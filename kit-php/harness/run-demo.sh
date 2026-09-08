#!/usr/bin/env bash
# run-demo.sh — documentation vidéo vivante (preuve de valeur, NON bloquant).
# Rejoue le parcours de référence en cadence, filme la vidéo, assemble la vitrine.
# Réutilise l'image et les node_modules du harnais visuel (Playwright + Chromium).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="todo-kit-visual:local"

source "$ROOT/harness/ensure-images.sh"
ensure_php_image
ensure_visual_image
ensure_visual_modules

# node_modules partagés avec le harnais visuel (DRY, comme le kit).
[ -e "$ROOT/harness/demo/node_modules" ] || ln -s ../visual/node_modules "$ROOT/harness/demo/node_modules"

# 1. MySQL + table vierge (démo déterministe).
docker ps --filter name=todo-mysql --format '{{.Names}}' | grep -q todo-mysql || \
  docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
    -p 13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password >/dev/null
for i in $(seq 1 30); do docker exec todo-mysql mysqladmin ping -uroot -proot --silent 2>/dev/null | grep -q alive && break; sleep 1; done
docker run --rm --network host -v "$ROOT":/app -w /app -e DB_HOST=127.0.0.1 -e DB_PORT=13306 todo-kit-php:local php -r '
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

# 3. Enregistrement + vitrine.
docker run --rm --network host -v "$ROOT":/app -w /app/harness/demo \
  -e DEMO_BASE_URL=http://127.0.0.1:8080 "$IMAGE" bash -lc 'node record-todo.mjs && node assembler-vitrine.mjs'

echo ""
echo "doc vivante: 🟢 → harness/demo/vitrine/index.html"
