#!/usr/bin/env bash
# Gate `e2e` — adaptateur HTTP de RÉFÉRENCE (API Platform / Symfony).
#
# Parcours de référence (créer → lister → basculer → supprimer) et les cinq scénarios de l'issue
# #31 (cloisonnement, 401 sans identité, 404 indiscernable, propriétaire jamais lu dans la requête,
# mots de passe jamais en clair), par les DEUX mécanismes : session par cookie et jeton porteur.
# Plus : en-têtes de sécurité, rien hors de public/, CSRF, limitation des essais, documentation
# OpenAPI des schémas de sécurité, 503 générique.
#
#   bash harness/e2e-apiplatform.sh                        # local : Docker, base remise à zéro
#   TODO_PERSISTENCE=doctrine bash harness/e2e-apiplatform.sh
#   E2E_BASE_URL=https://… E2E_A_EMAIL=… E2E_A_PASSWORD=… E2E_B_EMAIL=… E2E_B_PASSWORD=… \
#     bash harness/e2e-apiplatform.sh                      # distant : ni Docker ni remise à zéro
# Les deux comptes du mode distant se créent par `php bin/account.php create <courriel>`.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/lib-e2e.sh"
PERSISTENCE="${TODO_PERSISTENCE:-cqrs}"
E2E_CREES=(); E2E_CREES_B=(); A=(); B=()
JA="$E2E_TMP/a.jar"; JB="$E2E_TMP/b.jar"
E2E_SESSIONS=("$JA" "$JB"); E2E_JETONS_EMIS=("$E2E_TMP/a.hdr" "$E2E_TMP/b.hdr")

if [ "$E2E_REMOTE" = 0 ]; then
  source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_vendor; ensure_mysql
  trap 'e2e_menage; kit_stop' EXIT
  kit_reset_db
  kit_serve apiplatform "$PERSISTENCE"
  E2E_EXPECT_PERSISTENCE="$PERSISTENCE"
  A_EMAIL="a-$RANDOM@exemple.test"; A_PASS="$(openssl rand -hex 16)"
  B_EMAIL="b-$RANDOM@exemple.test"; B_PASS="$(openssl rand -hex 16)"
else
  trap e2e_menage EXIT
  : "${E2E_A_EMAIL:?mode distant : E2E_A_EMAIL, E2E_A_PASSWORD, E2E_B_EMAIL, E2E_B_PASSWORD requis}"
  A_EMAIL="$E2E_A_EMAIL"; A_PASS="${E2E_A_PASSWORD:?}"; B_EMAIL="${E2E_B_EMAIL:?}"; B_PASS="${E2E_B_PASSWORD:?}"
fi
connexion() { identifiants "$1" "$2" | corps "$3" -X POST "$BASE/api/$4" "${JSON[@]}" "${ORIGINE[@]}" --data-binary @- "${@:5}"; }
f="$E2E_TMP/r"; g="$E2E_TMP/r2"

echo "▶ sonde, en-têtes, rien hors de public/"
e2e_sante apiplatform
e2e_entetes
e2e_hors_public

echo "▶ création de compte (inscription « $E2E_REGISTRATION »)"
if [ "$E2E_REGISTRATION" = open ]; then
  assert "POST /api/register → 202" 202 "$(connexion "$A_EMAIL" "$A_PASS" "$f" register)"
  if grep -qi 'password\|hash\|"id"' "$f"; then ko "la réponse d'inscription porte un mot de passe, un hachage ou un identifiant"; else ok "la réponse d'inscription ne porte ni mot de passe, ni hachage, ni identifiant"; fi
  # Courriel déjà pris : MÊME réponse (aucun 409 qui révélerait le compte), et le mot de passe d'origine reste le bon.
  assert "POST /api/register, courriel déjà pris → 202 aussi" 202 "$(connexion "$A_EMAIL" "autre-mot-de-passe-$RANDOM" "$g" register)"
  verifier "inscription : même corps que le compte existe ou non" cmp -s "$f" "$g"
  assert "POST /api/register, mot de passe trop court → 422" 422 "$(connexion "c-$RANDOM@exemple.test" court "$f" register)"
  assert "POST /api/register, champ inconnu → 400" 400 "$(code -X POST "$BASE/api/register" "${JSON[@]}" "${ORIGINE[@]}" -d '{"email":"d@exemple.test","password":"un-mot-de-passe-long","role":"admin"}')"
