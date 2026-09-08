#!/usr/bin/env bash
# Gate `contrat` — le client TYPÉ api.ts doit être à jour vs le contrat OpenAPI (anti-drift).
# Régénère api.ts et échoue si le fichier committé diffère. Tourne dans l'image node (publique).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_visual_image

docker run --rm -v "$ROOT":/app -w /app/frontend-todos todo-kit-visual:local bash -lc '
  API_TS_OUT=/tmp/api.check.ts node scripts/gen-api.mjs >/dev/null
  if diff -q /tmp/api.check.ts src/generated/api.ts >/dev/null; then
    echo "contrat: 🟢 api.ts à jour vs OpenAPI"
  else
    echo "contrat: 🔴 api.ts désynchronisé — lancer: (cd frontend-todos && npm run gen:api)"; exit 1
  fi'
