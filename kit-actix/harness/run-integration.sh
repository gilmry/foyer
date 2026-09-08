#!/usr/bin/env bash
# Gate `integration` — sqlx CQRS contre PostgreSQL réel, via Docker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres
exec docker run --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
  -e DB_HOST=127.0.0.1 -e DB_PORT=15432 -e DB_NAME=todo -e DB_USER=todo -e DB_PASSWORD=todo \
  todo-kit-rust:local cargo run --quiet --bin integration