else
  assert "inscription fermée : POST /api/register → 403" 403 "$(connexion "ferme-$RANDOM@exemple.test" "un-mot-de-passe-long" "$f" register)"
fi
if [ "$E2E_REMOTE" = 0 ]; then
  # Le second compte par la commande, mot de passe sur l'entrée standard : même hachage, autre chemin.
  if printf '%s\n' "$B_PASS" | kit_php php bin/account.php create "$B_EMAIL" >/dev/null 2>&1; then
    ok "php bin/account.php create (mot de passe lu sur l'entrée standard)"
  else
    ko "php bin/account.php create (mot de passe lu sur l'entrée standard)"
  fi
fi

echo "▶ @negative — sans identité"
[ "$E2E_REMOTE" = 0 ] && AVANT="$(e2e_compte_todos)"
e2e_sans_identite 00000000-0000-4000-8000-000000000000
[ "$E2E_REMOTE" = 0 ] && assert "aucun cas d'usage exécuté par les requêtes refusées (lignes de todos inchangées)" "$AVANT" "$(e2e_compte_todos)"
curl -s -o /dev/null -D "$f" "$BASE/api/todos"
if grep -qi '^set-cookie:' "$f"; then ko "un refus 401 pose un cookie de session"; else ok "un refus 401 ne pose aucun cookie"; fi

echo "▶ connexion par session (cookie)"
assert "POST /api/login, mauvais mot de passe → 401" 401 "$(connexion "$A_EMAIL" "pas-le-bon-$RANDOM" "$f" login)"
assert "POST /api/login, compte inconnu → 401" 401 "$(connexion "inconnu-$RANDOM@exemple.test" "pas-le-bon-$RANDOM" "$g" login)"
verifier "même réponse pour « compte inconnu » et « mauvais mot de passe »" cmp -s "$f" "$g"
assert "POST /api/login sans origine → 403 (CSRF)" 403 "$(identifiants "$A_EMAIL" "$A_PASS" | code -X POST "$BASE/api/login" "${JSON[@]}" --data-binary @-)"
assert "POST /api/login, origine étrangère → 403 (CSRF)" 403 "$(identifiants "$A_EMAIL" "$A_PASS" | code -X POST "$BASE/api/login" "${JSON[@]}" -H 'Origin: https://pirate.exemple' --data-binary @-)"
assert "A : POST /api/login → 200" 200 "$(connexion "$A_EMAIL" "$A_PASS" "$f" login -c "$JA" -D "$E2E_TMP/login.h")"
assert "B : POST /api/login → 200" 200 "$(connexion "$B_EMAIL" "$B_PASS" "$f" login -c "$JB")"
verifier "cookie de session : HttpOnly" grep -qiE '^set-cookie: .*; *httponly' "$E2E_TMP/login.h"
verifier "cookie de session : SameSite=Strict" grep -qiE '^set-cookie: .*; *samesite=strict' "$E2E_TMP/login.h"
case "$BASE" in
  https://*) verifier "cookie de session : Secure" grep -qiE '^set-cookie: .*; *secure' "$E2E_TMP/login.h" ;;
  *) echo "  · drapeau Secure non vérifié : adresse en http" ;;
esac
assert "A : GET /api/me → 200" 200 "$(corps "$f" "$BASE/api/me" -b "$JA")"
verifier "A : /api/me rend son courriel" grep -qF "\"$A_EMAIL\"" "$f"

echo "▶ parcours de référence et cloisonnement — session"
A=(-b "$JA" "${ORIGINE[@]}"); B=(-b "$JB" "${ORIGINE[@]}")
e2e_parcours A B
assert "A : POST avec sa session mais sans origine → 403 (CSRF)" 403 "$(code -X POST "$BASE/api/todos" -b "$JA" "${JSON[@]}" -d '{"title":"csrf"}')"
assert "A : DELETE avec sa session, origine étrangère → 403 (CSRF)" 403 "$(code -X DELETE "$BASE/api/todos/x" -b "$JA" -H 'Origin: https://pirate.exemple')"

