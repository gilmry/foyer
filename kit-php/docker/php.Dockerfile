# Image PHP du kit — base PUBLIQUE (php:<version>-cli) + pdo_mysql + Composer.
# Autonome : aucune image privée. `docker/build.sh` la construit sous le tag todo-kit-php:local.
# PHP_VERSION = version mineure de PHP. Elle doit être celle du site chez l'hébergeur : c'est dans
# cette image que `deploiement/alwaysdata/deployer.sh` construit vendor/ (jamais sur le serveur).
# unzip + git : requis par Composer pour extraire les paquets dist.
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-cli
RUN apt-get update -y && apt-get install -y --no-install-recommends unzip git \
    && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install pdo_mysql >/dev/null
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
