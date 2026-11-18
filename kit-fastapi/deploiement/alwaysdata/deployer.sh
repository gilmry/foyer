#!/usr/bin/env bash
# Déploie une instance du kit sur un hébergement infogéré de type alwaysdata, avec une base
# PostgreSQL gérée. La même livraison sert les DEUX montages (voir README.md, à côté) :
#   A — site « programme utilisateur » : lancer.sh → uvicorn (ASGI natif) ;
#   B — site « Python » (uWSGI) : wsgi.py → pont ASGI→WSGI.
# Rejouable : un second passage livre une nouvelle version, garde la précédente, ne réécrit pas
# la configuration et ne rejoue aucune migration déjà passée.
#
# Avec le jeton d'API de l'hébergeur (ALWAYSDATA_TOKEN dans le fichier .env du kit, ignoré par
# git), le script crée lui-même ce qui manque, après l'avoir annoncé : la base PostgreSQL
# <compte>_<instance>, son utilisateur du même nom (mot de passe tiré sur le serveur) et le site.
# Il ne modifie ni ne supprime jamais une base ou un site existants. Sans jeton, ces trois choses
# se créent à la main (voir le guide) et le script s'arrête avant tout envoi si elles manquent.
#
# Usage : bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> <adresse publique>
#   KIT_MONTAGE      A (défaut) ou B : le type du site que le script crée s'il manque.
#   ALWAYSDATA_SITE  numéro du site à redémarrer, s'il n'est pas celui qui sert l'adresse publique.
#   ALWAYSDATA_API   adresse de l'API de l'hébergeur (la répétition locale y met un faux serveur).
#   KIT_SSH, KIT_SCP commandes ssh et scp (défaut : mode non interactif).
#   KIT_DB_HOTE, KIT_DB_PORT  serveur de bases (défaut : postgresql-<compte>.alwaysdata.net, 5432).
#   KIT_DOSSIER      dossier de l'instance sur le serveur (défaut : /home/<compte>/<instance>).
#   KIT_PYTHON       Python 3.12 du serveur (défaut : /usr/alwaysdata/python/3.12/bin/python).
#   KIT_REDEMARRAGE  commande locale qui redémarre le site (répétition locale, autre hébergeur).
# Le serveur n'installe ni ne compile rien ; rien ne tourne dans la session SSH au-delà de copies
# et de commandes courtes. Aucun secret ne passe en argument ni n'est affiché.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,26p' "$0"; exit 2; }
HOTE="$1"; COMPTE="$2"; INSTANCE="$3"; ADRESSE="${4%/}"
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
DB_HOTE="${KIT_DB_HOTE:-postgresql-$COMPTE.alwaysdata.net}"
DB_PORT="${KIT_DB_PORT:-5432}"
PY_SERVEUR="${KIT_PYTHON:-/usr/alwaysdata/python/3.12/bin/python}"
read -r -a SSH <<<"${KIT_SSH:-ssh -o BatchMode=yes}"
read -r -a SCP <<<"${KIT_SCP:-scp -q -o BatchMode=yes}"

