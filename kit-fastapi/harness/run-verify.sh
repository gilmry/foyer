#!/usr/bin/env bash
# Gate `verify` / `plancher` — via Docker (base publique). Régénère aussi contrat + client.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image
exec docker run --rm -v "$ROOT":/app -w /app -e PYTHONPATH=/app todo-kit-fastapi:local bash -lc '
  python harness/dump_openapi.py && python harness/codegen_client.py && python harness/verify.py'
