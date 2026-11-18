#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — parcours de référence, identité et cloisonnement, sans navigateur.
#
# Sans variable : uvicorn réel + PostgreSQL du harnais (base vide, migrée par `app.migrate`), login
#   sans privilège, application en mode production (cookie Secure). TODO_HTTP=fastapi|starlette et
#   TODO_PERSISTENCE=cqrs|orm choisissent les adaptateurs. Les deux comptes sont créés par la route
#   d'inscription (ouverte), avec des mots de passe tirés à chaque exécution.
# Avec E2E_BASE_URL=https://… : le même parcours contre une adresse déjà en service (un déploiement
#   réel, ou la répétition locale). Ni Docker, ni remise à zéro : le smoke supprime ce qu'il crée
#   et révoque ses jetons. Les deux comptes existent déjà (`python -m app.accounts create …`) :
#     E2E_EMAIL_A, E2E_PASSWORD_A, E2E_EMAIL_B, E2E_PASSWORD_B
#   L'inscription y est attendue FERMÉE (E2E_REGISTRATION=open si le déploiement la laisse ouverte).
# E2E_PROFIL=public : parcours ALLÉGÉ et ESPACÉ, à utiliser contre un hébergeur réel. Le frontal d'un
#   hébergement mutualisé prend une rafale de refus (401, 404, chemins sensibles, gros corps) pour une
#   attaque et peut bloquer l'adresse du poste, pour tous les sites du compte. Ce profil garde
#   l'identité, le parcours, le cloisonnement, la session, quatre fichiers non servis et les en-têtes ;
#   il laisse à la répétition locale (gate `deploiement`) les entrées hostiles, la limite d'essais et
#   les chemins détournés. E2E_PAUSE=<secondes> entre deux requêtes (1 par défaut dans ce profil).
#   Un seul passage par déploiement : ne jamais l'enchaîner.
# Aucun secret ne passe en argument de commande : identifiants et jetons vont à curl par fichier.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSISTENCE="${TODO_PERSISTENCE:-cqrs}"
HTTP="${TODO_HTTP:-fastapi}"
T="$(mktemp -d)"; chmod 700 "$T"
cid=""
nettoyer() { [ -n "$cid" ] && docker stop "$cid" >/dev/null 2>&1; rm -rf "$T"; return 0; }
trap nettoyer EXIT
alea() { head -c "${1:-18}" /dev/urandom | od -An -tx1 | tr -d ' \n'; }

if [ -n "${E2E_BASE_URL:-}" ]; then
  BASE="${E2E_BASE_URL%/}"
  LOCAL=0
  cible="$BASE"
  : "${E2E_EMAIL_A:?E2E_EMAIL_A manque (compte A du smoke)}" "${E2E_PASSWORD_A:?E2E_PASSWORD_A manque}"
  : "${E2E_EMAIL_B:?E2E_EMAIL_B manque (compte B du smoke)}" "${E2E_PASSWORD_B:?E2E_PASSWORD_B manque}"
  EMAIL_A="$E2E_EMAIL_A"; MDP_A="$E2E_PASSWORD_A"; EMAIL_B="$E2E_EMAIL_B"; MDP_B="$E2E_PASSWORD_B"
  INSCRIPTION="${E2E_REGISTRATION:-closed}"
else
  source "$ROOT/harness/ensure-images.sh"; ensure_py_image; ensure_postgres; reset_schema
  BASE="http://127.0.0.1:8080"
  LOCAL=1
  cible="local, http=$HTTP, persistance=$PERSISTENCE"
  kit_py python -m app.migrate up >/dev/null
  demarrer() {  # $1… : réglages supplémentaires du conteneur
    docker run -d --rm --network host -v "$ROOT":/app:ro -w /app -e PYTHONPATH=/app "${DB_ENV[@]}" \
      -e TODO_SECRET_KEY="$(kit_alea 32)" -e TODO_REGISTRATION=open -e TODO_PUBLIC_URL="$BASE" \
      -e TODO_PERSISTENCE="$PERSISTENCE" -e TODO_HTTP="$HTTP" "$@" \
      todo-kit-fastapi:local uvicorn app.http.app:app --host 127.0.0.1 --port 8080 --log-level info
  }
  cid=$(demarrer)
  EMAIL_A="a-$(alea 4)@exemple.test"; MDP_A="$(alea)"; EMAIL_B="b-$(alea 4)@exemple.test"; MDP_B="$(alea)"
  INSCRIPTION=open
