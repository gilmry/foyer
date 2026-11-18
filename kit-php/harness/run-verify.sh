#!/usr/bin/env bash
# Gate `verify` / `plancher` — via Docker (pas de PHP local requis).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image
IMAGE="${TODO_PHP_IMAGE:-todo-kit-php:local}"
exec docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT":/app -w /app "$IMAGE" php /app/harness/verify.php
