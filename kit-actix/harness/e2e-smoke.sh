#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — parcours de référence, sans navigateur.
#
# Sans variable : serveur actix réel + PostgreSQL du harnais (base vide, migrations jouées par le
#   serveur à son démarrage), login sans privilège. TODO_PERSISTENCE=cqrs|orm choisit l'adaptateur.
# Avec E2E_BASE_URL=https://… : le même parcours contre une adresse déjà en service (un déploiement
#   réel, ou la répétition locale). Ni Docker, ni remise à zéro : le smoke supprime ce qu'il crée.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSISTENCE="${TODO_PERSISTENCE:-cqrs}"

if [ -n "${E2E_BASE_URL:-}" ]; then
  BASE="${E2E_BASE_URL%/}"
  cible="$BASE"
else
  source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres
  BASE="http://127.0.0.1:8080"
  cible="local, persistance=$PERSISTENCE"

  # Compile le serveur (cache) puis le lance sur le binaire compilé.
  docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" todo-kit-rust:local cargo build --quiet --bin server
  reset_schema

  cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
    "${DB_ENV[@]}" \
    -e HTTP_HOST=127.0.0.1 -e HTTP_PORT=8080 -e TODO_MIGRER=1 -e TODO_PERSISTENCE="$PERSISTENCE" \
    todo-kit-rust:local ./target/debug/server)
  trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT
fi

C=(curl -s --max-time 20)
for i in $(seq 1 40); do "${C[@]}" -f "$BASE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done

fail=0
code() { "${C[@]}" -o /dev/null -w '%{http_code}' "$@"; }
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; else echo "  ✗ $1 : attendu $2, obtenu $3"; fail=1; fi; }
id_de() { printf '%s' "$1" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p'; }

# --- Parcours de référence : créer → lister → basculer → supprimer.
id=$(id_de "$("${C[@]}" -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}')")
seconde=$("${C[@]}" -w '\n%{http_code}' -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"seconde"}')
id2=$(id_de "$seconde")
assert "POST /api/todos → 201" 201 "$(printf '%s' "$seconde" | tail -n1)"
assert "POST libellé vide → 400" 400 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"  "}')"
assert "GET /api/todos → 200" 200 "$(code "$BASE/api/todos")"
assert "PATCH /api/todos/{id} → 200" 200 "$(code -X PATCH "$BASE/api/todos/$id")"
assert "PATCH id inconnu → 404" 404 "$(code -X PATCH "$BASE/api/todos/inconnu")"
assert "DELETE /api/todos/{id} → 200" 200 "$(code -X DELETE "$BASE/api/todos/$id")"
assert "DELETE id inconnu → 404" 404 "$(code -X DELETE "$BASE/api/todos/inconnu")"
# Le smoke ne laisse rien derrière lui : indispensable contre une adresse en service.
assert "DELETE de la seconde tâche (nettoyage) → 200" 200 "$(code -X DELETE "$BASE/api/todos/$id2")"

# --- Seuls public/ et l'API sont servis : ni sources, ni migrations, ni configuration, ni fichier caché.
for chemin in /.env /.git/config /Cargo.toml /src/main.rs /database/migrations/pending/0001_create_todos.up.sql \
              /lancer.sh /server /%2e%2e/Cargo.toml /..%2f.env; do
  rep=$("${C[@]}" --path-as-is -w '\n%{http_code}' "$BASE$chemin")
  c=$(printf '%s' "$rep" | tail -n1)
  case "$c" in 400|403|404) ok=1 ;; *) ok=0 ;; esac
  if printf '%s' "$rep" | grep -qE 'DATABASE_URL|CREATE TABLE|\[package\]|actix_web'; then ok=0; fi
  if [ "$ok" = 1 ]; then echo "  ✓ $chemin n'est pas servi ($c)"; else echo "  ✗ $chemin : réponse $c, ou contenu de fichier renvoyé"; fail=1; fi
done

# --- En-têtes de sécurité émis par l'application, sur une page ET sur une réponse d'API.
for url in "$BASE/" "$BASE/api/todos"; do
  h=$("${C[@]}" -o /dev/null -D - "$url" | tr -d '\r' | tr 'A-Z' 'a-z')
  for attendu in 'strict-transport-security: max-age=' 'x-content-type-options: nosniff' 'x-frame-options: deny' 'referrer-policy: '; do
    if printf '%s' "$h" | grep -q "^$attendu"; then echo "  ✓ ${url#"$BASE"} porte « ${attendu%%:*} »"; else echo "  ✗ ${url#"$BASE"} : en-tête « ${attendu%%:*} » absent"; fail=1; fi
  done
done

echo ""
if [ "$fail" = 0 ]; then echo "e2e (smoke HTTP, $cible): 🟢"; else echo "e2e ($cible): 🔴"; fi
exit "$fail"
