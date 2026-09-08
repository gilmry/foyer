#!/usr/bin/env bash
# Gate `unit` + `bdd` (domaine + application) — exécuté via Docker, sans PHP local.
# Le phar PHPUnit est mis en cache dans harness/.phpunit.phar (le kit reste sans vendor/).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/harness/.phpunit.phar"
IMAGE="${TODO_PHP_IMAGE:-php:8.3-cli}"

if [ ! -s "$CACHE" ]; then
  echo "[harnais] téléchargement de phpunit.phar (le kit le bundle normalement)…"
  docker run --rm -v "$ROOT":/app -w /app "$IMAGE" \
    php -r 'copy("https://phar.phpunit.de/phpunit-11.phar","/app/harness/.phpunit.phar");'
fi

exec docker run --rm -v "$ROOT":/app -w /app -e TZ=UTC "$IMAGE" \
  php /app/harness/.phpunit.phar -c /app/harness/phpunit.xml "${@:-}"
