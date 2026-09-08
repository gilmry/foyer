#!/usr/bin/env bash
# Gate `e2e` (smoke HTTP) — parcours de référence via uvicorn réel + PostgreSQL, sans navigateur.
# TODO_PERSISTENCE (cqrs|orm) est transparent pour ce test : l'adaptateur HTTP est le même.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image; ensure_postgres
BASE="http://127.0.0.1:8080"
PERSISTENCE="${TODO_PERSISTENCE:-cqrs}"

# Table (migration up).
docker run --rm --network host -v "$ROOT":/app -w /app -e PYTHONPATH=/app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=15432 -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo \
  todo-kit-fastapi:local python -c '
import psycopg, pathlib
from app.config import dsn
sql = pathlib.Path("database/migrations/pending/0001_create_todos.up.sql").read_text()
with psycopg.connect(dsn()) as c, c.cursor() as cur:
    cur.execute("DROP TABLE IF EXISTS todos"); cur.execute(sql); c.commit()
'

cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app -e PYTHONPATH=/app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=15432 -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo \
  -e TODO_PERSISTENCE="$PERSISTENCE" \
  todo-kit-fastapi:local uvicorn app.http.api:app --host 127.0.0.1 --port 8080 --log-level warning)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT

for i in $(seq 1 40); do curl -sf "$BASE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done

fail=0
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
assert() { if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; else echo "  ✗ $1 : attendu $2, obtenu $3"; fail=1; fi; }

created=$(curl -s -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"acheter du pain"}')
id=$(printf '%s' "$created" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
assert "POST /api/todos → 201" 201 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"seconde"}')"
assert "POST libellé vide → 400" 400 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"  "}')"
assert "POST champ inconnu → 422 (désérialisation stricte)" 422 "$(code -X POST "$BASE/api/todos" -H 'Content-Type: application/json' -d '{"title":"x","foo":1}')"
assert "GET /api/todos → 200" 200 "$(code "$BASE/api/todos")"
assert "PATCH /api/todos/{id} → 200" 200 "$(code -X PATCH "$BASE/api/todos/$id")"
assert "PATCH id inconnu → 404" 404 "$(code -X PATCH "$BASE/api/todos/inconnu")"
assert "DELETE /api/todos/{id} → 200" 200 "$(code -X DELETE "$BASE/api/todos/$id")"
assert "DELETE id inconnu → 404" 404 "$(code -X DELETE "$BASE/api/todos/inconnu")"

echo ""
if [ "$fail" = 0 ]; then echo "e2e (smoke HTTP, persistance=$PERSISTENCE): 🟢"; else echo "e2e: 🔴"; fi
exit "$fail"
