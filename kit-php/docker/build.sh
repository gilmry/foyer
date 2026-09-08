#!/usr/bin/env bash
# Construit les images du kit à partir de bases PUBLIQUES (aucune image privée requise).
# À lancer une fois après clone. Idempotent. Cf. AGENTS.md du kit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "▶ todo-kit-php:local (php:8.3-cli + pdo_mysql)…"
docker build -q -t todo-kit-php:local -f "$ROOT/docker/php.Dockerfile" "$ROOT/docker" >/dev/null

echo "▶ todo-kit-visual:local (node:22-bookworm + Chromium Playwright)…"
docker build -q -t todo-kit-visual:local "$ROOT/harness/visual" >/dev/null

echo "✓ images prêtes : todo-kit-php:local, todo-kit-visual:local"
