#!/usr/bin/env bash
# Gate `visuel` — régression d'apparence par goldens (Chromium). VISUAL_MODE=capture|compare.
# Le harnais crée un compte (inscription ouverte par serve.sh, mot de passe tiré à chaque fois),
# y sème le parcours de référence par l'API, puis le navigateur se connecte par le formulaire.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${VISUAL_MODE:-compare}"
BASE=http://127.0.0.1:8080
source "$ROOT/harness/ensure-images.sh"; ensure_visual_image; ensure_visual_modules

cid=$(bash "$ROOT/harness/serve.sh")
T="$(mktemp -d)"; chmod 700 "$T"
trap 'docker stop "$cid" >/dev/null 2>&1 || true; rm -rf "$T"' EXIT

# Compte et données stables (le courriel s'affiche : il est fixe ; le mot de passe, lui, est tiré).
EMAIL=demo@exemple.test
MDP="$(kit_alea 18)"
printf '{"email":"%s","password":"%s"}' "$EMAIL" "$MDP" > "$T/compte.json"
curl -sf -o /dev/null -X POST "$BASE/api/auth/register" -H 'Content-Type: application/json' --data-binary "@$T/compte.json"
jeton=$(curl -sf -X POST "$BASE/api/auth/token" -H 'Content-Type: application/json' --data-binary "@$T/compte.json" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
printf 'Authorization: Bearer %s\n' "$jeton" > "$T/jeton.h"
for t in "acheter du pain" "réviser Foyer" "préparer la démo"; do
  curl -sf -o /dev/null -X POST "$BASE/api/todos" -H "@$T/jeton.h" -H 'Content-Type: application/json' -d "{\"title\":\"$t\"}"
done

docker run --rm --network host -v "$ROOT":/app -w /app/harness/visual \
  -e VISUAL_MODE="$MODE" -e VISUAL_BASE_URL="$BASE" -e VISUAL_EMAIL="$EMAIL" -e VISUAL_PASSWORD="$MDP" \
  todo-kit-visual:local node visual.mjs