echo "▶ jeton porteur"
assert "POST /api/tokens, mauvais mot de passe → 401" 401 "$(identifiants "$A_EMAIL" "pas-le-bon" | code -X POST "$BASE/api/tokens" "${JSON[@]}" --data-binary @-)"
assert "A : POST /api/tokens → 201" 201 "$(identifiants "$A_EMAIL" "$A_PASS" | corps "$f" -X POST "$BASE/api/tokens" "${JSON[@]}" --data-binary @- -D "$E2E_TMP/tok.h")"
TA="$(champ token < "$f")"; printf 'Authorization: Bearer %s' "$TA" > "$E2E_TMP/a.hdr"
assert "B : POST /api/tokens → 201" 201 "$(identifiants "$B_EMAIL" "$B_PASS" | corps "$f" -X POST "$BASE/api/tokens" "${JSON[@]}" --data-binary @-)"
TB="$(champ token < "$f")"; printf 'Authorization: Bearer %s' "$TB" > "$E2E_TMP/b.hdr"
if grep -qi '^set-cookie:' "$E2E_TMP/tok.h"; then ko "l'émission d'un jeton pose un cookie"; else ok "l'émission d'un jeton ne pose aucun cookie"; fi
curl -s -o /dev/null -D "$f" "$BASE/api/todos" -H "@$E2E_TMP/a.hdr"
if grep -qi '^set-cookie:' "$f"; then ko "un client à jeton reçoit un cookie de session"; else ok "un client à jeton ne reçoit aucun cookie de session"; fi
assert "jeton altéré → 401" 401 "$(code "$BASE/api/todos" -H "Authorization: Bearer kit_$(openssl rand -hex 16)")"

# Le délai ne doit pas dire si un compte existe : compte inconnu et mauvais mot de passe coûtent le
# même hachage (leurre). Trois essais ratés de chaque côté, on compare les plus courts.
T_CONNU="$(e2e_temps_connexion "$B_EMAIL")"; T_INCONNU="$(e2e_temps_connexion "inconnu-$RANDOM-$(date +%s)@exemple.test")"
if [ "$((T_INCONNU * 2))" -ge "$T_CONNU" ]; then
  ok "délai d'un refus : compte inconnu ${T_INCONNU} ms, mauvais mot de passe ${T_CONNU} ms (même ordre de grandeur)"
else
  ko "délai d'un refus : compte inconnu ${T_INCONNU} ms contre ${T_CONNU} ms pour un mauvais mot de passe — le délai trahit l'existence du compte"
fi

echo "▶ parcours de référence et cloisonnement — jeton porteur (sans en-tête Origin)"
A=(-H "@$E2E_TMP/a.hdr"); B=(-H "@$E2E_TMP/b.hdr")
e2e_parcours A B

echo "▶ documentation OpenAPI produite par API Platform"
assert "GET /api/docs.jsonopenapi sans identité → 401" 401 "$(code "$BASE/api/docs.jsonopenapi")"
assert "GET /api/docs.jsonopenapi → 200" 200 "$(corps "$f" "$BASE/api/docs.jsonopenapi" "${A[@]}")"
verifier "schéma de sécurité « sessionCookie » (cookie) déclaré" grep -q '"sessionCookie":{"type":"apiKey"' "$f"
verifier "schéma de sécurité « bearerToken » (http bearer) déclaré" grep -q '"bearerToken":{"type":"http"' "$f"
for chemin in $(grep -o '"/api/[^"]*"' "$ROOT/openapi/todos.openapi.json" | sort -u | tr -d '"'); do
  verifier "la documentation couvre $chemin du contrat" grep -qF "\"$(printf '%s' "$chemin" | sed 's#/#\\/#g')\":" "$f"
done

