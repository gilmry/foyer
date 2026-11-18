#!/usr/bin/env bash
# Gate `unit` + `bdd` (domaine + application + couche HTTP sur doubles), sans DB — via Docker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image
exec docker run --rm -v "$ROOT":/app:ro -w /app -e PYTHONPATH=/app todo-kit-fastapi:local \
  python -m pytest -p no:cacheprovider tests/unit tests/application tests/http -q "$@"
