#!/usr/bin/env bash
# Retour arrière : remet en service la version précédente d'une instance (celle que deployer.sh a
# gardée, désignée par le lien `precedent`), puis redémarre le site. La version quittée devient
# la précédente : rejouer ce script annule le retour.
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
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
read -r -a SSH <<<"${KIT_SSH:-ssh -o BatchMode=yes}"
[[ "$COMPTE" =~ ^[a-z0-9][a-z0-9_-]*$ && "$INSTANCE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
  || { echo "compte et instance : lettres minuscules, chiffres, - et _ seulement"; exit 2; }
[[ "$HOTE" =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] \
  || { echo "hôte ssh : lettres, chiffres, . _ @ - seulement, sans tiret en tête"; exit 2; }
[[ "$ADRESSE" =~ ^https?://[][A-Za-z0-9.:_-]+$ ]] \
  || { echo "adresse publique : https://hôte[:port], sans chemin"; exit 2; }
[[ "$DOSSIER" =~ ^/[A-Za-z0-9./_-]+$ ]] || { echo "dossier : caractère inattendu"; exit 2; }
source "$ICI/hebergeur.sh"

echo "1/2 Échange de la version en service et de la précédente dans $HOTE:$DOSSIER"
"${SSH[@]}" -- "$HOTE" DOSSIER="$DOSSIER" sh -s <<'DISTANT'
set -eu
umask 077
cd "$DOSSIER"
[ -L courant ] && [ -L precedent ] && [ -d "$(readlink precedent)" ] \
  || { echo "aucune version précédente dans $DOSSIER : rien n'est changé"; exit 1; }
quittee="$(readlink courant)"; reprise="$(readlink precedent)"
[ "$quittee" != "$reprise" ] || { echo "la version précédente est déjà en service : rien n'est changé"; exit 1; }
# Aucune migration au démarrage qui suit : le schéma reste celui de la version quittée.
rm -f .migrer
ln -sfn "$reprise" courant.nouveau
mv -Tf courant.nouveau courant
ln -sfn "$quittee" precedent.nouveau
mv -Tf precedent.nouveau precedent
echo "  en service : $reprise ; gardée : $quittee"
DISTANT

echo "2/2 Redémarrage du site"
hebergeur_site
if hebergeur_redemarrer; then
  hebergeur_attendre "$ADRESSE/api/health" \
    || { echo "échec : $ADRESSE/api/health ne répond pas après le retour arrière (lire le journal du site)"; exit 1; }
  echo "  site redémarré sur la version précédente, $ADRESSE/api/health répond"
else
  echo "  ni KIT_REDEMARRAGE, ni jeton d'API : redémarrer le site depuis l'administration de l'hébergeur"
fi
echo "Preuve (un seul passage) : E2E_PROFIL=public E2E_BASE_URL=$ADRESSE … bash harness/e2e-smoke.sh (voir le guide)"
