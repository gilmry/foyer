# Image PHP du kit — base PUBLIQUE (php:8.3-cli) + pdo_mysql.
# Autonome : aucune image privée. `docker/build.sh` la construit sous le tag todo-kit-php:local.
FROM php:8.3-cli
RUN docker-php-ext-install pdo_mysql >/dev/null
