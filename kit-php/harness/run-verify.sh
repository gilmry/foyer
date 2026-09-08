#!/usr/bin/env bash
# Gate `verify` / `plancher` — via Docker (pas de PHP local requis).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${TODO_PHP_IMAGE:-php:8.3-cli}"
exec docker run --rm -v "$ROOT":/app -w /app "$IMAGE" php /app/harness/verify.php
