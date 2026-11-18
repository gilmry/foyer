#!/usr/bin/env bash
# Déploie une instance du kit sur un hébergement infogéré de type alwaysdata : un site « programme
# utilisateur » et une base PostgreSQL gérée. Rejouable : un second passage met à jour les binaires
# et le front, garde la version précédente, ne réécrit pas la configuration et ne rejoue aucune
# migration déjà passée. Guide : README.md, à côté.
#
# Avant le premier passage (une fois, dans l'administration de l'hébergeur) : une base PostgreSQL
# <compte>_<instance> et son utilisateur du même nom, tous droits sur elle ; sur le serveur, le
# fichier <dossier>/.pgpass.gen qui contient le seul mot de passe de cet utilisateur (droits 600).
#
# Usage : bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> <adresse publique>
#   ALWAYSDATA_SITE  numéro du site à redémarrer par l'API (jeton ALWAYSDATA_TOKEN dans le fichier
#                    .env du kit, ignoré par git). Sans lui, le script dit de redémarrer à la main.
#   KIT_SSH, KIT_SCP commandes ssh et scp (défaut : mode non interactif).
#   KIT_DB_HOTE, KIT_DB_PORT  serveur de bases (défaut : postgresql-<compte>.alwaysdata.net, 5432).
#   KIT_DOSSIER      dossier de l'instance sur le serveur (défaut : /home/<compte>/<instance>).
#   KIT_REDEMARRAGE  commande locale qui redémarre le site (répétition locale, autre hébergeur).
# Le script ne crée ni ne modifie le site : il affiche les réglages à y mettre.
# Rien ne tourne dans la session SSH au-delà de copies et de commandes courtes.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,20p' "$0"; exit 2; }
HOTE="$1"; COMPTE="$2"; INSTANCE="$3"; ADRESSE="${4%/}"
# Les arguments entrent dans des commandes distantes : seules des formes simples sont admises.
case "$HOTE" in -*|*[!A-Za-z0-9@._-]*) echo "hôte ssh invalide : $HOTE"; exit 2 ;; esac
case "$COMPTE$INSTANCE" in *[!A-Za-z0-9_-]*) echo "compte ou instance invalide (lettres, chiffres, - et _ seulement)"; exit 2 ;; esac
case "$ADRESSE" in http://*|https://*) ;; *) echo "adresse publique invalide : $ADRESSE"; exit 2 ;; esac
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
case "$DOSSIER" in /*) ;; *) echo "dossier invalide : $DOSSIER"; exit 2 ;; esac
case "$DOSSIER" in *[!A-Za-z0-9/._-]*) echo "dossier invalide : $DOSSIER"; exit 2 ;; esac
DB_HOTE="${KIT_DB_HOTE:-postgresql-$COMPTE.alwaysdata.net}"
DB_PORT="${KIT_DB_PORT:-5432}"
read -r -a SSH <<<"${KIT_SSH:-ssh -o BatchMode=yes}"
read -r -a SCP <<<"${KIT_SCP:-scp -q -o BatchMode=yes}"

echo "1/4 Construction sur le poste (le serveur ne compile rien)"
bash "$ICI/construire.sh"

echo "2/4 Envoi vers $HOTE:$DOSSIER"
"${SSH[@]}" -- "$HOTE" "umask 077; mkdir -p '$DOSSIER'"
# Chaque fichier arrive sous un autre nom, puis remplace l'ancien d'un coup (renommage atomique).
"${SCP[@]}" "$ICI/dist/server" "$HOTE:$DOSSIER/server.nouveau"
"${SCP[@]}" "$ICI/dist/migrate" "$HOTE:$DOSSIER/migrate.nouveau"
"${SCP[@]}" "$ICI/lancer.sh" "$HOTE:$DOSSIER/lancer.sh.nouveau"
tar -C "$ICI/dist" -czf - public | "${SSH[@]}" -- "$HOTE" \
  "rm -rf '$DOSSIER/public.nouveau' && mkdir '$DOSSIER/public.nouveau' && tar -C '$DOSSIER/public.nouveau' --strip-components=1 -xzf -"

echo "3/4 Configuration de l'instance (.env créé au premier passage, jamais réécrit ensuite)"
"${SSH[@]}" -- "$HOTE" COMPTE="$COMPTE" INSTANCE="$INSTANCE" DOSSIER="$DOSSIER" DB_HOTE="$DB_HOTE" DB_PORT="$DB_PORT" sh -s <<'DISTANT'
set -eu
umask 077
cd "$DOSSIER"
chmod 700 server.nouveau migrate.nouveau lancer.sh.nouveau
manque="$(ldd server.nouveau migrate.nouveau 2>&1 | grep 'not found' || true)"
[ -z "$manque" ] || { echo "bibliothèque manquante sur le serveur :"; echo "$manque"; exit 1; }
if [ ! -f .env ]; then
  [ -s .pgpass.gen ] || { echo ".pgpass.gen absent de $DOSSIER : créer d'abord la base et son utilisateur (voir le guide)"; exit 1; }
  motdepasse="$(cat .pgpass.gen)"
  [ -n "$motdepasse" ] || { echo ".pgpass.gen est vide"; exit 1; }
  # Écrit à côté puis renommé : une session coupée ne laisse jamais un .env à moitié écrit.
  {
    # Connexion directe au serveur de bases, jamais par un pooler. Le mot de passe est lu ici, sur
    # le serveur : il ne passe ni par un argument de commande, ni par une sortie.
    echo "DATABASE_URL=postgres://${COMPTE}_${INSTANCE}:${motdepasse}@${DB_HOTE}:${DB_PORT}/${COMPTE}_${INSTANCE}"
    echo "TODO_PERSISTENCE=cqrs"
    echo "PUBLIC_DIR=$DOSSIER/public"
  } > .env.nouveau
  mv -f .env.nouveau .env
  rm -f .pgpass.gen
  echo "  .env créé sur le serveur (droits 600)"
else
  echo "  .env gardé"
fi
# Témoin posé AVANT la bascule : si la plateforme relance le site entre deux renommages, le
# lanceur joue quand même les migrations manquantes. Jamais de nouveau code sans son schéma.
touch .migrer
# La version précédente reste sur le serveur : c'est le retour arrière.
[ -f server ] && cp -p server server.precedent
[ -f migrate ] && cp -p migrate migrate.precedent
mv -f server.nouveau server
mv -f migrate.nouveau migrate
mv -f lancer.sh.nouveau lancer.sh
rm -rf public.precedent
[ -d public ] && mv public public.precedent
mv public.nouveau public
# Reposé après la bascule : si un réveil du site a consommé le premier témoin avec l'ancienne
# version, le redémarrage qui suit joue bien les migrations de la nouvelle.
touch .migrer
DISTANT

echo "4/4 Redémarrage du site : les migrations se jouent à ce démarrage (témoin .migrer)"
redemarre=0
if [ -n "${KIT_REDEMARRAGE:-}" ]; then
  eval "$KIT_REDEMARRAGE"
  redemarre=1
elif [ -n "${ALWAYSDATA_SITE:-}" ] && grep -q '^ALWAYSDATA_TOKEN=' "$RACINE/.env" 2>/dev/null; then
  # Par l'API de l'hébergeur, jamais par un processus lancé en SSH. Le jeton est lu dans le
  # fichier .env du kit (ignoré par git) : il n'est ni passé en argument, ni affiché.
  code="$(python3 -I - "$RACINE/.env" "$COMPTE" "$ALWAYSDATA_SITE" <<'PY'
import base64, sys, urllib.error, urllib.request
env, compte, site = sys.argv[1:4]
jeton = next(l.split("=", 1)[1].strip().strip("\"'") for l in open(env) if l.startswith("ALWAYSDATA_TOKEN="))
auth = base64.b64encode(f"{jeton} account={compte}:".encode()).decode()
req = urllib.request.Request(f"https://api.alwaysdata.com/v1/site/{site}/restart/", method="POST",
                             headers={"Authorization": "Basic " + auth})
try:
    print(urllib.request.urlopen(req, timeout=60).status)
except urllib.error.HTTPError as e:
    print(e.code)
PY
)"
  [ "$code" = 204 ] || { echo "échec du redémarrage par l'API : HTTP $code"; exit 1; }
  redemarre=1
fi
if [ "$redemarre" = 1 ]; then
  ok=0
  for _ in $(seq 1 60); do
    curl -sf --max-time 10 "$ADRESSE/api/todos" >/dev/null 2>&1 && { ok=1; break; }
    sleep 2
  done
  [ "$ok" = 1 ] || { echo "échec : $ADRESSE/api/todos ne répond pas après le redémarrage (lire le journal du site)"; exit 1; }
  "${SSH[@]}" -- "$HOTE" "[ ! -f '$DOSSIER/.migrer' ]" || { echo "échec : le témoin .migrer est encore là, le site n'a pas redémarré"; exit 1; }
  echo "  site redémarré, migrations à jour, $ADRESSE/api/todos répond"
else
  echo "  ni KIT_REDEMARRAGE, ni ALWAYSDATA_SITE avec son jeton : redémarrer le site depuis l'administration de l'hébergeur"
fi

cat <<FIN

Instance prête dans $HOTE:$DOSSIER
Réglages du site (type « programme utilisateur ») :
  commande              $DOSSIER/lancer.sh
  répertoire de travail $DOSSIER
Preuve (un seul passage) : E2E_PROFIL=public E2E_BASE_URL=$ADRESSE bash harness/e2e-smoke.sh
Retour arrière : sur le serveur, remettre server.precedent, migrate.precedent et public.precedent
  à la place des versions courantes, puis redémarrer le site.
FIN
