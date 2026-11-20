#!/bin/sh
# Lanceur du kit pour un site de type « programme utilisateur » d'un hébergeur infogéré.
# Commande du site : /home/<compte>/<instance>/lancer.sh — répertoire de travail : ce dossier.
#
# La plateforme fournit l'adresse et le port d'écoute (IP ou HOST, PORT ; l'adresse peut être en
# IPv6). Les réglages et le mot de passe de la base sont dans `.env`, à côté (droits 600, créé sur
# le serveur par deployer.sh, jamais versionné). `exec` : le lanceur est remplacé par le serveur,
# le signal d'arrêt de la plateforme l'atteint donc directement.
set -eu
cd "$(dirname "$0")"
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  echo "lancer.sh : fichier .env absent de $(pwd) (deployer.sh le crée au premier passage)" >&2
fi
export HTTP_HOST="${IP:-${HOST:-127.0.0.1}}" HTTP_PORT="${PORT:-8080}"
# Migrations : jouées au seul démarrage qui suit un déploiement (deployer.sh pose le témoin
# `.migrer`), par une commande courte, puis le témoin est effacé. Si elles échouent, le témoin
# reste et le site ne démarre pas : l'échec se voit, il ne se rattrape pas en silence.
if [ -f .migrer ]; then
  ./migrate up
  rm -f .migrer
fi
exec ./server
