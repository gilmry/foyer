#!/usr/bin/env bash
# Construit les images du kit à partir de bases PUBLIQUES (aucune image privée requise).
# À lancer une fois après clone. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "▶ todo-kit-rust:local (rust:1-slim-bookworm)…"
docker build -q -t todo-kit-rust:local -f "$ROOT/docker/rust.Dockerfile" "$ROOT/docker" >/dev/null

echo "▶ todo-kit-visual:local (node:22-bookworm + Chromium Playwright)…"
docker build -q -t todo-kit-visual:local "$ROOT/harness/visual" >/dev/null

echo "✓ images prêtes : todo-kit-rust:local, todo-kit-visual:local"
echo "  (PostgreSQL est lancé à la demande par les gates — image publique postgres:16)"
