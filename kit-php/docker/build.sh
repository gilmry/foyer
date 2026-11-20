#!/usr/bin/env bash
# Construit les images du kit à partir de bases PUBLIQUES (aucune image privée requise).
# À lancer une fois après clone. Idempotent. Cf. AGENTS.md du kit.
#   KIT_PHP_VERSION (défaut 8.3) : version mineure de PHP — celle du site chez l'hébergeur.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"

echo "▶ todo-kit-php:local (php:$KIT_PHP_VERSION-cli + pdo_mysql + Composer)…"
ensure_php_image

echo "▶ todo-kit-visual:local (node:22-bookworm + Chromium Playwright)…"
ensure_visual_image

echo "▶ todo-kit-php-cible:$KIT_PHP_VERSION-fcgid (cible jetable de la répétition de déploiement : Apache + mod_fcgid + php-cgi + sshd)…"
docker build -q -t "todo-kit-php-cible:$KIT_PHP_VERSION-fcgid" --build-arg PHP_VERSION="$KIT_PHP_VERSION" --build-arg VARIANTE=cli "$ROOT/harness/cible" >/dev/null

echo "✓ images prêtes : todo-kit-php:local, todo-kit-visual:local, todo-kit-php-cible:$KIT_PHP_VERSION-fcgid"
