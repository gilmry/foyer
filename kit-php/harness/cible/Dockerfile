# Cible jetable de la répétition de déploiement : ce qu'un hébergement PHP infogéré donne à voir.
# Debian 12, Apache qui sert le site (mod_rewrite, .htaccess limité à FileInfo), PHP SOUS L'IDENTITÉ
# DU COMPTE, OPcache actif, sshd, un compte sans privilège. Ni Composer, ni git, ni compilateur :
# rien ne peut s'y construire. Base PUBLIQUE (php:<version>-<variante>-bookworm).
#
# Deux montages de PHP, choisis à la construction (KIT_CIBLE dans harness/repeter-deploiement.sh) :
#   VARIANTE=cli  → Apache + mod_fcgid + php-cgi : le montage relevé chez l'hébergeur (mod_fcgid
#                   2.3.9, pas de PHP-FPM visible). C'est le défaut du gate.
#   VARIANTE=fpm  → Apache + mod_proxy_fcgi + PHP-FPM : l'autre montage courant, rejouable à la demande.
ARG PHP_VERSION=8.3
ARG VARIANTE=cli
FROM php:${PHP_VERSION}-${VARIANTE}-bookworm
ARG VARIANTE=cli
RUN apt-get update && apt-get install -y --no-install-recommends apache2 libapache2-mod-fcgid openssh-server openssl procps \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_mysql opcache >/dev/null \
    && a2enmod rewrite headers ssl >/dev/null && a2dissite 000-default >/dev/null \
    && if [ "$VARIANTE" = fpm ]; then a2dismod fcgid >/dev/null; a2enmod proxy proxy_fcgi >/dev/null; rm -f /usr/local/etc/php-fpm.d/*.conf; else a2enmod fcgid >/dev/null; fi \
    && sed -i 's/^Listen 80$/# Listen 80/' /etc/apache2/ports.conf \
    && mkdir -p /run/sshd /etc/ssl/kit \
    && useradd -m -s /bin/bash repet && mkdir -p /home/repet/.ssh && chmod 700 /home/repet /home/repet/.ssh \
    && chown -R repet:repet /home/repet \
    && sed -i 's/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=repet/; s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=repet/' /etc/apache2/envvars \
    && chown -R repet:repet /var/lib/apache2/fcgid 2>/dev/null || true
COPY site-${VARIANTE}.conf /etc/apache2/sites-enabled/kit.conf
COPY fpm.conf /usr/local/etc/kit-fpm.conf
COPY php.ini /usr/local/etc/php/conf.d/kit.ini
COPY php-cgi-kit /usr/local/bin/php-cgi-kit
COPY entree.sh /usr/local/bin/entree.sh
RUN chmod 755 /usr/local/bin/php-cgi-kit && echo "$VARIANTE" > /etc/kit-variante
CMD ["sh", "/usr/local/bin/entree.sh"]
