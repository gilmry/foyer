#!/usr/bin/env bash
# Gate `integration` — MySQL réel, LOGIN SANS PRIVILÈGE (kit_php_app), via Docker.
# Rejoue le parcours et le cloisonnement par propriétaire sur les DEUX adaptateurs de persistance,
# et éprouve l'outil de migration. Le gate échoue si le login a des privilèges globaux.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_vendor; ensure_mysql
kit_php php harness/integration-todos.php
