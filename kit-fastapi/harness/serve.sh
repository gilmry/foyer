#!/usr/bin/env bash
# Démarre PostgreSQL + uvicorn (API + front statique) sur :8080, table fraîche. Écrit l'ID du
# conteneur web sur stdout. Sourcé/appelé par run-visual.sh et run-demo.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_py_image; ensure_postgres
ENVV=(-e DB_HOST=127.0.0.1 -e DB_PORT=15432 -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo -e PYTHONPATH=/app)

docker run --rm --network host -v "$ROOT":/app -w /app "${ENVV[@]}" todo-kit-fastapi:local python -c '
import psycopg, pathlib
from app.config import dsn
sql = pathlib.Path("database/migrations/pending/0001_create_todos.up.sql").read_text()
with psycopg.connect(dsn()) as c, c.cursor() as cur:
    cur.execute("DROP TABLE IF EXISTS todos"); cur.execute(sql); c.commit()
' >&2

cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app "${ENVV[@]}" \
  todo-kit-fastapi:local uvicorn app.http.api:app --host 127.0.0.1 --port 8080 --log-level warning)
for i in $(seq 1 40); do curl -sf http://127.0.0.1:8080/api/todos >/dev/null 2>&1 && break; sleep 0.5; done
echo "$cid"
