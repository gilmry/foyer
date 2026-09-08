#!/usr/bin/env bash
# Gate `verify` / `plancher` — via Docker (base publique). Régénère aussi contrat + client.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image
# verify.py compare le contrat committé au contrat réel de l'app (ne PAS dumper ici, sinon la
# dérive serait masquée). Pour regénérer le contrat après un changement voulu :
#   docker run … todo-kit-fastapi:local python harness/dump_openapi.py  (puis npm run gen:api)
exec docker run --rm -v "$ROOT":/app -w /app -e PYTHONPATH=/app todo-kit-fastapi:local \
  python harness/verify.py
