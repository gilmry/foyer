#!/usr/bin/env bash
# Fonctions communes aux smokes e2e (harness/e2e-smoke.sh, harness/e2e-apiplatform.sh). Sourcé.
#
# Deux modes :
#   - local (défaut)            : le gate monte MySQL, remet la base à zéro, sert le kit sur
#                                 127.0.0.1:8080 et crée ses comptes ;
#   - distant (E2E_BASE_URL=…)  : vise une adresse existante. Ni Docker, ni remise à zéro : le
#                                 smoke ne touche qu'à ce qu'il crée, et le supprime.
# curl seul : aucun autre outil n'est requis en mode distant.

BASE="${E2E_BASE_URL:-http://127.0.0.1:8080}"; BASE="${BASE%/}"
E2E_REMOTE=0; [ -n "${E2E_BASE_URL:-}" ] && E2E_REMOTE=1
E2E_TMP="$(mktemp -d)"
fail=0

ok() { echo "  ✓ $1"; }
ko() { echo "  ✗ $1"; fail=1; }
assert() { if [ "$2" = "$3" ]; then ok "$1 ($3)"; else ko "$1 : attendu $2, obtenu $3"; fi; }
# verifier <libellé> <commande…> : vert si la commande réussit.
verifier() { local l="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$l"; else ko "$l"; fi; }
code() { curl -s -o /dev/null --max-time 30 -w '%{http_code}' "$@"; }
# corps <fichier> <args curl…> : écrit le corps dans le fichier, rend le code.
corps() { local f="$1"; shift; curl -s -o "$f" --max-time 30 -w '%{http_code}' "$@"; }
champ() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }
# Corps JSON d'identifiants, sur la sortie standard : il passe à curl par un tube (--data-binary @-),
# jamais par un argument (les arguments se lisent dans la liste des processus).
identifiants() {
  local e p
  e="$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  p="$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"email":"%s","password":"%s"}' "$e" "$p"
}
JSON=(-H 'Content-Type: application/json')
ORIGINE=(-H "Origin: $BASE")

# La sonde de santé dit QUELLE combinaison répond : sans ce contrôle, quatre verts pourraient
# être quatre fois la même.
e2e_sante() {
  local attendu_http="$1" f="$E2E_TMP/sante"
  assert "GET /api/health → 200" 200 "$(corps "$f" "$BASE/api/health")"
  assert "adaptateur HTTP servi = $attendu_http" "$attendu_http" "$(champ http < "$f")"
  if [ -n "${E2E_EXPECT_PERSISTENCE:-}" ]; then
    assert "persistance servie = $E2E_EXPECT_PERSISTENCE" "$E2E_EXPECT_PERSISTENCE" "$(champ persistence < "$f")"
  fi
  E2E_REGISTRATION="$(champ registration < "$f")"
}

# @negative (#34) — rien hors de public/ n'est servi : 403 ou 404, et aucun contenu de fichier.
e2e_hors_public() {
  local chemin f="$E2E_TMP/hors" c
  for chemin in /src/config.php /src/Config.php /src/config.example.php /vendor/ /vendor/autoload.php \
                /database/ /database/schema.sql /composer.json /composer.lock /.git/ /.git/config /.env \
                /bin/migrate.php /var/log/kit.log /.htaccess; do
    c="$(corps "$f" "$BASE$chemin")"
    if { [ "$c" = 403 ] || [ "$c" = 404 ]; } && ! grep -qE '<\?php|"require"|CREATE TABLE|RewriteEngine|\[core\]|packages' "$f"; then
      ok "$chemin non servi ($c)"
    else
      ko "$chemin : attendu 403 ou 404 sans contenu, obtenu $c"
    fi
  done
  assert "/todos-island/ (dossier) : pas de listing" 404 "$(code "$BASE/todos-island/")"
}

