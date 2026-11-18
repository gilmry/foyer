#!/usr/bin/env bash
# CI local — rejoue tous les gates dans l'ordre (mêmes commandes qu'en CI, DRY).
# Les gates montent eux-mêmes ce qu'il leur faut : le MySQL `todo-mysql` (127.0.0.1:13306, login
# applicatif sans privilège `kit_php_app`), les images, vendor/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() { echo ""; echo "▶ $*"; "$@"; }

# 1. Plancher + structurel (G1/G2/H1/C1/D1).
run bash "$ROOT/harness/run-verify.sh"

# 2. Contrat : client TYPÉ api.ts à jour vs OpenAPI (anti-drift, image node).
run bash "$ROOT/harness/run-contract.sh"

# 3. Tests domaine + application (sans DB).
run bash "$ROOT/harness/run-phpunit.sh"

# 4. Intégration (MySQL réel, login sans privilège ; migrations, cloisonnement CQRS et Doctrine).
run bash "$ROOT/harness/run-integration.sh"

# 5. E2E smoke HTTP (serveur PHP réel + MySQL).
run bash "$ROOT/harness/e2e-smoke.sh"        # adaptateur HTTP vanilla (jeton porteur)
run bash "$ROOT/harness/e2e-apiplatform.sh"  # adaptateur HTTP de référence : API Platform (session + jeton)

# 6. Régression visuelle (Chromium, goldens). VISUAL_MODE=compare par défaut.
run bash "$ROOT/harness/run-visual.sh"

# 7. Répétition locale du déploiement sur hébergement infogéré (cible jetable + MariaDB) :
#    deployer.sh joué deux fois, puis les smokes pour chaque combinaison d'adaptateurs.
run bash "$ROOT/harness/repeter-deploiement.sh"

echo ""
echo "CI: 🟢 tous les gates bloquants sont verts."
