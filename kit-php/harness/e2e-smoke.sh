#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — exerce le parcours de référence via le serveur PHP réel + MySQL,
# sans navigateur : create → list → toggle → delete, en vérifiant les codes HTTP.
# L'apparence est couverte par le gate `visuel` (harness/run-visual.sh, Chromium + goldens).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${TODO_PHP_IMAGE:-todo-kit-php:local}"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_mysql
BASE="http://127.0.0.1:8080"

cid=$(docker run -d --rm --network host \
  -v "$ROOT":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 \
  -e DB_NAME=todo -e DB_USER=root -e DB_PASSWORD=root \
  "$IMAGE" php -S 127.0.0.1:8080 -t public harness/dev-router.php)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

# Prépare la table (migration up) via le conteneur.
docker exec "$cid" php -r '
  require "/app/src/bootstrap.php";
  $db = TodoApp\Database::connect(["db"=>["host"=>"127.0.0.1","port"=>13306,"database"=>"todo","username"=>"root","password"=>"root","charset"=>"utf8mb4"]]);
  $db->exec("DROP TABLE IF EXISTS todos");
  $db->exec(file_get_contents("/app/database/migrations/pending/0001_create_todos.up.sql"));
'

# Attendre que le serveur réponde.
for i in $(seq 1 20); do curl -sf "$BASE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done

fail=0
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; else echo "  ✗ $1 : attendu $2, obtenu $3"; fail=1; fi; }

code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

# @happy — création
created=$(curl -s -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}')
id=$(printf '%s' "$created" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
assert "POST /api/todos → 201" 201 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"seconde"}')"

# @negative — libellé vide → 400
assert "POST libellé vide → 400" 400 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":""}')"

# @happy — liste
assert "GET /api/todos → 200" 200 "$(code "$BASE/api/todos")"

# @happy — toggle
assert "PATCH /api/todos/{id} → 200" 200 "$(code -X PATCH "$BASE/api/todos/$id")"

# @negative — toggle id inconnu → 404
assert "PATCH id inconnu → 404" 404 "$(code -X PATCH "$BASE/api/todos/inconnu")"

# @happy — delete
assert "DELETE /api/todos/{id} → 200" 200 "$(code -X DELETE "$BASE/api/todos/$id")"

# @negative — delete id inconnu → 404
assert "DELETE id inconnu → 404" 404 "$(code -X DELETE "$BASE/api/todos/inconnu")"

echo ""
if [ "$fail" = 0 ]; then echo "e2e (smoke HTTP): 🟢"; else echo "e2e (smoke HTTP): 🔴"; fi
exit "$fail"