# En-têtes de sécurité, posés par l'application : sur le document, sur l'API, sur un statique.
e2e_entetes() {
  local cible h="$E2E_TMP/entetes"
  for cible in / /api/health /api/todos; do
    curl -s -o /dev/null --max-time 30 -D "$h" "$BASE$cible"
    verifier "$cible : X-Content-Type-Options nosniff" grep -qi '^x-content-type-options: *nosniff' "$h"
    verifier "$cible : inclusion en cadre interdite" grep -qiE "^x-frame-options: *DENY|^content-security-policy:.*frame-ancestors 'none'" "$h"
    verifier "$cible : Referrer-Policy" grep -qi '^referrer-policy: *no-referrer' "$h"
    case "$BASE" in https://*) verifier "$cible : Strict-Transport-Security (HSTS)" grep -qi '^strict-transport-security: *max-age=[0-9]' "$h" ;; esac
    if grep -qi '^x-powered-by:' "$h"; then ko "$cible : X-Powered-By divulgué"; fi
  done
  curl -s -o /dev/null --max-time 30 -D "$h" "$BASE/todos-island/index.js"
  verifier "fichier statique : X-Content-Type-Options nosniff" grep -qi '^x-content-type-options: *nosniff' "$h"
  case "$BASE" in https://*) : ;; *) echo "  · HSTS non vérifié : adresse en http (il n'est émis que pour une adresse publique en https)" ;; esac
}

# @negative (#31) — sans identité : 401 sur chaque opération, au format problème.
e2e_sans_identite() {
  local id="$1" f="$E2E_TMP/401"
  assert "sans identité : GET /api/todos → 401" 401 "$(corps "$f" "$BASE/api/todos")"
  verifier "401 au format problème (application/problem+json)" grep -q '"status":401' "$f"
  assert "sans identité : POST /api/todos → 401" 401 "$(code -X POST "$BASE/api/todos" "${JSON[@]}" "${ORIGINE[@]}" -d '{"title":"intrus"}')"
  assert "sans identité : GET /api/todos/{id} → 401" 401 "$(code "$BASE/api/todos/$id")"
  assert "sans identité : PATCH /api/todos/{id} → 401" 401 "$(code -X PATCH "$BASE/api/todos/$id" "${JSON[@]}" "${ORIGINE[@]}")"
  assert "sans identité : DELETE /api/todos/{id} → 401" 401 "$(code -X DELETE "$BASE/api/todos/$id" "${ORIGINE[@]}")"
  assert "sans identité : GET /api/me → 401" 401 "$(code "$BASE/api/me")"
}

