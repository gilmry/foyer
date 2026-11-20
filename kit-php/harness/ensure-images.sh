#!/usr/bin/env bash
# Construit les images du kit (bases publiques) si elles manquent, prépare la base du harnais et
# fournit les fonctions communes aux gates. Sourcé par les gates. Idempotent.
_kit_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# Version mineure de PHP de l'image du kit. Elle doit être celle du site chez l'hébergeur.
KIT_PHP_VERSION="${KIT_PHP_VERSION:-8.3}"
KIT_APP_DB_USER=kit_php_app

ensure_php_image() {
  local root; root="$(_kit_root)"
  local voulu; voulu="$(docker image inspect -f '{{index .Config.Labels "kit.php"}}' todo-kit-php:local 2>/dev/null || true)"
  [ "$voulu" = "$KIT_PHP_VERSION" ] && return 0
  echo "[kit] build todo-kit-php:local (php:$KIT_PHP_VERSION-cli + pdo_mysql)…" >&2
  docker build -q -t todo-kit-php:local --build-arg PHP_VERSION="$KIT_PHP_VERSION" --label kit.php="$KIT_PHP_VERSION" \
    -f "$root/docker/php.Dockerfile" "$root/docker" >/dev/null
}

ensure_visual_image() {
  local root; root="$(_kit_root)"
  docker image inspect todo-kit-visual:local >/dev/null 2>&1 && return 0
  echo "[kit] build todo-kit-visual:local (node:22-bookworm + Chromium)…" >&2
  docker build -q -t todo-kit-visual:local "$root/harness/visual" >/dev/null
}

