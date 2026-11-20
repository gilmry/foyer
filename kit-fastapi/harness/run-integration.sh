#!/usr/bin/env bash
# Gate `integration` — PostgreSQL réel, les DEUX adaptateurs (CQRS + ORM), connecté par le login
# SANS PRIVILÈGE (celui d'une base gérée). Base vide au départ : le schéma vient de `app.migrate`.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image; ensure_postgres; reset_schema
kit_py python harness/integration.py