fi
# Origine du site (schéma://hôte[:port]) : celle que le navigateur enverrait dans `Origin`.
ORIGINE="$(printf '%s' "$BASE" | sed -E 's#^(https?://[^/]+).*#\1#')"

PROFIL="${E2E_PROFIL:-complet}"
case "$PROFIL" in
  complet) PAUSE="${E2E_PAUSE:-0}" ;;
  public) PAUSE="${E2E_PAUSE:-1}"; cible="$cible, profil public" ;;
  *) echo "E2E_PROFIL : « complet » ou « public », reçu « $PROFIL »" >&2; exit 2 ;;
esac
requete() { [ "$PAUSE" = 0 ] || sleep "$PAUSE"; curl -s --max-time 30 "$@"; }
C=(requete)
JSON=(-H 'Content-Type: application/json')
for _ in $(seq 1 60); do curl -s --max-time 30 -f "$BASE/api/health" >/dev/null 2>&1 && break; sleep 0.5; [ "$PROFIL" = complet ] || sleep 4; done

fail=0
ok() { echo "  ✓ $1"; }
ko() { echo "  ✗ $1"; fail=1; }
assert() { if [ "$2" = "$3" ]; then ok "$1 ($3)"; else ko "$1 : attendu $2, obtenu $3"; fi; }
verifier() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
code() { "${C[@]}" -o /dev/null -w '%{http_code}' "$@"; }
# Réponse complète : corps, puis le code sur la dernière ligne.
rep() { "${C[@]}" -w '\n%{http_code}' "$@"; }
code_de() { printf '%s' "$1" | tail -n1; }
corps_de() { printf '%s' "$1" | sed '$d'; }
champ() { printf '%s' "$2" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p"; }
# Identifiants : écrits dans un fichier à droits restreints, lus par curl (jamais en argument).
identifiants() { printf '{"email":"%s","password":"%s"}' "$2" "$3" > "$T/$1.json"; }
identifiants a "$EMAIL_A" "$MDP_A"; identifiants b "$EMAIL_B" "$MDP_B"

echo "— identité : sans jeton ni session, tout est refusé (401)"
sans=$(rep "$BASE/api/todos")
assert "GET /api/todos sans identité → 401" 401 "$(code_de "$sans")"
assert "POST /api/todos sans identité → 401" 401 "$(code -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"intrus"}')"
if [ "$PROFIL" = complet ]; then
  assert "GET /api/todos/{id} sans identité → 401" 401 "$(code "$BASE/api/todos/un-id")"
  assert "PATCH /api/todos/{id} sans identité → 401" 401 "$(code -X PATCH "$BASE/api/todos/un-id")"
  assert "DELETE /api/todos/{id} sans identité → 401" 401 "$(code -X DELETE "$BASE/api/todos/un-id")"
fi
assert "jeton porteur jamais délivré → 401" 401 "$(code -H 'Authorization: Bearer jamais-delivre' "$BASE/api/todos")"
verifier "le refus ne contient aucun todo" "! corps_de \"\$sans\" | grep -q '\"items\"'"

echo "— comptes"
if [ "$INSCRIPTION" = open ]; then
  assert "POST /api/auth/register (A) → 201" 201 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/a.json")"
  assert "POST /api/auth/register (B) → 201" 201 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/b.json")"
  assert "inscription, courriel déjà pris → 409" 409 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/a.json")"
  identifiants court "court-$(alea 4)@exemple.test" "court"
  assert "inscription, mot de passe trop court → 400" 400 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/court.json")"
  printf '{"email":"x-%s@exemple.test","password":"%s","role":"admin"}' "$(alea 4)" "$(alea)" > "$T/intrus.json"
  assert "inscription, champ inconnu → 422 (désérialisation stricte)" 422 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/intrus.json")"
else
  identifiants nouveau "nouveau-$(alea 4)@exemple.test" "$(alea)"
  assert "inscription fermée sur ce déploiement → 403" 403 "$(code -X POST "$BASE/api/auth/register" "${JSON[@]}" --data-binary "@$T/nouveau.json")"
fi

echo "— jetons porteurs (clients d'API)"
jeton() {  # $1 : a|b → écrit l'en-tête Authorization dans $T/$1.h, affiche le code HTTP
  local r; r=$(rep -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/$1.json")
  printf 'Authorization: Bearer %s\n' "$(champ token "$(corps_de "$r")")" > "$T/$1.h"
  code_de "$r"
}
assert "POST /api/auth/token (A) → 200" 200 "$(jeton a)"
assert "POST /api/auth/token (B) → 200" 200 "$(jeton b)"
A=(-H "@$T/a.h"); B=(-H "@$T/b.h")
identifiants faux "$EMAIL_A" "$(alea)"
identifiants inconnu "inconnu-$(alea 4)@exemple.test" "$(alea)"
faux=$(rep -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/faux.json")
inconnu=$(rep -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/inconnu.json")
assert "mauvais mot de passe → 401" 401 "$(code_de "$faux")"
assert "compte inconnu → 401" 401 "$(code_de "$inconnu")"
verifier "« compte inconnu » et « mauvais mot de passe » : réponses identiques" "[ \"\$faux\" = \"\$inconnu\" ]"
assert "GET /api/auth/me (A) → 200" 200 "$(code "${A[@]}" "$BASE/api/auth/me")"
# Contre une adresse en service, les comptes peuvent déjà porter des todos : on compte avant.
compter() { "${C[@]}" "$@" "$BASE/api/todos" | { grep -o '"id"' || true; } | wc -l; }
avant_a=$(compter "${A[@]}"); avant_b=$(compter "${B[@]}")

echo "— parcours de référence (compte A) : créer → lister → lire → basculer → supprimer"
cree=$(rep "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"acheter du pain"}')
id=$(champ id "$(corps_de "$cree")")
assert "POST /api/todos → 201" 201 "$(code_de "$cree")"
seconde=$(rep "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"seconde"}')
id2=$(champ id "$(corps_de "$seconde")")
assert "POST /api/todos (seconde) → 201" 201 "$(code_de "$seconde")"
assert "POST libellé vide → 400" 400 "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"  "}')"
assert "POST champ inconnu → 422 (désérialisation stricte)" 422 "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"x","foo":1}')"
assert "GET /api/todos → 200" 200 "$(code "${A[@]}" "$BASE/api/todos")"
assert "GET /api/todos/{id} → 200" 200 "$(code "${A[@]}" "$BASE/api/todos/$id")"
assert "PATCH /api/todos/{id} → 200" 200 "$(code "${A[@]}" -X PATCH "$BASE/api/todos/$id")"
inexistant=$(rep "${A[@]}" -X PATCH "$BASE/api/todos/inconnu")
assert "PATCH id inconnu → 404" 404 "$(code_de "$inexistant")"
assert "DELETE /api/todos/{id} → 200" 200 "$(code "${A[@]}" -X DELETE "$BASE/api/todos/$id")"
assert "DELETE id inconnu → 404" 404 "$(code "${A[@]}" -X DELETE "$BASE/api/todos/inconnu")"

if [ "$PROFIL" = complet ]; then
echo "— entrées hostiles : refusées à la validation, jamais par une erreur 500"
assert "JSON mal formé sans identité → 401 (l'identité d'abord)" 401 "$(code -X POST "$BASE/api/todos" "${JSON[@]}" -d '{pas du json')"
assert "JSON mal formé avec identité → 422" 422 "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{pas du json')"
assert "corps JSON annoncé en text/plain → 422" 422 "$(code "${A[@]}" -X POST "$BASE/api/todos" -H 'Content-Type: text/plain' -d '{"title":"x"}')"
assert "libellé avec un octet NUL → 400" 400 "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"a\u0000b"}')"
assert "libellé avec un demi-codet isolé → 400" 400 "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"\ud800"}')"
for verbe in GET PATCH DELETE; do
  assert "$verbe d'un identifiant avec un octet NUL → 404" 404 "$(code "${A[@]}" -X "$verbe" "$BASE/api/todos/a%00b")"
done
printf '{"email":"a\\u0000@exemple.test","password":"%s"}' "$(alea)" > "$T/nul.json"
assert "connexion, courriel avec un octet NUL → 401" 401 "$(code -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/nul.json")"
printf '{"email":"%s","password":"%s"}' "$EMAIL_A" "$(alea 100)" > "$T/long.json"
assert "connexion, mot de passe de 200 caractères → 401 (refusé avant hachage)" 401 "$(code -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/long.json")"
printf '{"email":"%s","password":"%s"}' "$EMAIL_A" "$(alea 10000)" > "$T/enorme.json"
assert "corps de 20 Ko → 413" 413 "$(code -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/enorme.json")"
assert "le compte A n'est pas verrouillé par ces refus → 200" 200 "$(code "${A[@]}" "$BASE/api/auth/me")"
fi

echo "— cloisonnement par propriétaire"
de_b=$(champ id "$(corps_de "$(rep "${B[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"todo de B"}')")")
liste_a=$("${C[@]}" "${A[@]}" "$BASE/api/todos")
verifier "A liste son todo" "printf '%s' \"\$liste_a\" | grep -q '\"id\":\"$id2\"'"
verifier "A ne voit pas le todo de B" "[ -n '$de_b' ] && ! printf '%s' \"\$liste_a\" | grep -q '$de_b'"
verifier "la vue d'un todo ne porte aucun propriétaire" "! printf '%s' \"\$liste_a\" | grep -qi 'owner'"
for verbe in GET PATCH DELETE; do
  autrui=$(rep "${A[@]}" -X "$verbe" "$BASE/api/todos/$de_b")
  inconnu=$(rep "${A[@]}" -X "$verbe" "$BASE/api/todos/inconnu")
  assert "$verbe du todo de B par A → 404" 404 "$(code_de "$autrui")"
  verifier "$verbe : réponse identique à celle d'un identifiant inexistant" "[ \"\$autrui\" = \"\$inconnu\" ]"
done
relu=$("${C[@]}" "${B[@]}" "$BASE/api/todos/$de_b")
verifier "le todo de B est intact (ni basculé, ni supprimé)" "printf '%s' \"\$relu\" | grep -q '\"done\":false'"
if [ "$PROFIL" = complet ]; then intrus_essayes="owner_id ownerId owner"; else intrus_essayes="owner_id"; fi
for intrus in $intrus_essayes; do
  assert "POST avec le champ « $intrus » désignant B → 422" 422 \
    "$(code "${A[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d "{\"title\":\"pour B\",\"$intrus\":\"$de_b\"}")"
done
verifier "aucun todo n'a été créé pour B, ni par l'appel sans identité" \
  "[ \"\$(compter \"\${B[@]}\")\" = $((avant_b + 1)) ]"
verifier "A n'a que son todo (rien créé par les requêtes rejetées)" \
  "[ \"\$(compter \"\${A[@]}\")\" = $((avant_a + 1)) ]"

echo "— session par cookie (front)"
"${C[@]}" -D "$T/login.entetes" -o "$T/login.corps" -X POST "$BASE/api/auth/login" "${JSON[@]}" \
  -H "Origin: $ORIGINE" --data-binary "@$T/a.json"
pose=$(grep -i '^set-cookie:' "$T/login.entetes" | head -1 | tr -d '\r')
printf 'Cookie: %s\n' "$(printf '%s' "$pose" | sed -E 's/^[Ss]et-[Cc]ookie: *([^;]*).*/\1/')" > "$T/session.h"
S=(-H "@$T/session.h")
assert "POST /api/auth/login → 200" 200 "$(sed -n '1s/^HTTP[^ ]* \([0-9]*\).*/\1/p' "$T/login.entetes")"
verifier "cookie HttpOnly" "printf '%s' \"\$pose\" | grep -qi 'httponly'"
verifier "cookie SameSite=Strict" "printf '%s' \"\$pose\" | grep -qi 'samesite=strict'"
verifier "cookie Path=/ et sans Domain" "printf '%s' \"\$pose\" | grep -qi 'path=/' && ! printf '%s' \"\$pose\" | grep -qi 'domain='"
if [ "${E2E_COOKIE_SECURE:-1}" = 1 ]; then
  verifier "cookie Secure, nom préfixé __Host-" "printf '%s' \"\$pose\" | grep -qi '; *secure' && printf '%s' \"\$pose\" | grep -q '__Host-'"
fi
assert "GET /api/auth/me avec le cookie → 200" 200 "$(code "${S[@]}" "$BASE/api/auth/me")"
assert "GET /api/todos avec le cookie → 200" 200 "$(code "${S[@]}" "$BASE/api/todos")"
par_cookie=$(rep "${S[@]}" -H "Origin: $ORIGINE" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"par le front"}')
assert "POST avec le cookie et la bonne origine → 201" 201 "$(code_de "$par_cookie")"
id3=$(champ id "$(corps_de "$par_cookie")")
assert "POST avec le cookie, origine étrangère → 403" 403 "$(code "${S[@]}" -H 'Origin: https://pirate.exemple.test' -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"csrf"}')"
assert "POST avec le cookie, sans en-tête Origin → 403" 403 "$(code "${S[@]}" -X POST "$BASE/api/todos" "${JSON[@]}" -d '{"title":"csrf"}')"
assert "DELETE avec le cookie, origine étrangère → 403" 403 "$(code "${S[@]}" -H 'Origin: https://pirate.exemple.test' -X DELETE "$BASE/api/todos/$id3")"
assert "connexion demandée depuis une origine étrangère → 403" 403 "$(code -X POST "$BASE/api/auth/login" "${JSON[@]}" -H 'Origin: https://pirate.exemple.test' --data-binary "@$T/a.json")"
sed 's/^Cookie: [^=]*=/Authorization: Bearer /' "$T/session.h" > "$T/session-en-jeton.h"
assert "la valeur du cookie ne vaut pas jeton porteur → 401" 401 "$(code -H "@$T/session-en-jeton.h" "$BASE/api/todos")"
assert "DELETE avec le cookie et la bonne origine (nettoyage) → 200" 200 "$(code "${S[@]}" -H "Origin: $ORIGINE" -X DELETE "$BASE/api/todos/$id3")"
assert "POST /api/auth/logout (cookie) → 200" 200 "$(code "${S[@]}" -H "Origin: $ORIGINE" -X POST "$BASE/api/auth/logout")"
assert "après déconnexion, le cookie est refusé → 401" 401 "$(code "${S[@]}" "$BASE/api/todos")"

if [ "$PROFIL" = complet ]; then
echo "— limite d'essais de connexion (courriel jetable : les comptes du smoke ne sont pas verrouillés)"
identifiants limite "limite-$(alea 6)@exemple.test" "$(alea)"
essais=""
for _ in 1 2 3 4 5; do essais="$essais$(code -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/limite.json") "; done
assert "cinq essais échoués → 401 chacun" "401 401 401 401 401 " "$essais"
assert "sixième essai → 429" 429 "$(code -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/limite.json")"
assert "le compte A n'est pas verrouillé par ces essais → 200" 200 "$(code "${A[@]}" "$BASE/api/auth/me")"
fi

echo "— seuls public/ et l'API sont servis"
chemins="/.env /.git/config /.git/ /app/config.py /requirements.txt /requirements.lock /database/
  /database/migrations/pending/0001_create_todos.up.sql /wsgi.py /lancer.sh /deps/
  /%2e%2e/requirements.txt /..%2f.env /../app/config.py"
[ "$PROFIL" = complet ] || chemins="/.env /app/config.py /database/migrations/pending/0001_create_todos.up.sql /wsgi.py"
for chemin in $chemins; do
  r=$(rep --path-as-is "$BASE$chemin")
  c=$(code_de "$r")
  case "$c" in 400|403|404) bon=1 ;; *) bon=0 ;; esac
  if printf '%s' "$r" | grep -qE 'CREATE TABLE|fastapi==|def dsn|DATABASE_URL|TODO_SECRET_KEY|\[core\]'; then bon=0; fi
  if [ "$bon" = 1 ]; then ok "$chemin n'est pas servi ($c)"; else ko "$chemin : réponse $c, ou contenu de fichier renvoyé"; fi
done
assert "la page du front est servie → 200" 200 "$(code "$BASE/")"

echo "— en-têtes de sécurité émis par l'application"
cas_entetes=("page:/" "API:/api/health" "refus 401:/api/todos" "fichier absent:/introuvable")
[ "$PROFIL" = complet ] || cas_entetes=("page:/" "API:/api/health")
for cas in "${cas_entetes[@]}"; do
  nom="${cas%%:*}"; chemin="${cas#*:}"
  "${C[@]}" -D "$T/entetes" -o /dev/null "$BASE$chemin"
  for entete in strict-transport-security x-content-type-options referrer-policy; do
    verifier "$nom ($chemin) : $entete" "grep -qi '^$entete:' '$T/entetes'"
  done
  verifier "$nom ($chemin) : interdiction d'inclusion en cadre" \
    "grep -qi '^x-frame-options: *DENY' '$T/entetes' && grep -i '^content-security-policy:' '$T/entetes' | grep -q \"frame-ancestors 'none'\""
done

echo "— nettoyage : le smoke ne laisse ni todo ni jeton"
assert "DELETE de la seconde tâche de A → 200" 200 "$(code "${A[@]}" -X DELETE "$BASE/api/todos/$id2")"
assert "DELETE du todo de B → 200" 200 "$(code "${B[@]}" -X DELETE "$BASE/api/todos/$de_b")"
verifier "A et B retrouvent leur nombre de todos de départ" "[ \"\$(compter \"\${A[@]}\")\" = $avant_a ] && [ \"\$(compter \"\${B[@]}\")\" = $avant_b ]"
verifier "A et B n'ont plus aucun todo du smoke" \
  "! \"\${C[@]}\" \"\${A[@]}\" \"$BASE/api/todos\" | grep -q '$id2' && ! \"\${C[@]}\" \"\${B[@]}\" \"$BASE/api/todos\" | grep -q '$de_b'"
assert "POST /api/auth/logout (jeton de A) → 200" 200 "$(code "${A[@]}" -X POST "$BASE/api/auth/logout")"
assert "le jeton révoqué de A est refusé → 401" 401 "$(code "${A[@]}" "$BASE/api/todos")"
assert "POST /api/auth/logout (jeton de B) → 200" 200 "$(code "${B[@]}" -X POST "$BASE/api/auth/logout")"

if [ "$LOCAL" = 1 ]; then
  echo "— aucun mot de passe ni jeton en clair, en base ou dans le journal (local)"
  verifier "table des comptes : hachage Argon2id pour chaque compte" \
    "[ \"\$(kit_sql \"SELECT COUNT(*) FROM accounts WHERE password_hash NOT LIKE '\\\$argon2id\\\$%'\")\" = 0 ] && [ \"\$(kit_sql 'SELECT COUNT(*) FROM accounts')\" = 2 ]"
  docker logs "$cid" > "$T/journal" 2>&1
  { kit_sql "SELECT accounts::text FROM accounts"; kit_sql "SELECT auth_tokens::text FROM auth_tokens"; kit_sql "SELECT login_attempts::text FROM login_attempts"; } > "$T/base"
  for secret in "$MDP_A" "$MDP_B" "$(sed 's/^Authorization: Bearer //' "$T/a.h")" "$(sed 's/^Cookie: [^=]*=//' "$T/session.h")"; do
    printf '%s\n' "$secret"
  done > "$T/secrets"
  verifier "ni mot de passe ni jeton en clair dans la base" "! grep -qFf '$T/secrets' '$T/base'"
  verifier "ni mot de passe ni jeton dans le journal du serveur" "[ -s '$T/journal' ] && ! grep -qFf '$T/secrets' '$T/journal'"
  verifier "les essais de connexion ne gardent aucun courriel" "! grep -q '@' <(kit_sql 'SELECT subject FROM login_attempts')"

  echo "— erreur de base de données : réponse générique (local)"
  docker stop "$cid" >/dev/null
  cid=$(demarrer -e DB_PORT=1)   # aucun serveur de bases sur ce port
  for _ in $(seq 1 60); do [ "$(code "$BASE/api/health")" != 000 ] && break; sleep 0.5; done
  panne=$(rep -X POST "$BASE/api/auth/token" "${JSON[@]}" --data-binary "@$T/a.json")
  assert "base injoignable → 500" 500 "$(code_de "$panne")"
  verifier "corps générique, sans trace ni identifiant" \
    "[ \"\$(corps_de \"\$panne\")\" = '{\"error\":\"Erreur interne.\"}' ] && ! printf '%s' \"\$panne\" | grep -qiE 'traceback|psycopg|$KIT_DB|127\\.0\\.0\\.1|connection'"
  assert "sonde de santé, base injoignable → 503" 503 "$(code "$BASE/api/health")"
  "${C[@]}" -D "$T/entetes" -o /dev/null "$BASE/api/todos"
  verifier "en-têtes de sécurité présents sur l'erreur" "grep -qi '^x-content-type-options:' '$T/entetes'"
  docker logs "$cid" > "$T/journal-panne" 2>&1
  verifier "le journal de la panne ne contient pas le mot de passe de la base" "! grep -qF 'password=$KIT_DB' '$T/journal-panne'"
fi

echo ""
if [ "$fail" = 0 ]; then echo "e2e (smoke HTTP, $cible): 🟢"; else echo "e2e ($cible): 🔴"; fi
exit "$fail"
