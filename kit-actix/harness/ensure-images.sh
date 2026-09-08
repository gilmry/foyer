#!/usr/bin/env bash
# Construit l'image Rust (base publique) et lance PostgreSQL si absents. Sourcé par les gates.
# Volumes de cache cargo → compilations rapides après la première.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

CARGO_VOLS=(-v todo_actix_cargo:/usr/local/cargo/registry -v todo_actix_target:/app/target)

ensure_rust_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-rust:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-rust:local (rust:1-slim-bookworm)…" >&2
  docker build -q -t todo-kit-rust:local -f "$root/docker/rust.Dockerfile" "$root/docker" >/dev/null
}

ensure_postgres() {
  docker ps --filter name=todo-postgres --format '{{.Names}}' | grep -qx todo-postgres || \
    docker run -d --name todo-postgres -e POSTGRES_DB=todo -e POSTGRES_USER=todo \
      -e POSTGRES_PASSWORD=todo -p 15432:5432 postgres:16 >/dev/null
  local i
  for i in $(seq 1 60); do
    docker exec todo-postgres pg_isready -U todo -d todo >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "[kit] PostgreSQL n'a pas démarré à temps" >&2; return 1
}

# Applique la migration up (schéma propre) via psql du conteneur postgres.
reset_schema() {
  local root; root="$(_kit_root)"
  { echo 'DROP TABLE IF EXISTS todos;'; cat "$root/database/migrations/pending/0001_create_todos.up.sql"; } \
    | docker exec -i todo-postgres psql -U todo -d todo -q -f - >/dev/null
}

ensure_visual_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-visual:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-visual:local (node:22-bookworm + Chromium)…" >&2
  docker build -q -t todo-kit-visual:local "$root/harness/visual" >/dev/null
}

ensure_visual_modules() {
  local root; root="$(_kit_root)"
  [ -d "$root/harness/visual/node_modules/playwright" ] && return 0
  echo "[kit] npm install (harness/visual)…" >&2
  (cd "$root/harness/visual" && npm install >/dev/null 2>&1)
}
