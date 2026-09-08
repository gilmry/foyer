#!/usr/bin/env bash
# Gate `integration` — MySQL éphémère + exécution du scénario PDO réel via Docker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Image dev du kit : embarque pdo_mysql (le php:8.3-cli nu ne l'a pas).
IMAGE="${TODO_PHP_IMAGE:-todo-kit-php:local}"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_vendor; ensure_mysql

# Le conteneur MySQL doit tourner (voir README). --network host → atteint 127.0.0.1:13306 publié.
docker run --rm --network host \
  -v "$ROOT":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 \
  -e DB_NAME=todo -e DB_USER=root -e DB_PASSWORD=root \
  "$IMAGE" php harness/integration-todos.php
