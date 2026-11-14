#!/usr/bin/env bash
# Construit l'image Rust (base publique) et lance PostgreSQL si absents. Sourcé par les gates.
# Volumes de cache cargo → compilations rapides après la première.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# Port hôte de PostgreSQL ; à déplacer si un autre projet occupe 15432 (KIT_PG_PORT=25432).
KIT_PG_PORT="${KIT_PG_PORT:-15432}"

CARGO_VOLS=(-v todo_actix_cargo:/usr/local/cargo/registry -v todo_actix_target:/app/target)
# Plafonds facultatifs pour une machine à court de mémoire (rien par défaut) :
# KIT_CARGO_JOBS=1 KIT_DOCKER_MEM=6g bash harness/ci.sh
[ -n "${KIT_CARGO_JOBS:-}" ] && CARGO_VOLS+=(-e "CARGO_BUILD_JOBS=$KIT_CARGO_JOBS")
[ -n "${KIT_DOCKER_MEM:-}" ] && CARGO_VOLS+=(--memory "$KIT_DOCKER_MEM")

# OpenBao du module de mesure (foyer#28), épinglé par empreinte (ADR-038 de Sluis).
# MODE DEV ET JETON RACINE : réservés au spike. La cible est un jeton court délivré à
# l'application (ADR-042 de Sluis, point 6). Ne jamais reprendre ce démarrage hors du harnais.
OPENBAO_IMAGE="openbao/openbao:2.4.4@sha256:595c83b42614a4d2b044608e4593c05b019c5db25bc9c185d8fff3ac96c03ddd"
OPENBAO_PORT=18200
OPENBAO_JETON_DEV="jeton-racine-du-mode-dev"

ensure_rust_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-rust:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-rust:local (rust:1-slim-bookworm)…" >&2
  docker build -q -t todo-kit-rust:local -f "$root/docker/rust.Dockerfile" "$root/docker" >/dev/null
}

ensure_postgres() {
  docker ps --filter name=todo-postgres --format '{{.Names}}' | grep -qx todo-postgres || \
    docker run -d --name todo-postgres -e POSTGRES_DB=todo -e POSTGRES_USER=todo \
      -e POSTGRES_PASSWORD=todo -p "$KIT_PG_PORT:5432" postgres:16 >/dev/null
  local i
  for i in $(seq 1 60); do
    docker exec todo-postgres pg_isready -U todo -d todo >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "[kit] PostgreSQL n'a pas démarré à temps" >&2; return 1
}

# OpenBao en mode dev (état en mémoire, perdu à l'arrêt), moteur transit et clé `kit-actix`.
ensure_openbao() {
  local base="http://127.0.0.1:$OPENBAO_PORT" i
  if ! docker ps --filter name=todo-openbao --format '{{.Names}}' | grep -qx todo-openbao; then
    docker run -d --rm --name todo-openbao --cap-add IPC_LOCK -p "$OPENBAO_PORT:8200" "$OPENBAO_IMAGE" \
      server -dev -dev-root-token-id="$OPENBAO_JETON_DEV" -dev-listen-address=0.0.0.0:8200 >/dev/null
  fi
  for i in $(seq 1 60); do
    curl -sf "$base/v1/sys/health" >/dev/null 2>&1 && break
    sleep 0.5
  done
  curl -sf "$base/v1/sys/health" >/dev/null 2>&1 || { echo "[kit] OpenBao n'a pas démarré à temps" >&2; return 1; }
  # Idempotent : 400 si transit est déjà monté.
  curl -s -o /dev/null -H "X-Vault-Token: $OPENBAO_JETON_DEV" -X POST "$base/v1/sys/mounts/transit" -d '{"type":"transit"}'
  curl -sf -o /dev/null -H "X-Vault-Token: $OPENBAO_JETON_DEV" -X POST "$base/v1/transit/keys/kit-actix"
}

# Table du module de mesure, schéma propre.
reset_schema_mesure() {
  local root; root="$(_kit_root)"
  { cat "$root/database/mesure/0001_create_personnes.down.sql"; cat "$root/database/mesure/0001_create_personnes.up.sql"; } \
    | docker exec -i todo-postgres psql -U todo -d todo -q -f - >/dev/null
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
