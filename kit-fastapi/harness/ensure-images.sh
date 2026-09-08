#!/usr/bin/env bash
# Construit l'image Python (base publique) et lance PostgreSQL si absents. Sourcé par les gates.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

ensure_py_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-fastapi:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-fastapi:local (python:3.12-slim + deps)…" >&2
  docker build -q -t todo-kit-fastapi:local -f "$root/docker/py.Dockerfile" "$root" >/dev/null
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

ensure_visual_modules() {
  local root; root="$(_kit_root)"
  [ -d "$root/harness/visual/node_modules/playwright" ] && return 0
  echo "[kit] npm install (harness/visual)…" >&2
  (cd "$root/harness/visual" && npm install >/dev/null 2>&1)
}

ensure_visual_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-visual:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-visual:local (node:22-bookworm + Chromium)…" >&2
  docker build -q -t todo-kit-visual:local "$root/harness/visual" >/dev/null
}
