#!/usr/bin/env bash
# Démarre PostgreSQL + uvicorn (API + front statique) sur 127.0.0.1:8080, base vide puis migrée.
# Écrit l'ID du conteneur web sur stdout. Appelé par run-visual.sh et run-demo.sh.
#
# Mode DÉVELOPPEMENT (TODO_ENV=development) : ces deux harnais pilotent un navigateur en http, où
# un cookie `Secure` ne serait pas renvoyé. Le gate e2e, lui, tourne en mode production.
# Inscription ouverte : les harnais y créent leur compte, avec un mot de passe tiré à chaque fois.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image; ensure_postgres; reset_schema
kit_py python -m app.migrate up >&2

cid=$(docker run -d --rm --network host -v "$ROOT":/app:ro -w /app -e PYTHONPATH=/app "${DB_ENV[@]}" \
  -e TODO_ENV=development -e TODO_SECRET_KEY="$(kit_alea 32)" -e TODO_REGISTRATION=open \
  -e TODO_PERSISTENCE="${TODO_PERSISTENCE:-cqrs}" -e TODO_HTTP="${TODO_HTTP:-fastapi}" \
  todo-kit-fastapi:local uvicorn app.http.app:app --host 127.0.0.1 --port 8080 --log-level warning)
for i in $(seq 1 40); do curl -sf http://127.0.0.1:8080/api/health >/dev/null 2>&1 && break; sleep 0.5; done
echo "$cid"