# Ces valeurs entrent dans des chemins, des noms de base et le fichier .env : formes strictes.
[[ "$COMPTE" =~ ^[a-z0-9][a-z0-9_-]*$ && "$INSTANCE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
  || { echo "compte et instance : lettres minuscules, chiffres, - et _ seulement"; exit 2; }
# L'hôte SSH part sur une ligne de commande : jamais une option déguisée (pas de tiret en tête).
[[ "$HOTE" =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] \
  || { echo "hôte ssh : lettres, chiffres, . _ @ - seulement, sans tiret en tête"; exit 2; }
[[ "$ADRESSE" =~ ^https?://[][A-Za-z0-9.:_-]+$ ]] \
  || { echo "adresse publique : https://hôte[:port], sans chemin"; exit 2; }
[[ "$DOSSIER$DB_HOTE$DB_PORT$PY_SERVEUR" =~ ^[][A-Za-z0-9./:_-]+$ ]] \
  || { echo "dossier, serveur de bases ou Python : caractère inattendu"; exit 2; }

KIT_BASE_MOTEUR=POSTGRESQL; KIT_FICHIER_MDP=.pgpass.gen; KIT_FICHIER_CONFIG=.env
# Les chemins d'un site se donnent relatifs au dossier du compte.
RELATIF="${DOSSIER#/home/$COMPTE/}"
case "${KIT_MONTAGE:-A}" in
  A) KIT_SITE_REGLAGES="{\"type\":\"user_program\",\"command\":\"$DOSSIER/lancer.sh\",\"working_directory\":\"$RELATIF\"}" ;;
  B) KIT_SITE_REGLAGES="{\"type\":\"wsgi\",\"path\":\"$RELATIF/wsgi.py\",\"working_directory\":\"$RELATIF\",\"python_version\":\"3.12\",\"uwsgi_additional_settings\":\"enable-threads = true\"}" ;;
  *) echo "KIT_MONTAGE : A (programme utilisateur) ou B (Python, uWSGI)"; exit 2 ;;
esac
source "$ICI/hebergeur.sh"

echo "0/4 Hébergeur : la base, son utilisateur et le site (créés s'ils manquent, jamais modifiés)"
hebergeur_preparer

echo "1/4 Préparation sur le poste (le serveur n'installe ni ne compile rien)"
bash "$ICI/construire.sh"

echo "2/4 Envoi vers $HOTE:$DOSSIER"
"${SSH[@]}" -- "$HOTE" "umask 077; mkdir -p '$DOSSIER/versions'"
# L'archive arrive sous un autre nom ; rien de ce que sert le site n'est touché ici. Les points
# d'entrée (lancer.sh, wsgi.py) sont DANS l'archive : ils basculent avec le code, pas avant.
"${SCP[@]}" -- "$ICI/dist/livraison.tgz" "$HOTE:$DOSSIER/livraison.tgz.nouveau"

echo "3/4 Configuration de l'instance (.env créé au premier passage, jamais réécrit ensuite), bascule"
"${SSH[@]}" -- "$HOTE" COMPTE="$COMPTE" INSTANCE="$INSTANCE" DOSSIER="$DOSSIER" DB_HOTE="$DB_HOTE" \
  DB_PORT="$DB_PORT" ADRESSE="$ADRESSE" PY="$PY_SERVEUR" sh -s <<'DISTANT'
set -eu
umask 077
cd "$DOSSIER"

# La livraison est dépliée à part, sous un nom provisoire.
rm -rf versions/.nouveau
mkdir versions/.nouveau
tar -C versions/.nouveau -xzf livraison.tgz.nouveau
rm -f livraison.tgz.nouveau
id="$(date -u +%Y%m%dT%H%M%SZ)-$(cat versions/.nouveau/VERSION)"
mv versions/.nouveau "versions/$id"

# Les modules compilés préparés sur le poste se chargent-ils avec le Python du serveur ?
# Commande courte, sans effet : c'est l'équivalent du `ldd` d'un binaire.
[ -x "$PY" ] || { echo "Python 3.12 introuvable sur le serveur : $PY (régler KIT_PYTHON)"; rm -rf "versions/$id"; exit 1; }
PYTHONPATH="versions/$id:versions/$id/deps" PYTHONDONTWRITEBYTECODE=1 "$PY" -c '
import sys
assert sys.version_info[:2] == (3, 12), "Python %d.%d au lieu de 3.12" % sys.version_info[:2]
import a2wsgi, argon2, fastapi, psycopg, pydantic_core, sqlalchemy, uvicorn
assert psycopg.pq.__impl__ == "binary", "psycopg sans sa bibliothèque embarquée"
argon2.PasswordHasher(time_cost=1, memory_cost=8, parallelism=1).hash("essai")
import app.migrate, app.accounts
' || { echo "la livraison ne se charge pas avec $PY : rien n'est changé"; rm -rf "versions/$id"; exit 1; }

if [ ! -f .env ]; then
  [ -s .pgpass.gen ] || { echo ".pgpass.gen absent de $DOSSIER : créer d'abord la base et son utilisateur (voir le guide)"; rm -rf "versions/$id"; exit 1; }
  # Le mot de passe est lu ici, sur le serveur : il ne passe ni par un argument, ni par une sortie.
  mdp="$(cat .pgpass.gen)"
  case "$mdp" in
    *[!A-Za-z0-9_.~+/=-]*) echo "le mot de passe de la base ne doit contenir que des lettres, des chiffres et _ . ~ + / = -"; rm -rf "versions/$id"; exit 1 ;;
  esac
  # La clé est tirée dans une variable et CONTRÔLÉE : un tirage raté n'écrit pas de clé vide.
  cle="$(openssl rand -hex 32)" || cle=""
  case "$cle" in
    *[!0-9a-f]*|"") echo "tirage de la clé d'instance impossible (openssl) : rien n'est changé"; rm -rf "versions/$id"; exit 1 ;;
  esac
  [ "${#cle}" -eq 64 ] || { echo "clé d'instance de longueur inattendue : rien n'est changé"; rm -rf "versions/$id"; exit 1; }
  # Écrit à part, puis renommé : .env existe complet ou n'existe pas. .pgpass.gen n'est supprimé qu'après.
  rm -f .env.nouveau
  {
    echo "# Réglages de l'instance. Créé par deployer.sh au premier passage, JAMAIS réécrit ensuite."
    echo "# Lu par lancer.sh (montage A) et par wsgi.py (montage B). Droits 600."
    echo "# Connexion directe au serveur de bases (jamais par un pooler)."
    echo "DB_HOST='$DB_HOTE'"
    echo "DB_PORT='$DB_PORT'"
    echo "DB_NAME='${COMPTE}_${INSTANCE}'"
    echo "DB_USER='${COMPTE}_${INSTANCE}'"
    echo "DB_PASSWORD='$mdp'"
    echo "# Clé de l'instance (empreintes des jetons), tirée ici. La changer révoque tous les jetons."
    echo "TODO_SECRET_KEY='$cle'"
    echo "# Adresse publique : origine attendue des requêtes à cookie. Exigée par l'application."
    echo "TODO_PUBLIC_URL='$ADRESSE'"
    echo "# Inscription fermée : les comptes se créent par ./lancer.sh outil app.accounts create <courriel>"
    echo "TODO_REGISTRATION='closed'"
    echo "# Adaptateurs (lignes modifiables à la main, puis redémarrer le site)."
    echo "TODO_HTTP='fastapi'"
    echo "TODO_PERSISTENCE='cqrs'"
    [ "$PY" = /usr/alwaysdata/python/3.12/bin/python ] || echo "KIT_PYTHON='$PY'"
  } > .env.nouveau
  unset mdp cle
  chmod 600 .env.nouveau
  mv -f .env.nouveau .env
  rm -f .pgpass.gen
  echo "  .env créé sur le serveur (droits 600, secrets tirés sur place)"
