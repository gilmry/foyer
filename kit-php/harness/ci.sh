#!/usr/bin/env bash
# CI local — rejoue tous les gates dans l'ordre (mêmes commandes qu'en CI, DRY).
# Prérequis pour integration/e2e : conteneur MySQL `todo-mysql` en écoute sur 127.0.0.1:13306
#   docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
#     -p 13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() { echo ""; echo "▶ $*"; "$@"; }

# 1. Contrat : le client généré doit être à jour (regénère puis verify vérifie l'anti-drift).
run docker run --rm -v "$ROOT":/app -w /app php:8.3-cli php harness/codegen-todos-client.php

# 2. Plancher + structurel (G1/G2/H1/C1).
run bash "$ROOT/harness/run-verify.sh"

# 3. Tests domaine + application (sans DB).
run bash "$ROOT/harness/run-phpunit.sh"

# 4. Intégration (MySQL réel).
run bash "$ROOT/harness/run-integration.sh"

# 5. E2E smoke HTTP (serveur PHP réel + MySQL).
run bash "$ROOT/harness/e2e-smoke.sh"

# 6. Régression visuelle (Chromium, goldens). VISUAL_MODE=compare par défaut.
run bash "$ROOT/harness/run-visual.sh"

echo ""
echo "CI: 🟢 tous les gates bloquants sont verts."
