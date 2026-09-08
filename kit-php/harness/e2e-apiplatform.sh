#!/usr/bin/env bash
# Gate `e2e` (adaptateur HTTP API Platform) — même parcours de référence, câblé aux MÊMES use-cases
# via State Provider/Processor. Conventions propres à API Platform : DELETE→204, collection=tableau.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_vendor; ensure_mysql
BASE="http://127.0.0.1:8080"

# Table fraîche (migration up).
docker run --rm --network host -v "$ROOT":/app -w /app -e DB_HOST=127.0.0.1 -e DB_PORT=13306 \
  todo-kit-php:local php -r '
  require "src/bootstrap.php";
  $db = TodoApp\Database::connect(["db"=>["host"=>"127.0.0.1","port"=>13306,"database"=>"todo","username"=>"root","password"=>"root","charset"=>"utf8mb4"]]);
  $db->exec("DROP TABLE IF EXISTS todos"); $db->exec(file_get_contents("database/migrations/pending/0001_create_todos.up.sql"));'

cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 -e DB_NAME=todo -e DB_USER=root -e DB_PASSWORD=root \
  -e TODO_HTTP=apiplatform \
  todo-kit-php:local php -S 127.0.0.1:8080 -t public harness/dev-router.php)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

for i in $(seq 1 30); do curl -sf "$BASE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done

fail=0
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; else echo "  ✗ $1 : attendu $2, obtenu $3"; fail=1; fi; }

created=$(curl -s -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}')
id=$(printf '%s' "$created" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
assert "POST /api/todos → 201" 201 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"seconde"}')"
assert "POST libellé vide → 400" 400 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"  "}')"
assert "GET /api/todos → 200" 200 "$(code "$BASE/api/todos")"
assert "PATCH /api/todos/{id} → 200" 200 "$(code -X PATCH "$BASE/api/todos/$id" -H 'Content-Type: application/json' -d '{}')"
assert "PATCH id inconnu → 404" 404 "$(code -X PATCH "$BASE/api/todos/inconnu" -H 'Content-Type: application/json' -d '{}')"
assert "DELETE /api/todos/{id} → 204 (convention API Platform)" 204 "$(code -X DELETE "$BASE/api/todos/$id")"
assert "DELETE id inconnu → 404" 404 "$(code -X DELETE "$BASE/api/todos/inconnu")"

echo ""
if [ "$fail" = 0 ]; then echo "e2e (API Platform): 🟢"; else echo "e2e (API Platform): 🔴"; fi
exit "$fail"
