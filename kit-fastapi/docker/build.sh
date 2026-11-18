#!/usr/bin/env bash
# Construit les images du kit à partir de bases PUBLIQUES (aucune image privée requise).
# À lancer une fois après clone. Idempotent : l'image Python est reconstruite quand le verrou
# des dépendances (requirements-dev.lock) a changé.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"

echo "▶ todo-kit-fastapi:local (python:3.12-slim-bookworm + dépendances verrouillées)…"
ensure_py_image

echo "▶ todo-kit-visual:local (node:22-bookworm + Chromium Playwright)…"
ensure_visual_image

echo "✓ images prêtes : todo-kit-fastapi:local, todo-kit-visual:local"
echo "  (PostgreSQL est lancé à la demande par les gates — image publique postgres:16)"
