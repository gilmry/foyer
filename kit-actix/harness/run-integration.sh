#!/usr/bin/env bash
# Gate `integration` — sqlx CQRS et sea-orm contre PostgreSQL réel, via Docker, avec le LOGIN SANS
# PRIVILÈGE de la cible (le gate échoue si le login est superutilisateur ou dispensé de RLS).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres; ensure_app_db
exec docker run --rm --network host -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
  "${DB_ENV[@]}" \
  todo-kit-rust:local cargo run --quiet --bin integration
