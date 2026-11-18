#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — adaptateur HTTP VANILLA, même contrat que l'adaptateur de référence.
#
# Parcours de référence (créer → lister → basculer → supprimer) et cloisonnement, par JETON
# PORTEUR : c'est le seul mécanisme de l'adaptateur vanilla (ADR-001). Plus : en-têtes de
# sécurité, rien hors de public/, 503 générique. L'apparence est couverte par le gate `visuel`.
#
#   bash harness/e2e-smoke.sh                              # local : Docker, base remise à zéro
#   TODO_PERSISTENCE=doctrine bash harness/e2e-smoke.sh
#   E2E_BASE_URL=https://… E2E_A_TOKEN=… E2E_B_TOKEN=… bash harness/e2e-smoke.sh   # distant
# Les deux jetons du mode distant s'émettent par `php bin/account.php token <courriel>`.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/lib-e2e.sh"
PERSISTENCE="${TODO_PERSISTENCE:-cqrs}"
E2E_CREES=(); E2E_CREES_B=(); A=(); B=()
# Les jetons du mode distant sont fournis : le smoke ne les révoque pas. Il n'ouvre aucune session.
E2E_SESSIONS=(); E2E_JETONS_EMIS=()
f="$E2E_TMP/r"

if [ "$E2E_REMOTE" = 0 ]; then
  source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_mysql
  [ "$PERSISTENCE" = doctrine ] && ensure_vendor
  trap 'e2e_menage; kit_stop' EXIT
  kit_reset_db
  kit_serve vanilla "$PERSISTENCE"
  E2E_EXPECT_PERSISTENCE="$PERSISTENCE"
  A_EMAIL="a-$RANDOM@exemple.test"; B_EMAIL="b-$RANDOM@exemple.test"
  A_PASS="$(openssl rand -hex 16)"; B_PASS="$(openssl rand -hex 16)"
  echo "▶ comptes et jetons par la ligne de commande (aucun secret en argument)"
  printf '%s\n' "$A_PASS" | kit_php php bin/account.php create "$A_EMAIL" >/dev/null
  printf '%s\n' "$B_PASS" | kit_php php bin/account.php create "$B_EMAIL" >/dev/null
  TA="$(kit_php php bin/account.php token "$A_EMAIL" 2>/dev/null)"
  TB="$(kit_php php bin/account.php token "$B_EMAIL" 2>/dev/null)"
  verifier "php bin/account.php create puis token : deux jetons émis" test -n "$TA" -a -n "$TB"
  assert "php bin/account.php create, courriel déjà pris → échec" 1 "$(printf '%s\n' "$A_PASS" | kit_php php bin/account.php create "$A_EMAIL" >/dev/null 2>&1; echo $?)"
else
  trap e2e_menage EXIT
  : "${E2E_A_TOKEN:?mode distant : E2E_A_TOKEN et E2E_B_TOKEN requis}"
  TA="$E2E_A_TOKEN"; TB="${E2E_B_TOKEN:?}"
fi
# Les jetons vont à curl par un fichier d'en-tête, pas par un argument.
printf 'Authorization: Bearer %s' "$TA" > "$E2E_TMP/a.hdr"
printf 'Authorization: Bearer %s' "$TB" > "$E2E_TMP/b.hdr"
A=(-H "@$E2E_TMP/a.hdr"); B=(-H "@$E2E_TMP/b.hdr")

echo "▶ sonde, en-têtes, rien hors de public/"
e2e_sante vanilla
e2e_entetes
e2e_hors_public

echo "▶ @negative — sans identité"
[ "$E2E_REMOTE" = 0 ] && AVANT="$(e2e_compte_todos)"
e2e_sans_identite 00000000-0000-4000-8000-000000000000
[ "$E2E_REMOTE" = 0 ] && assert "aucun cas d'usage exécuté par les requêtes refusées (lignes de todos inchangées)" "$AVANT" "$(e2e_compte_todos)"
assert "jeton altéré → 401" 401 "$(code "$BASE/api/todos" -H "Authorization: Bearer kit_$(openssl rand -hex 16)")"
if e2e_complet; then assert "schéma d'authentification inconnu → 401" 401 "$(code "$BASE/api/todos" -H 'Authorization: Basic YTpi')"; fi
assert "A : GET /api/me → 200" 200 "$(code "$BASE/api/me" "${A[@]}")"

echo "▶ ce que l'adaptateur vanilla ne fait pas (ADR-001) : ni connexion, ni inscription, ni émission"
routes="login register tokens"; e2e_complet || routes="login"
for route in $routes; do
  assert "POST /api/$route sans jeton → 401" 401 "$(code -X POST "$BASE/api/$route" "${JSON[@]}" -d '{"email":"a@exemple.test","password":"un-mot-de-passe-long"}')"
  assert "POST /api/$route avec jeton → 404 (route absente)" 404 "$(code -X POST "$BASE/api/$route" "${A[@]}" "${JSON[@]}" -d '{"email":"a@exemple.test","password":"un-mot-de-passe-long"}')"
done

echo "▶ parcours de référence et cloisonnement — jeton porteur"
e2e_parcours A B

if [ "$E2E_REMOTE" = 0 ]; then
  echo "▶ révocation d'un jeton"
  TC="$(kit_php php bin/account.php token "$A_EMAIL" 2>/dev/null)"; printf 'Authorization: Bearer %s' "$TC" > "$E2E_TMP/c.hdr"
  assert "DELETE /api/tokens/current → 204" 204 "$(code -X DELETE "$BASE/api/tokens/current" -H "@$E2E_TMP/c.hdr")"
  assert "jeton révoqué → 401" 401 "$(code "$BASE/api/todos" -H "@$E2E_TMP/c.hdr")"
  echo "▶ @security — mots de passe et jetons jamais en clair (base, journaux)"
  e2e_fuites "$ROOT" "$A_PASS" "$B_PASS" "$TA" "$TB" "$TC"
  echo "▶ @security — base injoignable"
  e2e_base_injoignable vanilla "$PERSISTENCE" "${A[@]}"
fi

e2e_fin "e2e (smoke HTTP)"
