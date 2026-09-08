#!/usr/bin/env bash
# Gate `visuel` — régression d'apparence par goldens (Chromium Playwright).
#   VISUAL_MODE=capture → (ré)écrit les goldens        VISUAL_MODE=compare → gate (défaut)
# Prérequis : MySQL `todo-mysql` up + serveur web `todo-web` sur :8080 (démarrés ci-dessous si absents).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${VISUAL_MODE:-compare}"
IMAGE="todo-kit-visual:local"

source "$ROOT/harness/ensure-images.sh"
ensure_php_image        # serveur web + seed
ensure_visual_image     # Chromium
ensure_visual_modules   # node_modules côté hôte (le montage masque ceux de l'image)

# 1. MySQL + table.
docker ps --filter name=todo-mysql --format '{{.Names}}' | grep -q todo-mysql || \
  docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
    -p 13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password >/dev/null
for i in $(seq 1 30); do docker exec todo-mysql mysqladmin ping -uroot -proot --silent 2>/dev/null | grep -q alive && break; sleep 1; done
docker run --rm --network host -v "$ROOT":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 todo-kit-php:local php -r '
  require "/app/src/bootstrap.php";
  $db = TodoApp\Database::connect(["db"=>["host"=>"127.0.0.1","port"=>13306,"database"=>"todo","username"=>"root","password"=>"root","charset"=>"utf8mb4"]]);
  $db->exec("DROP TABLE IF EXISTS todos");
  $db->exec(file_get_contents("/app/database/migrations/pending/0001_create_todos.up.sql"));
'

# 2. Serveur web.
docker rm -f todo-web >/dev/null 2>&1 || true
docker run -d --name todo-web --network host -v "$ROOT":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 -e DB_NAME=todo -e DB_USER=root -e DB_PASSWORD=root \
  todo-kit-php:local php -S 127.0.0.1:8080 -t public harness/dev-router.php >/dev/null
trap 'docker rm -f todo-web >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 20); do curl -sf http://127.0.0.1:8080/api/todos >/dev/null 2>&1 && break; sleep 0.5; done

# 3. Seed du parcours de référence (données stables pour un golden reproductible).
curl -s -X POST http://127.0.0.1:8080/api/todos -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}' >/dev/null
curl -s -X POST http://127.0.0.1:8080/api/todos -H 'Content-Type: application/json' -d '{"title":"réviser Foyer"}' >/dev/null
curl -s -X POST http://127.0.0.1:8080/api/todos -H 'Content-Type: application/json' -d '{"title":"préparer la démo"}' >/dev/null

# 4. Capture / comparaison.
exec docker run --rm --network host -v "$ROOT":/app -w /app/harness/visual \
  -e VISUAL_MODE="$MODE" -e VISUAL_BASE_URL=http://127.0.0.1:8080 \
  "$IMAGE" node visual.mjs
