#!/usr/bin/env bash
# CI local — rejoue tous les gates (mêmes commandes qu'en CI, DRY). Images sur bases publiques,
# construites à froid par ensure-images.sh. « Clone → bash docker/build.sh → bash harness/ci.sh ».
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run() { echo ""; echo "▶ $*"; "$@"; }

run bash "$ROOT/harness/run-verify.sh"      # plancher + structurel + contrat OpenAPI==app (G1/G2/H1/C1)
run bash "$ROOT/harness/run-contract.sh"    # client TYPÉ api.ts à jour vs OpenAPI (anti-drift)
run bash "$ROOT/harness/run-pytest.sh"      # domaine + application (sans DB)
run bash "$ROOT/harness/run-integration.sh" # PostgreSQL réel — CQRS **et** ORM
run bash "$ROOT/harness/e2e-smoke.sh"                    # adaptateur HTTP FastAPI (défaut)
run env TODO_HTTP=starlette bash "$ROOT/harness/e2e-smoke.sh"  # adaptateur HTTP Starlette (même contrat)
run bash "$ROOT/harness/run-visual.sh"      # régression d'apparence (goldens Chromium)

echo ""
echo "CI: 🟢 tous les gates bloquants sont verts."
