#!/usr/bin/env bash
# Retour arrière : remet en service la version précédente d'une instance (celle que deployer.sh a
# gardée à côté), puis redémarre le site. La version quittée prend la place de la précédente :
# rejouer ce script annule le retour.
#
# Ce script ne touche PAS au schéma de la base : aucune migration n'est jouée ni défaite. Revenir
# sur une release qui portait une migration de schéma demande donc une décision humaine (l'ancien
# code doit tenir sur le nouveau schéma, ou la base être restaurée depuis sa sauvegarde).
#
# Usage : bash deploiement/alwaysdata/revenir.sh <hôte ssh> <compte> <instance> <adresse publique>
#   Mêmes variables que deployer.sh (ALWAYSDATA_SITE, ALWAYSDATA_API, KIT_SSH, KIT_DOSSIER,
#   KIT_REDEMARRAGE). Le site est retrouvé par son adresse, avec le jeton d'API du fichier .env.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,12p' "$0"; exit 2; }
HOTE="$1"; COMPTE="$2"; INSTANCE="$3"; ADRESSE="${4%/}"
case "$HOTE" in -*|*[!A-Za-z0-9@._-]*) echo "hôte ssh invalide : $HOTE"; exit 2 ;; esac
case "$COMPTE$INSTANCE" in *[!A-Za-z0-9_-]*) echo "compte ou instance invalide (lettres, chiffres, - et _ seulement)"; exit 2 ;; esac
case "$ADRESSE" in http://*|https://*) ;; *) echo "adresse publique invalide : $ADRESSE"; exit 2 ;; esac
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
case "$DOSSIER" in /*) ;; *) echo "dossier invalide : $DOSSIER"; exit 2 ;; esac
case "$DOSSIER" in *[!A-Za-z0-9/._-]*) echo "dossier invalide : $DOSSIER"; exit 2 ;; esac
read -r -a SSH <<<"${KIT_SSH:-ssh -o BatchMode=yes}"
source "$ICI/hebergeur.sh"

echo "1/2 Échange de la version en service et de la précédente dans $HOTE:$DOSSIER"
"${SSH[@]}" -- "$HOTE" DOSSIER="$DOSSIER" sh -s <<'DISTANT'
set -eu
umask 077
cd "$DOSSIER"
for f in server migrate lancer.sh public; do
  [ -e "$f.precedent" ] || { echo "aucune version précédente dans $DOSSIER ($f.precedent absent) : rien n'est changé"; exit 1; }
done
for f in server migrate lancer.sh public; do
  rm -rf "$f.echange"
  mv "$f" "$f.echange"
  mv "$f.precedent" "$f"
  mv "$f.echange" "$f.precedent"
done
# Aucune migration au démarrage qui suit : le schéma reste celui de la version quittée.
rm -f .migrer
echo "  version précédente remise en place ; la version quittée est gardée à sa place"
DISTANT

echo "2/2 Redémarrage du site"
hebergeur_site
if hebergeur_redemarrer; then
  hebergeur_attendre "$ADRESSE/api/todos" \
    || { echo "échec : $ADRESSE/api/todos ne répond pas après le retour arrière (lire le journal du site)"; exit 1; }
  echo "  site redémarré sur la version précédente, $ADRESSE/api/todos répond"
else
  echo "  ni KIT_REDEMARRAGE, ni jeton d'API : redémarrer le site depuis l'administration de l'hébergeur"
fi
echo "Preuve (un seul passage) : E2E_PROFIL=public E2E_BASE_URL=$ADRESSE bash harness/e2e-smoke.sh"
