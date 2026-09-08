#!/usr/bin/env bash
# Gate `verify` / `plancher` — invariants structurels (exit 0 = 🟢, ≠0 = 🔴). Pur (grep/fichiers).
#   G1 secrets hors code · G2 migrations réversibles + SQL portable · H1 pureté hexagonale
#   (domaine/application sans infra) · C1 contrat OpenAPI présent.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
add() { echo "  ✗ $1"; fail=1; }

# G1 — pas de mot de passe en dur dans le code.
if grep -rniE 'password[[:space:]]*[:=][[:space:]]*"[^"]{3,}"' "$ROOT/src" 2>/dev/null | grep -qv 'DB_PASSWORD'; then
  add "G1: secret potentiel en dur dans src/"
fi

# G2 — chaque *.up.sql a son *.down.sql ; SQL portable.
for up in "$ROOT"/database/migrations/pending/*.up.sql; do
  down="${up/.up.sql/.down.sql}"
  [ -f "$down" ] || add "G2: migration sans réversion : $(basename "$up")"
  if sed 's/--.*//' "$up" | grep -qiE '\bNOW\(\)|\bSERIAL\b|\bAUTO_INCREMENT\b'; then
    add "G2: SQL non portable (NOW()/SERIAL/AUTO_INCREMENT) dans $(basename "$up")"
  fi
done

# H1 — domaine + application ne dépendent d'aucune infra. On cible les VRAIS usages de crate
# (`use X` ou `X::`), commentaires retirés — pas les noms de méthode (ex. le port `uuid()`).
CRATES='actix_web|actix_files|actix|sqlx|sea_orm|serde_json|serde|chrono|uuid|tokio'
if find "$ROOT/src/domain" "$ROOT/src/application" -name '*.rs' -print0 2>/dev/null \
     | xargs -0 sed 's://.*::' 2>/dev/null \
     | grep -qE "(use[[:space:]]+($CRATES))|(($CRATES)::)"; then
  add "H1: dépendance infrastructure dans une couche pure (domain/application)"
fi

# C1 — contrat OpenAPI présent (le drift d'api.ts est vérifié par le gate `contrat`).
[ -f "$ROOT/openapi/todos.openapi.json" ] || add "C1: openapi/todos.openapi.json absent"

if [ "$fail" = 0 ]; then echo "verify: 🟢 tous les invariants sont verts."; else echo "verify: 🔴"; fi
exit "$fail"
