#!/usr/bin/env bash
# Démarre PostgreSQL + le serveur actix (API + front statique) sur :8080, base vide puis migrations
# jouées par le serveur à son démarrage (TODO_MIGRER=1).
# Écrit l'ID du conteneur web sur stdout. Utilisé par run-visual.sh et run-demo.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres

docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" todo-kit-rust:local cargo build --quiet --bin server >&2
reset_schema

cid=$(docker run -d --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
  "${DB_ENV[@]}" \
  -e HTTP_HOST=127.0.0.1 -e HTTP_PORT=8080 -e TODO_MIGRER=1 -e TODO_PERSISTENCE="${TODO_PERSISTENCE:-cqrs}" \
  todo-kit-rust:local ./target/debug/server)
for i in $(seq 1 40); do curl -sf http://127.0.0.1:8080/api/todos >/dev/null 2>&1 && break; sleep 0.5; done
echo "$cid"
