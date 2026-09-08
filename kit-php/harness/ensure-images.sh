#!/usr/bin/env bash
# Construit les images du kit (bases publiques) si elles manquent. Sourcé par les gates.
# Idempotent : ne rebuild pas si l'image existe déjà.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

ensure_php_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-php:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-php:local (php:8.3-cli + pdo_mysql)…" >&2
  docker build -q -t todo-kit-php:local -f "$root/docker/php.Dockerfile" "$root/docker" >/dev/null
}

ensure_visual_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-visual:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-visual:local (node:22-bookworm + Chromium)…" >&2
  docker build -q -t todo-kit-visual:local "$root/harness/visual" >/dev/null
}

# MySQL éphémère de dev (image publique mysql:8.0), prêt à recevoir des connexions.
ensure_mysql() {
  docker ps --filter name=todo-mysql --format '{{.Names}}' | grep -qx todo-mysql || \
    docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
      -p 13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password >/dev/null
  local i
  for i in $(seq 1 60); do
    docker exec todo-mysql mysqladmin ping -uroot -proot --silent 2>/dev/null | grep -q alive && return 0
    sleep 1
  done
  echo "[kit] MySQL n'a pas démarré à temps" >&2; return 1
}

# node_modules du harnais visuel : installés côté hôte (le montage du repo masque ceux de l'image).
ensure_visual_modules() {
  local root; root="$(_kit_root)"
  [ -d "$root/harness/visual/node_modules/playwright" ] && return 0
  echo "[kit] npm install (harness/visual)…" >&2
  (cd "$root/harness/visual" && npm install >/dev/null 2>&1)
}
