#!/bin/sh
# Démarre la cible : certificat autosigné (TLS comme en production, pour éprouver le cookie
# Secure et HSTS), sshd, PHP-FPM s'il y a lieu, puis Apache au premier plan.
set -e
if [ ! -s /etc/ssl/kit/cert.pem ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj '/CN=127.0.0.1' \
    -addext 'subjectAltName=IP:127.0.0.1,DNS:localhost' \
    -keyout /etc/ssl/kit/key.pem -out /etc/ssl/kit/cert.pem >/dev/null 2>&1
fi
/usr/sbin/sshd -o PasswordAuthentication=no -o AllowUsers=repet
# PHP-FPM seulement dans la variante fpm ; avec mod_fcgid, c'est Apache qui lance php-cgi.
if [ "$(cat /etc/kit-variante)" = fpm ]; then php-fpm --fpm-config /usr/local/etc/kit-fpm.conf; fi
# apache2ctl lit /etc/apache2/envvars (identité du compte) et crée le dossier d'exécution.
exec apache2ctl -D FOREGROUND
