#!/usr/bin/env bash
# Gate `visuel` — régression d'apparence par goldens (Chromium). VISUAL_MODE=capture|compare.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${VISUAL_MODE:-compare}"
source "$ROOT/harness/ensure-images.sh"; ensure_visual_image; ensure_visual_modules

cid=$(bash "$ROOT/harness/serve.sh")
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

# Une seconde entre deux créations : la liste est triée par created_at (à la seconde) puis par
# UUID aléatoire ; trois tâches créées dans la même seconde s'affichent dans un ordre tiré au sort.
for t in "acheter du pain" "réviser Foyer" "préparer la démo"; do
  curl -s -X POST http://127.0.0.1:8080/api/todos -H 'Content-Type: application/json' -d "{\"title\":\"$t\"}" >/dev/null
  sleep 1.1
done

exec docker run --rm --network host -v "$ROOT":/app -w /app/harness/visual \
  -e VISUAL_MODE="$MODE" -e VISUAL_BASE_URL=http://127.0.0.1:8080 \
  todo-kit-visual:local node visual.mjs
