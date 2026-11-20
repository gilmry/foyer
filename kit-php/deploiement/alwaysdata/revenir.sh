#!/usr/bin/env bash
# Retour arrière : remet en service la version précédente d'une instance (celle que deployer.sh a
# gardée, désignée par le lien `precedent`). La version quittée devient la précédente : rejouer ce
# script annule le retour. Un site PHP ne se redémarre pas : la bascule du lien suffit.
#
# Ce script ne touche PAS au schéma de la base : aucune migration n'est jouée ni défaite. Revenir
# sur une release qui portait une migration de schéma demande donc une décision humaine (l'ancien
# code doit tenir sur le nouveau schéma, ou la base être restaurée depuis sa sauvegarde).
#
# Usage : bash deploiement/alwaysdata/revenir.sh <hôte ssh> <compte> <instance> <adresse publique>
#   KIT_SSH, KIT_DOSSIER : comme pour deployer.sh.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,11p' "$0"; exit 2; }
HOTE="$1"; COMPTE="$2"; INSTANCE="$3"; ADRESSE="${4%/}"
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
[[ "$HOTE" =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] || { echo "hôte ssh invalide"; exit 2; }
[[ "$COMPTE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "compte invalide"; exit 2; }
[[ "$INSTANCE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "instance invalide"; exit 2; }
[[ "$ADRESSE" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || { echo "adresse publique invalide (attendu : https://hôte, sans chemin)"; exit 2; }
read -r -a SSH <<< "${KIT_SSH:-ssh -o BatchMode=yes}"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
[[ "$DOSSIER" =~ ^/[A-Za-z0-9./_-]+$ ]] || { echo "dossier invalide"; exit 2; }
source "$ICI/hebergeur.sh"
# PHP peut garder l'ancienne résolution du lien `courant` jusqu'à 120 secondes (realpath_cache_ttl
# relevé chez l'hébergeur) : la sonde attend jusqu'à trois minutes.
KIT_ATTENTE_ESSAIS="${KIT_ATTENTE_ESSAIS:-60}"
SITE_NEUF=0

echo "1/2 Échange de la version en service et de la précédente dans $HOTE:$DOSSIER"
reprise="$("${SSH[@]}" -- "$HOTE" DOSSIER="$DOSSIER" sh -s <<'DISTANT'
set -eu
umask 077
cd "$DOSSIER"
[ -L courant ] && [ -L precedent ] && [ -d "$(readlink precedent)" ] \
  || { echo "aucune version précédente dans $DOSSIER : rien n'est changé" >&2; exit 1; }
quittee="$(readlink courant)"; reprise="$(readlink precedent)"
[ "$quittee" != "$reprise" ] || { echo "la version précédente est déjà en service : rien n'est changé" >&2; exit 1; }
ln -sfn "$reprise" courant.nouveau
mv -T courant.nouveau courant
ln -sfn "$quittee" precedent.nouveau
mv -T precedent.nouveau precedent
basename "$reprise"
DISTANT
)"
[[ "$reprise" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "échec : version reprise illisible"; exit 1; }
echo "  en service : $reprise"

echo "2/2 Sonde de santé : $ADRESSE/api/health doit répondre avec la version $reprise"
hebergeur_attendre "$ADRESSE/api/health" "\"version\":\"$reprise\"" \
  || { echo "échec : la sonde de santé ne répond pas avec la version $reprise (lire le journal du site)"; exit 1; }
echo "  santé verte : la version $reprise répond"
echo "Preuve (un seul passage) : le smoke au profil public, E2E_PROFIL=public (voir le guide)"