# Fichier d'environnement du harnais (droits 600, hors dépôt) : identifiants de la base locale et
# secret du noyau, TIRÉS AU HASARD au premier passage. Rien n'est en dur, rien ne passe en argument.
kit_env_file() {
  local root; root="$(_kit_root)"
  local f="$root/var/harness/kit.env"
  if [ ! -s "$f" ]; then
    mkdir -p "$root/var/harness"
    ( umask 077
      printf 'DB_HOST=127.0.0.1\nDB_PORT=13306\nDB_NAME=todo\nDB_USER=%s\nDB_PASSWORD=%s\nKIT_SECRET=%s\n' \
        "$KIT_APP_DB_USER" "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > "$f" )
  fi
  printf '%s' "$f"
}

# MySQL éphémère de dev (image publique mysql:8.0), en écoute sur 127.0.0.1 seulement, avec un
# utilisateur applicatif SANS PRIVILÈGE : `kit_php_app` n'a de droits que sur la base `todo`
# (ni root, ni SUPER, ni GRANT OPTION), comme le login d'un hébergeur infogéré. Tous les gates
# s'y connectent ; le compte root du conteneur ne sert qu'ici, à créer cet utilisateur.
ensure_mysql() {
  docker ps --filter name='^todo-mysql$' --format '{{.Names}}' | grep -qx todo-mysql || {
    docker rm -f todo-mysql >/dev/null 2>&1 || true
    docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
      -p 127.0.0.1:13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password >/dev/null
  }
  local i pret=0
  for i in $(seq 1 90); do
    docker exec todo-mysql mysql -uroot -proot -e 'SELECT 1' >/dev/null 2>&1 && { pret=1; break; }
    sleep 1
  done
  [ "$pret" = 1 ] || { echo "[kit] MySQL n'a pas démarré à temps" >&2; return 1; }
  local env; env="$(kit_env_file)"
  # Le mot de passe passe par l'entrée standard du client, jamais par un argument.
  ( pw="$(sed -n 's/^DB_PASSWORD=//p' "$env")"
    printf "CREATE DATABASE IF NOT EXISTS todo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\nCREATE USER IF NOT EXISTS '%s'@'%%' IDENTIFIED BY '%s';\nALTER USER '%s'@'%%' IDENTIFIED BY '%s';\nGRANT ALL PRIVILEGES ON todo.* TO '%s'@'%%';\nFLUSH PRIVILEGES;\n" \
      "$KIT_APP_DB_USER" "$pw" "$KIT_APP_DB_USER" "$pw" "$KIT_APP_DB_USER" ) \
    | docker exec -i todo-mysql mysql -uroot -proot >/dev/null 2>&1
}

# vendor/ Composer (API Platform, Symfony, Doctrine) : installé dans le dépôt monté, d'après
# composer.lock (versionné : mêmes dépendances partout). Fait sous l'identité de l'utilisateur.
ensure_vendor() {
  local root; root="$(_kit_root)"
  [ -f "$root/vendor/autoload.php" ] && [ "$root/vendor/autoload.php" -nt "$root/composer.lock" ] && return 0
  echo "[kit] composer install (API Platform, Symfony, Doctrine)…" >&2
  mkdir -p "$root/var/composer-cache"
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e COMPOSER_CACHE_DIR=/app/var/composer-cache \
    -v "$root":/app -w /app todo-kit-php:local \
    composer install --no-interaction --no-progress >/dev/null 2>&1 && touch "$root/vendor/autoload.php"
}

# node_modules du harnais visuel : installés côté hôte (le montage du repo masque ceux de l'image).
ensure_visual_modules() {
  local root; root="$(_kit_root)"
  [ -d "$root/harness/visual/node_modules/playwright" ] && return 0
  echo "[kit] npm install (harness/visual)…" >&2
  (cd "$root/harness/visual" && npm install >/dev/null 2>&1)
}

# Lance une commande PHP du kit dans son image, connectée à la base du harnais par le login
# applicatif sans privilège. Variables supplémentaires : KIT_RUN_ENV="-e NOM=valeur …".
kit_php() {
  local root; root="$(_kit_root)"
  # shellcheck disable=SC2086
  docker run --rm -i --network host -u "$(id -u):$(id -g)" -e HOME=/tmp -e TZ=UTC \
    --env-file "$(kit_env_file)" ${KIT_RUN_ENV:-} -v "$root":/app -w /app todo-kit-php:local "$@"
}

# Base vide puis migrations par l'outil du kit (bin/migrate.php via harness/reset-db.php).
kit_reset_db() { kit_php php harness/reset-db.php; }

# Sert le kit sur 127.0.0.1:8080 par le serveur intégré de PHP (conteneur `todo-web`), avec
# l'adaptateur HTTP et la persistance demandés, à QUATRE processus (comme un vrai serveur : les
# gates éprouvent des requêtes simultanées). Le cache du noyau est vidé : en mode production
# il n'est jamais recalculé tout seul.
#   kit_serve <apiplatform|vanilla> <cqrs|doctrine> [-e NOM=valeur …]
kit_serve() {
  local root; root="$(_kit_root)"
  local http="$1" persistence="$2"; shift 2
  docker rm -f todo-web >/dev/null 2>&1 || true
  rm -rf "$root/var/cache" "$root/var/pools" "$root/var/sessions" "$root/var/log" "$root/var/doctrine"
  docker run -d --name todo-web --network host -u "$(id -u):$(id -g)" -e HOME=/tmp -e TZ=UTC \
    --env-file "$(kit_env_file)" -e TODO_HTTP="$http" -e TODO_PERSISTENCE="$persistence" \
    -e KIT_REGISTRATION=open -e KIT_LOG_LEVEL=debug -e PHP_CLI_SERVER_WORKERS=4 "$@" \
    -v "$root":/app -w /app todo-kit-php:local \
    php -S 127.0.0.1:8080 -t public harness/dev-router.php >/dev/null
  # On attend le document, pas la sonde de santé : un gate peut vouloir une base injoignable.
  local i
  for i in $(seq 1 60); do
    curl -sf --max-time 5 http://127.0.0.1:8080/ >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  echo "[kit] le serveur ne répond pas sur 127.0.0.1:8080 — journal :" >&2
  docker logs todo-web 2>&1 | tail -20 >&2
  return 1
}
kit_stop() { docker rm -f todo-web >/dev/null 2>&1 || true; }