else
  echo "  .env gardé"
  # L'adresse n'est pas un secret : on la compare, et on prévient si elle a changé.
  connue="$(sed -n "s/^TODO_PUBLIC_URL='\\(.*\\)'\$/\\1/p" .env | head -n 1)"
  [ "$connue" = "$ADRESSE" ] || echo "  ATTENTION : l'adresse passée ($ADRESSE) diffère de TODO_PUBLIC_URL dans .env (${connue:-absente}). .env n'est pas réécrit : corrigez cette ligne à la main, sinon les requêtes du front seront refusées (origine)."
fi

# Témoin posé AVANT la bascule, et adressé à la nouvelle version : dès que le lien bascule, le
# premier démarrage migre ; un réveil de l'ancienne version entre-temps ne le consomme pas.
rm -f .migrer.nouveau
printf '%s\n' "$id" > .migrer.nouveau
mv -f .migrer.nouveau .migrer
# Les points d'entrée du site sont des liens vers ceux de la version courante (posés une fois).
for f in lancer.sh wsgi.py; do
  if [ "$(readlink "$f" 2>/dev/null || true)" != "courant/$f" ]; then
    ln -sfn "courant/$f" "$f.nouveau"
    mv -Tf "$f.nouveau" "$f"
  fi
done
# Bascule. La version précédente reste sur le serveur : c'est le retour arrière.
if [ -L courant ]; then
  ln -sfn "$(readlink courant)" precedent.nouveau
  mv -Tf precedent.nouveau precedent
fi
# Le lien `courant` change de cible d'un seul coup (renommage atomique) : lanceur, wsgi.py, code
# et dépendances passent ensemble à la nouvelle version.
ln -sfn "versions/$id" courant.nouveau
mv -Tf courant.nouveau courant
# Seules la version courante et la précédente sont gardées.
for v in versions/*; do
  [ "$v" = "$(readlink courant)" ] || [ "$v" = "$(readlink precedent 2>/dev/null || true)" ] || rm -rf "$v"
done
echo "  version $id en place ; précédente : $(readlink precedent 2>/dev/null || echo aucune)"
DISTANT

echo "4/4 Redémarrage du site : les migrations se jouent à ce démarrage (témoin .migrer)"
if hebergeur_redemarrer; then redemarre=1; else redemarre=0; fi
if [ "$redemarre" = 1 ]; then
  hebergeur_attendre "$ADRESSE/api/health" \
    || { echo "échec : $ADRESSE/api/health ne répond pas après le redémarrage (lire le journal du site)"; exit 1; }
  "${SSH[@]}" -- "$HOTE" "[ -z \"\$(ls -A '$DOSSIER' | grep '^\.migrer')\" ]" \
    || { echo "échec : un témoin .migrer est encore là — le site n'a pas redémarré sur la nouvelle version, ou ses migrations ont échoué (lire le journal du site)"; exit 1; }
  echo "  site redémarré, migrations à jour, $ADRESSE/api/health répond"
else
  echo "  ni KIT_REDEMARRAGE, ni jeton d'API : redémarrer le site depuis l'administration de l'hébergeur"
fi

cat <<FIN

Instance prête dans $HOTE:$DOSSIER
Réglages du site, selon le montage (voir le guide) :
  A — « programme utilisateur » : commande $DOSSIER/lancer.sh, répertoire de travail $DOSSIER
  B — « Python » (uWSGI)        : application $DOSSIER/wsgi.py, répertoire de travail $DOSSIER,
                                  Python 3.12, sans environnement virtuel, fils activés (enable-threads)
Comptes : $DOSSIER/lancer.sh outil app.accounts create <courriel>   (sur le serveur, commande courte)
Preuve (un seul passage) : E2E_PROFIL=public E2E_BASE_URL=$ADRESSE E2E_EMAIL_A=… E2E_PASSWORD_A=… E2E_EMAIL_B=… E2E_PASSWORD_B=… bash harness/e2e-smoke.sh
Retour arrière : bash deploiement/alwaysdata/revenir.sh $HOTE $COMPTE $INSTANCE $ADRESSE
  Le schéma, lui, ne recule pas tout seul : voir le guide.
FIN