# Parcours de référence et cloisonnement, communs aux deux adaptateurs. A et B sont deux jeux
# d'arguments curl qui portent l'identité (cookie + origine, ou jeton porteur).
#   e2e_parcours A[@] B[@]
e2e_parcours() {
  local -n _a="$1" _b="$2"
  local f="$E2E_TMP/corps" g="$E2E_TMP/corps2" ida idb idx c marque
  marque="e2e-$(date +%s)-$RANDOM"

  # @happy — création (A et B), puis liste.
  assert "A : POST /api/todos → 201" 201 "$(corps "$f" -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" -d "{\"title\":\"$marque de A\"}")"
  ida="$(champ id < "$f")"; E2E_CREES+=("$ida")
  if grep -qiE '"owner|"password' "$f"; then ko "la vue d'une tâche divulgue le propriétaire"; else ok "la vue d'une tâche ne porte pas le propriétaire"; fi
  assert "B : POST /api/todos → 201" 201 "$(corps "$f" -X POST "$BASE/api/todos" "${_b[@]}" "${JSON[@]}" -d "{\"title\":\"$marque de B\"}")"
  idb="$(champ id < "$f")"; E2E_CREES_B+=("$idb")

  # @happy (#31) — un utilisateur authentifié ne voit que ses propres todos.
  assert "A : GET /api/todos → 200" 200 "$(corps "$f" "$BASE/api/todos?limit=100" "${_a[@]}")"
  verifier "la liste est un tableau JSON" grep -q '^\[' "$f"
  verifier "la liste de A contient le todo de A" grep -q "\"$ida\"" "$f"
  if grep -q "\"$idb\"" "$f" || grep -q "$marque de B" "$f"; then ko "la liste de A contient le todo de B"; else ok "la liste de A ne contient pas le todo de B"; fi
  assert "liste bornée : ?limit=1 → 200" 200 "$(corps "$f" "$BASE/api/todos?limit=1" "${_a[@]}")"
  assert "liste bornée : ?limit=1 rend un seul élément" 1 "$(grep -o '"id":' "$f" | wc -l | tr -d ' ')"

  # @edge (#31) — le todo d'autrui : 404, IDENTIQUE à celui d'un identifiant inexistant.
  for verbe in GET PATCH DELETE; do
    c="$(corps "$f" -X "$verbe" "$BASE/api/todos/$idb" "${_a[@]}" "${JSON[@]}")"
    corps "$g" -X "$verbe" "$BASE/api/todos/00000000-0000-4000-8000-000000000000" "${_a[@]}" "${JSON[@]}" >/dev/null
    assert "A : $verbe sur le todo de B → 404" 404 "$c"
    verifier "A : $verbe sur le todo de B = même corps que sur un identifiant inexistant" cmp -s "$f" "$g"
  done
  assert "B : son todo existe toujours → 200" 200 "$(corps "$f" "$BASE/api/todos/$idb" "${_b[@]}")"
  verifier "B : son todo n'a pas été basculé par A" grep -q '"done":false' "$f"

  # @security (#31) — le propriétaire ne vient jamais de la requête : champ refusé (400).
  for cle in ownerId owner owner_id; do
    assert "A : POST avec un champ « $cle » → 400 (désérialisation stricte)" 400 \
      "$(code -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" -d "{\"title\":\"$marque usurpation\",\"$cle\":\"$idb\"}")"
  done
  corps "$f" "$BASE/api/todos?limit=100" "${_b[@]}" >/dev/null
  if grep -q "$marque usurpation" "$f"; then ko "B a reçu un todo créé par A"; else ok "aucun todo n'a été créé chez B par A"; fi

  # Validation et corps invalides.
  assert "POST libellé vide → 422" 422 "$(corps "$f" -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" -d '{"title":"  "}')"
  verifier "422 au format problème, avec les violations" grep -q '"violations":\[{"propertyPath":"title"' "$f"
  assert "POST libellé trop long → 422" 422 "$(printf '{"title":"%0300d"}' 0 | code -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" --data-binary @-)"
  assert "POST JSON mal formé → 400" 400 "$(code -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" -d '{pas du json')"
  assert "POST libellé non textuel → 400" 400 "$(code -X POST "$BASE/api/todos" "${_a[@]}" "${JSON[@]}" -d '{"title":12}')"
  if grep -qiE 'stack|trace|\.php|Symfony|ApiPlatform|SQLSTATE' "$f"; then ko "une erreur divulgue une trace"; else ok "aucune trace dans les erreurs"; fi

  # @happy — bascule puis suppression (parcours de référence).
  assert "A : PATCH /api/todos/{id} → 200" 200 "$(corps "$f" -X PATCH "$BASE/api/todos/$ida" "${_a[@]}" "${JSON[@]}")"
  verifier "A : la tâche est faite" grep -q '"done":true' "$f"
  assert "A : DELETE /api/todos/{id} → 204" 204 "$(code -X DELETE "$BASE/api/todos/$ida" "${_a[@]}")"
  assert "A : DELETE d'une tâche déjà supprimée → 404" 404 "$(code -X DELETE "$BASE/api/todos/$ida" "${_a[@]}")"
  assert "B : DELETE /api/todos/{id} → 204" 204 "$(code -X DELETE "$BASE/api/todos/$idb" "${_b[@]}")"
}

# Ménage : supprime ce que le smoke a créé et n'aurait pas encore défait (tâches, jetons, sessions).
# Appelé à la fin normale ET par le piège de sortie : un smoke interrompu ne laisse rien derrière
# lui tant que le service répond. A et B sont les identités courantes (tableaux d'arguments curl).
E2E_MENAGE_FAIT=0
e2e_menage() {
  [ "$E2E_MENAGE_FAIT" = 0 ] && [ -d "$E2E_TMP" ] || return 0
  E2E_MENAGE_FAIT=1
  local id j
  for id in "${E2E_CREES[@]:-}"; do [ -n "$id" ] && code -X DELETE "$BASE/api/todos/$id" "${A[@]:-}" >/dev/null 2>&1 || true; done
  for id in "${E2E_CREES_B[@]:-}"; do [ -n "$id" ] && code -X DELETE "$BASE/api/todos/$id" "${B[@]:-}" >/dev/null 2>&1 || true; done
  # Jetons émis par le smoke lui-même (jamais ceux reçus par E2E_A_TOKEN / E2E_B_TOKEN).
  for j in "${E2E_JETONS_EMIS[@]:-}"; do [ -n "$j" ] && [ -s "$j" ] && code -X DELETE "$BASE/api/tokens/current" -H "@$j" >/dev/null 2>&1 || true; done
  for j in "${E2E_SESSIONS[@]:-}"; do [ -n "$j" ] && [ -s "$j" ] && code -X POST "$BASE/api/logout" -b "$j" "${ORIGINE[@]}" >/dev/null 2>&1 || true; done
  rm -rf "$E2E_TMP"
}

