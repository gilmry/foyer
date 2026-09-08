#!/usr/bin/env bash
# run-demo.sh — documentation vidéo vivante (preuve de valeur, NON bloquant).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_visual_image; ensure_visual_modules
[ -e "$ROOT/harness/demo/node_modules" ] || ln -s ../visual/node_modules "$ROOT/harness/demo/node_modules"

cid=$(bash "$ROOT/harness/serve.sh")
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

docker run --rm --network host -v "$ROOT":/app -w /app/harness/demo \
  -e DEMO_BASE_URL=http://127.0.0.1:8080 todo-kit-visual:local \
  bash -lc 'node record-todo.mjs && node assembler-vitrine.mjs'

echo ""
echo "doc vivante: 🟢 → harness/demo/vitrine/index.html"
