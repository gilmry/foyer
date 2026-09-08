#!/usr/bin/env bash
# Gate `unit` + `bdd` (domaine + application), sans DB — via Docker (base publique).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image
exec docker run --rm -v "$ROOT":/app -w /app -e PYTHONPATH=/app todo-kit-fastapi:local \
  python -m pytest tests/unit tests/application -q "${@:-}"
