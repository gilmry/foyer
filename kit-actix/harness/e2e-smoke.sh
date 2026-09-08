#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — parcours de référence via le serveur actix réel + PostgreSQL, sans navigateur.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres
BASE="http://127.0.0.1:8080"

# Compile le serveur (cache) puis le lance sur le binaire compilé.
docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" todo-kit-rust:local cargo build --quiet --bin server
reset_schema

cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
  -e DB_HOST=127.0.0.1 -e DB_PORT=15432 -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo \
  -e HTTP_HOST=127.0.0.1 -e HTTP_PORT=8080 \
  todo-kit-rust:local ./target/debug/server)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

for i in $(seq 1 40); do curl -sf "$BASE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done

fail=0
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; else echo "  ✗ $1 : attendu $2, obtenu $3"; fail=1; fi; }

created=$(curl -s -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}')
id=$(printf '%s' "$created" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
assert "POST /api/todos → 201" 201 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"seconde"}')"
assert "POST libellé vide → 400" 400 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"  "}')"
assert "GET /api/todos → 200" 200 "$(code "$BASE/api/todos")"
assert "PATCH /api/todos/{id} → 200" 200 "$(code -X PATCH "$BASE/api/todos/$id")"
assert "PATCH id inconnu → 404" 404 "$(code -X PATCH "$BASE/api/todos/inconnu")"
assert "DELETE /api/todos/{id} → 200" 200 "$(code -X DELETE "$BASE/api/todos/$id")"
assert "DELETE id inconnu → 404" 404 "$(code -X DELETE "$BASE/api/todos/inconnu")"

echo ""
if [ "$fail" = 0 ]; then echo "e2e (smoke HTTP): 🟢"; else echo "e2e: 🔴"; fi
exit "$fail"