echo "▶ limitation des essais : un seul compteur par compte (variantes du courriel, deux pare-feu), essais simultanés"
essai() { printf '{"email":"%s","password":"mauvais-%s"}' "$1" "$RANDOM" | code -X POST "$BASE/api/$2" "${JSON[@]}" "${ORIGINE[@]}" --data-binary @-; }
jetable="jetable-$RANDOM-$(date +%s)@exemple.test"
# Cinq essais ratés sur LE MÊME compte, écrits de cinq façons (espace, tabulation, casse) et par
# les deux points d'entrée à mot de passe : ils doivent tomber dans le même compteur.
for forme in "$jetable:login" " $jetable:tokens" "$jetable\\t:login" "${jetable^^}:tokens" "$jetable :login"; do
  assert "essai raté « ${forme%:*} » par /api/${forme##*:} → 401" 401 "$(essai "${forme%:*}" "${forme##*:}")"
done
assert "6e essai en une minute, autre variante, autre point d'entrée → 429" 429 "$(essai "  $jetable" tokens)"
assert "… et par /api/login aussi → 429" 429 "$(essai "$jetable" login)"
# Accents : la base compare sans accent par défaut. « é » pour « e » ne doit PAS désigner le compte de A.
accentue="$(printf '%s' "$A_EMAIL" | sed 's/e/é/; t; s/a/á/')"
if [ "$accentue" != "$A_EMAIL" ]; then
  assert "variante accentuée du courriel de A, avec le bon mot de passe → 401" 401 "$(identifiants "$accentue" "$A_PASS" | code -X POST "$BASE/api/login" "${JSON[@]}" "${ORIGINE[@]}" --data-binary @-)"
fi
# Douze essais ratés LANCÉS EN MÊME TEMPS sur un compte : au plus cinq mots de passe sont vérifiés.
simultane="simultane-$RANDOM-$(date +%s)@exemple.test"
for i in $(seq 1 12); do ( essai "$simultane" login > "$E2E_TMP/simultane.$i" ) & done
wait
verifies="$(cat "$E2E_TMP"/simultane.* | grep -o 401 | wc -l | tr -d ' ')"; refuses="$(cat "$E2E_TMP"/simultane.* | grep -o 429 | wc -l | tr -d ' ')"
if [ "$verifies" -le 5 ] && [ "$((verifies + refuses))" = 12 ]; then
  ok "12 essais simultanés : $verifies vérifiés (401), $refuses refusés d'emblée (429)"
else
  ko "12 essais simultanés : $verifies vérifiés (401), $refuses refusés (429) — attendu au plus 5 vérifiés"
fi

echo "▶ révocation et déconnexion (le smoke défait ce qu'il a fait)"
assert "A : DELETE /api/tokens/current → 204" 204 "$(code -X DELETE "$BASE/api/tokens/current" -H "@$E2E_TMP/a.hdr")"
assert "A : jeton révoqué → 401" 401 "$(code "$BASE/api/todos" -H "@$E2E_TMP/a.hdr")"
assert "B : DELETE /api/tokens/current → 204" 204 "$(code -X DELETE "$BASE/api/tokens/current" -H "@$E2E_TMP/b.hdr")"
assert "A : POST /api/logout → 204" 204 "$(code -X POST "$BASE/api/logout" -b "$JA" "${ORIGINE[@]}")"
assert "A : session fermée → 401" 401 "$(code "$BASE/api/me" -b "$JA")"
assert "B : POST /api/logout → 204" 204 "$(code -X POST "$BASE/api/logout" -b "$JB" "${ORIGINE[@]}")"

if [ "$E2E_REMOTE" = 0 ]; then
  echo "▶ inscription limitée par adresse (10 par 10 minutes)"
  dernier=""
  for i in $(seq 1 11); do dernier="$(connexion "flot-$i-$RANDOM@exemple.test" "un-mot-de-passe-long-$i" "$f" register)"; done
  assert "inscriptions en rafale depuis une adresse → 429" 429 "$dernier"

  echo "▶ expiration des sessions côté application (inactivité ramenée à 2 s pour l'essai)"
  kit_serve apiplatform "$PERSISTENCE" -e KIT_SESSION_IDLE=2
  assert "A : POST /api/login → 200" 200 "$(connexion "$A_EMAIL" "$A_PASS" "$f" login -c "$JA")"
  assert "A : session fraîche → 200" 200 "$(code "$BASE/api/me" -b "$JA")"
  sleep 3
  assert "A : session inactive depuis plus longtemps que la limite → 401" 401 "$(code "$BASE/api/me" -b "$JA")"
  assert "A : la session expirée ne revit pas → 401" 401 "$(code "$BASE/api/me" -b "$JA")"

  echo "▶ @security — mots de passe et jetons jamais en clair (base, journaux)"
  e2e_fuites "$ROOT" "$A_PASS" "$B_PASS" "$TA" "$TB"
  echo "▶ @security — base injoignable"
  e2e_base_injoignable apiplatform "$PERSISTENCE"
fi

e2e_fin "e2e (API Platform)"
