#!/usr/bin/env bash
# Gate `visuel` — régression d'apparence par goldens (Chromium Playwright), sur l'adaptateur HTTP
# de référence (API Platform) : formulaire de connexion, puis la liste après connexion PAR L'UI.
#   VISUAL_MODE=capture → (ré)écrit les goldens        VISUAL_MODE=compare → gate (défaut)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${VISUAL_MODE:-compare}"
IMAGE="todo-kit-visual:local"
BASE=http://127.0.0.1:8080

source "$ROOT/harness/ensure-images.sh"
ensure_php_image        # serveur web + seed
ensure_vendor
ensure_visual_image     # Chromium
ensure_visual_modules   # node_modules côté hôte (le montage masque ceux de l'image)

# 1. MySQL (login sans privilège) + base vide + migrations, puis le serveur web.
TMP="$(mktemp -d)"
trap 'kit_stop; rm -rf "$TMP"' EXIT
ensure_mysql
kit_reset_db
kit_serve apiplatform "${TODO_PERSISTENCE:-cqrs}"

# 2. Compte du parcours : courriel fixe (il figure dans le golden), mot de passe tiré à chaque
#    passage, transmis par l'entrée standard et par un fichier d'environnement à droits 600.
EMAIL=demo@exemple.test
( umask 077; printf 'VISUAL_EMAIL=%s\nVISUAL_PASSWORD=%s\n' "$EMAIL" "$(openssl rand -hex 16)" > "$TMP/visual.env" )
sed -n 's/^VISUAL_PASSWORD=//p' "$TMP/visual.env" | kit_php php bin/account.php create "$EMAIL" >/dev/null

# 3. Seed du parcours de référence par l'API, avec un jeton porteur (données stables → golden reproductible).
printf 'Authorization: Bearer %s' "$(kit_php php bin/account.php token "$EMAIL" 2>/dev/null)" > "$TMP/jeton.hdr"
for titre in "acheter du pain" "réviser Foyer" "préparer la démo"; do
  curl -s -o /dev/null -X POST "$BASE/api/todos" -H "@$TMP/jeton.hdr" -H 'Content-Type: application/json' -d "{\"title\":\"$titre\"}"
  sleep 1.1   # dates de création distinctes (à la seconde) → ordre de la liste stable d'un passage à l'autre
done

# 4. Capture / comparaison, sur l'adaptateur de référence (session par cookie).
visuel() {
  docker run --rm --network host -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$ROOT":/app -w /app/harness/visual \
    --env-file "$TMP/visual.env" -e VISUAL_MODE="$MODE" -e VISUAL_BASE_URL="$BASE" "$@" "$IMAGE" node visual.mjs
}
visuel

# 5. Le même îlot sur l'adaptateur vanilla : pas de session, on colle un jeton porteur. Parcours
#    fonctionnel seulement (pas de golden) : il prouve que le front marche sur les deux adaptateurs.
kit_serve vanilla "${TODO_PERSISTENCE:-cqrs}"
( umask 077; printf 'VISUAL_TOKEN=%s\n' "$(kit_php php bin/account.php token "$EMAIL" 2>/dev/null)" >> "$TMP/visual.env" )
visuel -e VISUAL_SCENARIO=jeton