# Verdict + ménage.
e2e_fin() {
  e2e_menage
  echo ""
  if [ "$fail" = 0 ]; then echo "$1: 🟢"; else echo "$1: 🔴"; fi
  exit "$fail"
}

# (mode local) Ni mot de passe ni jeton en clair : journaux du noyau, sortie du serveur, tables.
#   e2e_fuites <secret>…
e2e_fuites() {
  local root="$1"; shift
  local secret dump="$E2E_TMP/dump"
  kit_php php harness/dump-auth.php > "$dump"
  verifier "tables accounts et access_tokens : hachages seulement (bcrypt/argon2, SHA-256)" grep -qx 'HORS_FORMAT=0' "$dump"
  docker logs todo-web > "$E2E_TMP/serveur.log" 2>&1 || true
  for secret in "$@"; do
    [ -n "$secret" ] || continue
    if grep -qF -- "$secret" "$dump" "$E2E_TMP/serveur.log" "$root"/var/log/* 2>/dev/null; then
      ko "un secret figure en clair dans la base ou un journal"
    else
      ok "secret absent de la base, du journal du noyau et de la sortie du serveur"
    fi
  done
}

# (mode local) @security (#34) — base injoignable → 503 générique, sans trace ni identifiant.
#   e2e_base_injoignable <apiplatform|vanilla> <persistance> [args curl d'identité…]
e2e_base_injoignable() {
  local http="$1" persistence="$2"; shift 2
  local f="$E2E_TMP/503" chemin
  kit_serve "$http" "$persistence" -e DB_PORT=1 || { ko "le serveur n'a pas redémarré"; return; }
  for chemin in /api/health /api/todos; do
    assert "base injoignable : GET $chemin → 503" 503 "$(corps "$f" "$BASE$chemin" "$@")"
    verifier "503 générique au format problème" grep -q '"status":503' "$f"
    if grep -qiE 'SQLSTATE|PDO|127\.0\.0\.1|kit_php_app|refused|stack|trace|\.php|#[0-9]' "$f"; then
      ko "le 503 divulgue une trace ou un identifiant"
    else
      ok "le 503 ne porte ni trace ni identifiant"
    fi
  done
  assert "base injoignable : le document reste servi → 200" 200 "$(code "$BASE/")"
  # Le journal du noyau ne doit pas porter le message de PDO (il nomme l'hôte et l'identifiant).
  if grep -qE 'SQLSTATE\[|kit_php_app|Connection refused' "$(_kit_root)"/var/log/* 2>/dev/null; then
    ko "le journal du noyau porte le message de la panne de base (hôte ou identifiant)"
  else
    ok "le journal du noyau ne porte ni hôte ni identifiant de la base"
  fi
}

# (mode local) Nombre de lignes de la table todos : sert à prouver qu'un refus 401 n'a exécuté
# aucun cas d'usage (rien n'a été écrit).
e2e_compte_todos() { kit_php php harness/dump-auth.php todos 2>/dev/null | sed -n 's/^TODOS=//p'; }

# Temps de réponse (en ms, le plus court de deux essais) d'une tentative de connexion ratée.
#   e2e_temps_connexion <courriel>
e2e_temps_connexion() {
  local t min=999999 i
  for i in 1 2; do
    t="$(identifiants "$1" "pas-le-bon-$RANDOM" | curl -s -o /dev/null --max-time 30 -w '%{time_total}' -X POST "$BASE/api/tokens" "${JSON[@]}" --data-binary @-)"
    t="$(printf '%s' "$t" | awk '{printf "%d", $1 * 1000}')"
    [ "$t" -lt "$min" ] && min="$t"
  done
  printf '%s' "$min"
}
