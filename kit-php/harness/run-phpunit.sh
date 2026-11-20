#!/usr/bin/env bash
# Gate `unit` + `bdd` (domaine + application) — exécuté via Docker, sans PHP local ni base.
# Le phar PHPUnit est versionné dans harness/.phpunit.phar (aucun vendor/ requis pour ce gate).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image
CACHE="$ROOT/harness/.phpunit.phar"
IMAGE="${TODO_PHP_IMAGE:-todo-kit-php:local}"

if [ ! -s "$CACHE" ]; then
  echo "[harnais] téléchargement de phpunit.phar (le kit le bundle normalement)…"
  docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT":/app -w /app "$IMAGE" \
    php -r 'copy("https://phar.phpunit.de/phpunit-11.phar","/app/harness/.phpunit.phar");'
fi

exec docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT":/app -w /app -e TZ=UTC "$IMAGE" \
  php /app/harness/.phpunit.phar -c /app/harness/phpunit.xml "${@:-}"
