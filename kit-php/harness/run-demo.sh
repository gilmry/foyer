#!/usr/bin/env bash
# run-demo.sh — documentation vidéo vivante (preuve de valeur, NON bloquant).
# Rejoue le parcours de référence en cadence (inscription, connexion, tâches, déconnexion) sur
# l'adaptateur HTTP de référence, filme la vidéo, assemble la vitrine.
# Réutilise l'image et les node_modules du harnais visuel (Playwright + Chromium).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="todo-kit-visual:local"

source "$ROOT/harness/ensure-images.sh"
ensure_php_image
ensure_vendor
ensure_visual_image
ensure_visual_modules

# node_modules partagés avec le harnais visuel (DRY, comme le kit).
[ -e "$ROOT/harness/demo/node_modules" ] || ln -s ../visual/node_modules "$ROOT/harness/demo/node_modules"

# 1. MySQL (login sans privilège) + base vide + migrations (démo déterministe), puis le serveur web.
TMP="$(mktemp -d)"
trap 'kit_stop; rm -rf "$TMP"' EXIT
ensure_mysql || exit 1
kit_reset_db || exit 1
kit_serve apiplatform "${TODO_PERSISTENCE:-cqrs}" || exit 1

# 2. Compte de la démonstration : créé À L'ÉCRAN par l'inscription (ouverte dans le harnais).
#    Mot de passe tiré à chaque passage, transmis par un fichier d'environnement à droits 600.
( umask 077; printf 'DEMO_EMAIL=demo@exemple.test\nDEMO_PASSWORD=%s\n' "$(openssl rand -hex 16)" > "$TMP/demo.env" )

# 3. Enregistrement + vitrine.
docker run --rm --network host -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$ROOT":/app -w /app/harness/demo \
  --env-file "$TMP/demo.env" -e DEMO_BASE_URL=http://127.0.0.1:8080 "$IMAGE" bash -lc 'node record-todo.mjs && node assembler-vitrine.mjs' || exit 1

echo ""
echo "doc vivante: 🟢 → harness/demo/vitrine/index.html"
