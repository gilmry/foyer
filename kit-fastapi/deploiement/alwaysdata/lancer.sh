#!/bin/sh
# Lanceur du kit pour un site de type « programme utilisateur » d'un hébergeur infogéré — montage A.
# Commande du site : /home/<compte>/<instance>/lancer.sh — répertoire de travail : ce dossier.
#
# La plateforme fournit l'adresse et le port d'écoute (IP ou HOST, PORT ; l'adresse peut être en
# IPv6). Les réglages et les secrets sont dans `.env`, à côté (droits 600, créé sur le serveur par
# deployer.sh, jamais versionné). `exec` : le lanceur est remplacé par uvicorn, le signal d'arrêt
# de la plateforme l'atteint donc directement.
#
# Ce fichier vit DANS sa version (`versions/<id>/lancer.sh`) ; le site y accède par le lien
# `lancer.sh -> courant/lancer.sh`. La bascule du lien `courant` change donc d'un seul coup le
# lanceur, le code et les dépendances (préparées sur le poste, jamais installées ici) : un réveil
# du site pendant un déploiement lance soit l'ancienne version entière, soit la nouvelle.
# Python : celui que l'hébergeur fournit en 3.12 — celui du shell peut être une autre version, pour
# laquelle les dépendances compilées ne valent pas. Autre chemin : KIT_PYTHON dans `.env`.
#
# Outils, par une commande courte en session SSH, avec les mêmes réglages que le site :
#   ./lancer.sh outil app.migrate status
#   ./lancer.sh outil app.accounts create <courriel>      (mot de passe sur l'entrée standard)
set -eu
cd "$(dirname "$0")"
[ -f .env ] || { echo "lancer.sh : fichier .env absent de $(pwd) (deployer.sh le crée au premier passage)" >&2; exit 78; }
droits="$(stat -c %a .env 2>/dev/null || echo inconnus)"
[ "$droits" = 600 ] || { echo "lancer.sh : .env doit être à droits 600, il porte des secrets (trouvé : $droits)" >&2; exit 78; }
set -a
. ./.env
set +a
PY="${KIT_PYTHON:-/usr/alwaysdata/python/3.12/bin/python}"
[ -x "$PY" ] || { echo "lancer.sh : Python 3.12 introuvable ($PY) ; régler KIT_PYTHON dans .env" >&2; exit 78; }
# La version à laquelle CE lanceur appartient (le lien est résolu une fois, ici).
V="$(dirname "$(readlink -f "$0")")"
[ -d "$V/app" ] || { echo "lancer.sh : pas de code à côté du lanceur ($V) ; il se lance par le lien posé par deployer.sh" >&2; exit 78; }
export PYTHONPATH="$V:$V/deps" PYTHONUNBUFFERED=1

if [ "${1:-}" = outil ]; then
  shift
  exec "$PY" -m "$@"
fi

# Adresse et port de la plateforme. Une adresse IPv6 peut arriver entre crochets : uvicorn l'attend nue.
HOTE="$(printf '%s' "${IP:-${HOST:-127.0.0.1}}" | tr -d '[]')"
PORT_ECOUTE="${PORT:-8080}"

# Migrations : jouées au seul démarrage qui suit un déploiement (deployer.sh pose le témoin
# `.migrer`, qui porte l'identifiant de la version à migrer), par une commande courte, puis le
# témoin est effacé. Un témoin adressé à une AUTRE version est laissé en place : l'ancienne version,
# réveillée pendant un déploiement, ne le consomme pas. Si les migrations échouent, le témoin
# reste et le site ne démarre pas : l'échec se voit, il ne se rattrape pas en silence.
if [ -f .migrer ] && [ "$(cat .migrer 2>/dev/null)" = "$(basename "$V")" ]; then
  "$PY" -m app.migrate up
  rm -f .migrer
fi
exec "$PY" -m uvicorn app.http.app:app --host "$HOTE" --port "$PORT_ECOUTE" --no-server-header --log-level info
