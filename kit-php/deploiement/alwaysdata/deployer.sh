#!/usr/bin/env bash
# Déploie une instance du kit sur un hébergement PHP infogéré (alwaysdata : site de type « PHP »
# servi par l'Apache de l'hébergeur, base MariaDB gérée). Rejouable. Guide : README.md voisin.
#
# Avant le premier passage (une fois, dans l'administration de l'hébergeur) : la base et son
# utilisateur, tous droits sur elle et sur elle seule ; sur le serveur, le fichier
# <dossier>/.dbpass qui contient le seul mot de passe de cet utilisateur (droits 600) ; le site
# PHP, racine sur <dossier>/courant/public.
#
# Usage : bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> <adresse publique>
#   ex. : bash deploiement/alwaysdata/deployer.sh <hôte> <compte> <instance> https://<adresse>
#   KIT_PHP_VERSION (défaut 8.3)  version mineure de PHP du site : vendor/ est construit avec elle.
#   KIT_DB_HOST, KIT_DB_NAME, KIT_DB_USER, KIT_DB_PORT  base de l'instance (défauts : ceux de l'hébergeur).
#   KIT_DOSSIER (défaut /home/<compte>/<instance>)      dossier de l'instance sur le serveur.
#   KIT_SSH, KIT_SCP              commandes ssh et scp de remplacement (répétition locale).
#
# Ce que fait le script, et dans quel ordre :
#   1. construit vendor/ SUR LE POSTE, dans l'image PHP du kit (composer install --no-dev), et
#      préchauffe le cache du noyau ; rien de tout cela ne tourne jamais sur le serveur ;
#   2. envoie la version en une archive, dans un dossier de version neuf ;
#   3. crée la configuration de l'instance au premier passage, SUR LE SERVEUR : le secret du noyau
#      y est tiré (openssl rand). Elle n'est jamais réécrite ensuite. Aucun secret ne passe en
#      argument ni dans une sortie ;
#   4. joue les migrations manquantes (commande courte : php bin/migrate.php up) ;
#   5. bascule le lien `courant` d'un seul renommage (atomique), garde la version précédente,
#      puis attend que la sonde de santé réponde AVEC le nom de la nouvelle version.
# Rien ne tourne dans la session SSH au-delà de copies et de commandes courtes.
set -euo pipefail
[ $# -eq 4 ] || { sed -n '2,16p' "$0"; exit 2; }
HOTE="$1"; COMPTE="$2"; INSTANCE="$3"; ADRESSE="${4%/}"
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$ICI/../.." && pwd)"

# Ces valeurs entrent dans des commandes, des chemins et la configuration : rien d'exotique.
# Un hôte qui commencerait par un tiret serait lu par ssh comme une option.
[[ "$HOTE" =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] || { echo "hôte ssh invalide"; exit 2; }
[[ "$COMPTE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "compte invalide"; exit 2; }
[[ "$INSTANCE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "instance invalide"; exit 2; }
[[ "$ADRESSE" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || { echo "adresse publique invalide (attendu : https://hôte, sans chemin)"; exit 2; }

read -r -a SSH <<< "${KIT_SSH:-ssh -o BatchMode=yes}"
read -r -a SCP <<< "${KIT_SCP:-scp -q -o BatchMode=yes}"
DOSSIER="${KIT_DOSSIER:-/home/$COMPTE/$INSTANCE}"
DB_HOST="${KIT_DB_HOST:-mysql-$COMPTE.alwaysdata.net}"
DB_PORT="${KIT_DB_PORT:-3306}"
DB_NAME="${KIT_DB_NAME:-${COMPTE}_${INSTANCE}}"
DB_USER="${KIT_DB_USER:-${COMPTE}_${INSTANCE}}"
for v in "$DOSSIER" "$DB_HOST" "$DB_PORT" "$DB_NAME" "$DB_USER"; do
  [[ "$v" =~ ^[A-Za-z0-9./_-]+$ ]] || { echo "valeur invalide : $v"; exit 2; }
done
export KIT_PHP_VERSION="${KIT_PHP_VERSION:-8.3}"
[[ "$KIT_PHP_VERSION" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "KIT_PHP_VERSION invalide (attendu : 8.3, 8.4…)"; exit 2; }
# Une adresse en http:// donnerait un cookie de session sans drapeau Secure et pas de HSTS : refus,
# sauf demande explicite (répétition sur une cible sans TLS).
case "$ADRESSE" in
  https://*) : ;;
  *) [ "${KIT_AUTORISER_HTTP:-}" = 1 ] || { echo "refus : l'adresse publique doit être en https:// (KIT_AUTORISER_HTTP=1 pour passer outre, hors production)"; exit 2; }
     echo "ATTENTION : adresse en http:// — cookie de session sans drapeau Secure, pas de HSTS. Jamais en production." ;;
esac
VERSION="$(date -u +%Y%m%d-%H%M%S)"
CIBLE="$DOSSIER/versions/$VERSION"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "1/5 Construction de la version $VERSION sur le poste (PHP $KIT_PHP_VERSION, composer install --no-dev)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image
mkdir -p "$TMP/version" "$ROOT/var/composer-cache"
cp -R "$ROOT/public" "$ROOT/src" "$ROOT/bin" "$ROOT/database" "$ROOT/composer.json" "$ROOT/composer.lock" "$TMP/version/"
# La configuration locale éventuelle ne part jamais : celle de l'instance naît sur le serveur.
# Ni aucun fichier caché de src/ (un .dbpass ou un .env posé là par mégarde resterait sur le poste).
rm -f "$TMP/version/src/config.php"
find "$TMP/version" -mindepth 1 -name '.*' ! -name '.htaccess' -prune -exec rm -rf {} +
# Date neuve sur le contrôleur frontal : précaution pour OPcache. La bascule est de toute façon
# vue aussitôt, public/index.php relisant le lien `courant` à chaque requête.
touch "$TMP/version/public/index.php"
# Le dossier est monté AU CHEMIN qu'il aura sur le serveur : le cache du noyau contient des chemins absolus.
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e COMPOSER_CACHE_DIR=/cache \
  -v "$ROOT/var/composer-cache":/cache -v "$TMP/version":"$CIBLE" -w "$CIBLE" todo-kit-php:local \
  sh -c 'composer install --no-dev --optimize-autoloader --no-interaction --no-progress >/dev/null 2>&1 && php bin/warmup.php >/dev/null && php -r "echo \"  PHP \", PHP_VERSION, \", vendor et cache du noyau prêts\n\";"'
tar -C "$TMP" -czf "$TMP/$VERSION.tar.gz" version
echo "  archive : $(du -h "$TMP/$VERSION.tar.gz" | cut -f1)"

echo "2/5 Envoi vers $HOTE:$DOSSIER/versions/"
"${SSH[@]}" -- "$HOTE" "umask 077; mkdir -p '$DOSSIER/versions'"
"${SCP[@]}" -- "$TMP/$VERSION.tar.gz" "$HOTE:$DOSSIER/versions/$VERSION.tar.gz"

echo "3/5 Configuration de l'instance (créée au premier passage, jamais réécrite), 4/5 migrations, 5/5 bascule"
"${SSH[@]}" -- "$HOTE" DOSSIER="$DOSSIER" VERSION="$VERSION" ADRESSE="$ADRESSE" \
  DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_NAME="$DB_NAME" DB_USER="$DB_USER" PHP_VOULU="$KIT_PHP_VERSION" sh -s <<'DISTANT'
set -eu
# Tout le travail est dans une fonction appelée à la DERNIÈRE ligne : si le script arrivait
# tronqué, rien ne s'exécuterait à moitié.
principal() {
umask 077
cd "$DOSSIER"

# Dossier de version neuf : l'archive y est dépliée, puis supprimée.
rm -rf "versions/$VERSION"
mkdir "versions/$VERSION"
tar -C "versions/$VERSION" --strip-components=1 -xzf "versions/$VERSION.tar.gz"
rm -f "versions/$VERSION.tar.gz"

# Le PHP de la ligne de commande suffit aux outils bin/ (PDO seul, sans Composer).
php -r 'exit(version_compare(PHP_VERSION, "8.3.0", ">=") && extension_loaded("pdo_mysql") ? 0 : 1);' \
  || { echo "échec : il faut PHP >= 8.3 avec pdo_mysql en ligne de commande"; exit 1; }
php -r 'echo "  PHP en ligne de commande : ", PHP_VERSION, "\n";'
case "$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')" in
  "$PHP_VOULU") : ;;
  *) echo "  attention : vendor/ est construit pour PHP $PHP_VOULU ; régler le site sur cette version" ;;
esac

if [ ! -f config.php ]; then
  [ -s .dbpass ] || { echo "échec : $DOSSIER/.dbpass absent — créer d'abord la base et son utilisateur, puis ce fichier"; exit 1; }
  chmod 600 .dbpass
  # Le secret du noyau naît ici, sur le serveur. Il n'est ni affiché ni renvoyé au poste.
  SECRET="$(openssl rand -hex 32)"
  # Écrite à côté, vérifiée, puis renommée : jamais de configuration à moitié écrite ou fausse en place.
  cat > config.php.nouveau <<PHP
<?php

// Configuration de l'instance — écrite UNE fois par deploiement/alwaysdata/deployer.sh, sur le
// serveur. Droits 600, hors de la racine du site, jamais versionnée. Les clés sont décrites dans
// src/config.example.php. Modifier ce fichier suffit à changer d'adaptateur.
return [
    'http' => 'apiplatform',
    'persistence' => 'cqrs',
    'db' => [
        'host' => '$DB_HOST',
        'port' => $DB_PORT,
        'database' => '$DB_NAME',
        'username' => '$DB_USER',
        'password' => trim((string) file_get_contents(__DIR__ . '/.dbpass')),
        'charset' => 'utf8mb4',
    ],
    'secret' => '$SECRET',
    'public_url' => '$ADRESSE',
    'registration' => 'closed',
    'var_dir' => __DIR__ . '/var',
    'log_level' => 'notice',
];
PHP
  unset SECRET
  chmod 600 config.php.nouveau
  php -l config.php.nouveau >/dev/null 2>&1 || { rm -f config.php.nouveau; echo "échec : la configuration écrite n'est pas du PHP valide"; exit 1; }
  mv config.php.nouveau config.php
  echo "  configuration créée (secret du noyau tiré sur le serveur)"
else
  echo "  configuration gardée"
fi
mkdir -p var/log var/sessions var/pools
# Chaque version lit la configuration de l'instance par ce lien.
ln -sfn "$DOSSIER/config.php" "versions/$VERSION/src/config.php"

# Migrations AVANT la bascule : le nouveau code ne sert jamais sur un schéma en retard. Tant que
# le lien `courant` n'est pas renommé, le site ne sert que l'ancienne version (public/index.php
# suit ce lien) ; si une migration échoue, le script s'arrête ici et rien ne bascule.
( cd "versions/$VERSION" && php bin/migrate.php up )

# Bascule atomique : le lien est préparé à côté, puis renommé d'un coup. L'ancienne version
# reste en place, désignée par le lien `precedent` : c'est le retour arrière.
if [ -L courant ] && [ "$(readlink courant)" != "versions/$VERSION" ]; then
  ln -sfn "$(readlink courant)" precedent
fi
ln -sfn "versions/$VERSION" courant.nouveau
mv -T courant.nouveau courant
echo "  bascule faite : courant -> versions/$VERSION$( [ -L precedent ] && echo " ; precedent -> $(readlink precedent)" )"

# Ménage : on garde la version courante, la précédente et la plus récente des autres.
garder="$(readlink courant) $( [ -L precedent ] && readlink precedent || true )"
n=0
for d in $(ls -1d versions/*/ 2>/dev/null | sed 's#/$##' | sort -r); do
  case " $garder " in *" $d "*) continue ;; esac
  n=$((n + 1))
  if [ "$n" -gt 1 ]; then rm -rf "$d"; fi
done
}
principal
DISTANT

echo "Sonde de santé : $ADRESSE/api/health doit répondre avec la version $VERSION"
ok=0
for _ in $(seq 1 90); do
  rep="$(curl -sf --max-time 10 "$ADRESSE/api/health" 2>/dev/null || true)"
  case "$rep" in *'"status":"ok"'*"\"version\":\"$VERSION\""*) ok=1; break ;; esac
  sleep 2
done
if [ "$ok" != 1 ]; then
  cat <<FIN
échec : la sonde de santé ne répond pas avec la version $VERSION.
  - premier passage : créer le site PHP (racine $DOSSIER/courant/public), puis relancer ;
  - sinon, retour arrière (voir le guide) :
      ssh $HOTE 'cd $DOSSIER && ln -sfn "\$(readlink precedent)" courant.nouveau && mv -T courant.nouveau courant'
FIN
  exit 1
fi
echo "  santé verte : $rep"

cat <<FIN

Instance prête dans $HOTE:$DOSSIER (version $VERSION)
Site de l'hébergeur (type « PHP », version $KIT_PHP_VERSION) :
  racine du site   $DOSSIER/courant/public
Comptes (l'inscription par l'API est fermée) :
  ssh $HOTE 'cd $DOSSIER/courant && php bin/account.php create <courriel>'
FIN
