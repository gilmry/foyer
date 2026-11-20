#!/usr/bin/env bash
# Construit l'image Python (base publique) et lance PostgreSQL si absents. Sourcé par les gates.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# Port hôte de PostgreSQL ; à déplacer si un autre projet occupe 15432 (KIT_PG_PORT=25432).
KIT_PG_PORT="${KIT_PG_PORT:-15432}"

# L'image porte l'empreinte du verrou : elle est reconstruite dès que les dépendances changent.
ensure_py_image() {
  local root verrou; root="$(_kit_root)"
  verrou="$(sha256sum "$root/requirements-dev.lock" | cut -c1-16)"
  [ "$(docker image inspect -f '{{ index .Config.Labels "kit.verrou" }}' todo-kit-fastapi:local 2>/dev/null)" = "$verrou" ] && return 0
  echo "[kit] build todo-kit-fastapi:local (python:3.12-slim-bookworm + dépendances verrouillées)…" >&2
  docker build -q --build-arg VERROU="$verrou" -t todo-kit-fastapi:local -f "$root/docker/py.Dockerfile" "$root" >/dev/null
}

# Port publié sur 127.0.0.1 seulement : le mot de passe de dev ne sort pas de la machine.
# Conteneur PARTAGÉ avec les autres kits de la famille : on ne le recrée ni ne le supprime.
ensure_postgres() {
  docker ps --filter name=todo-postgres --format '{{.Names}}' | grep -qx todo-postgres || \
    docker run -d --name todo-postgres -e POSTGRES_DB=todo -e POSTGRES_USER=todo \
      -e POSTGRES_PASSWORD=todo -p "127.0.0.1:$KIT_PG_PORT:5432" postgres:16 >/dev/null
  local i
  for i in $(seq 1 60); do
    docker exec todo-postgres pg_isready -U todo -d todo >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "[kit] PostgreSQL n'a pas démarré à temps" >&2; return 1
}

# Login applicatif SANS PRIVILÈGE, celui d'un PostgreSQL géré par un hébergeur : propriétaire de sa
# base, ni superutilisateur, ni BYPASSRLS, ni créateur de rôles ou de bases. TOUS les gates s'y
# connectent ; le superutilisateur `todo` de l'image ne sert qu'à poser ce login et sa base.
# Le conteneur est partagé avec les autres kits : chacun a son rôle et sa base, à son nom.
KIT_DB=kit_fastapi_app
DB_ENV=(-e DB_HOST=127.0.0.1 -e DB_PORT="$KIT_PG_PORT" -e DB_NAME="$KIT_DB" -e DB_USER="$KIT_DB" -e DB_PASSWORD="$KIT_DB")
_psql_admin() { docker exec -i todo-postgres psql -U todo -d todo -q -v ON_ERROR_STOP=1 "$@" >/dev/null; }
# Requête jouée par le login applicatif lui-même (lecture des tables pour les vérifications).
kit_sql() { docker exec todo-postgres psql -U "$KIT_DB" -d "$KIT_DB" -tAc "$1"; }

# Le login et sa base, créés s'ils manquent (idempotent).
ensure_app_db() {
  _psql_admin <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$KIT_DB') THEN
    CREATE ROLE $KIT_DB LOGIN PASSWORD '$KIT_DB' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
  END IF;
END \$\$;
SELECT 'CREATE DATABASE $KIT_DB OWNER $KIT_DB' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$KIT_DB')\gexec
SQL
}

# Base VIDE appartenant au login applicatif (seule la base de CE kit est recréée). Le schéma y est
# posé par l'outil de migration (`python -m app.migrate up`), jamais par un psql du harnais.
reset_schema() {
  ensure_app_db
  _psql_admin <<SQL
DROP DATABASE IF EXISTS $KIT_DB WITH (FORCE);
CREATE DATABASE $KIT_DB OWNER $KIT_DB;
SQL
}

# Valeur imprévisible, tirée à chaque exécution : aucun mot de passe ni clé en dur dans le harnais.
kit_alea() { head -c "${1:-24}" /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# Exécute une commande Python du kit dans l'image, connectée à la base par le login sans privilège.
kit_py() {
  local root; root="$(_kit_root)"
  docker run --rm -i --network host -v "$root":/app -w /app -e PYTHONPATH=/app "${DB_ENV[@]}" \
    todo-kit-fastapi:local "$@"
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
