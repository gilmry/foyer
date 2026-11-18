#!/bin/sh
# Essaie le pont ASGI→WSGI sous uWSGI, DANS la cible jetable (appelé par repeter-deploiement.sh).
# Usage : essayer.sh <dossier des dépendances> <port>
# Une ligne par variante : « <nom> <JSON des résultats> ». Le guide cite ces résultats.
set -eu
DEPS="$1"; PORT="$2"
ICI="$(cd "$(dirname "$0")" && pwd)"
UWSGI="${KIT_UWSGI:-/usr/alwaysdata/uwsgi/bin/uwsgi}"
PY="${KIT_PYTHON:-/usr/alwaysdata/python/3.12/bin/python}"

variante() {  # $1 nom, $2 direct|paresseux, reste : options de uWSGI
  nom="$1"; pont="$2"; shift 2
  SONDE_DEPS="$DEPS" SONDE_PONT="$pont" "$UWSGI" --http-socket "[::1]:$PORT" --wsgi-file "$ICI/sonde_wsgi.py" \
    --master --die-on-term --disable-logging "$@" >"/tmp/sonde-$nom.log" 2>&1 &
  pid=$!
  i=0
  while [ $i -lt 50 ] && ! "$PY" -c "import socket,sys; socket.create_connection(('::1',$PORT),0.2)" 2>/dev/null; do i=$((i+1)); sleep 0.2; done
  printf '%s %s\n' "$nom" "$("$PY" "$ICI/sonder.py" ::1 "$PORT")"
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

# Le pont du kit (créé dans le processus qui sert), avec les fils de uWSGI activés.
variante kit-threads        paresseux --processes 2 --threads 4
variante kit-enable-threads paresseux --processes 2 --enable-threads
variante kit-un-processus   paresseux --processes 1 --threads 4
# Sans fils activés : ce que donne une configuration de uWSGI laissée par défaut.
variante kit-sans-fils      paresseux --processes 2
# Le pont naïf, créé à l'import dans le processus maître, puis dédoublé.
variante naif-threads       direct    --processes 2 --threads 4
variante naif-lazy-apps     direct    --processes 2 --threads 4 --lazy-apps
