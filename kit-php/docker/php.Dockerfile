# Image PHP du kit — base PUBLIQUE (php:8.3-cli) + pdo_mysql + Composer.
# Autonome : aucune image privée. `docker/build.sh` la construit sous le tag todo-kit-php:local.
# Composer sert à installer Doctrine (option de persistance ORM) et, plus tard, API Platform.
# unzip + git : requis par Composer pour extraire les paquets dist.
FROM php:8.3-cli
RUN apt-get update -y && apt-get install -y --no-install-recommends unzip git \
    && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install pdo_mysql >/dev/null
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
