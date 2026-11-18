#!/usr/bin/env bash
# Gate `deploiement` — RÉPÉTITION LOCALE du déploiement sur hébergement PHP infogéré.
#
# Monte une cible jetable qui ressemble à l'hébergeur (harness/cible : Debian 12, Apache + PHP en
# FastCGI sous l'identité d'un compte sans privilège, .htaccess limité, OPcache, sshd, TLS) et une
# MariaDB LTS à login sans privilège ; y joue le VRAI script deploiement/alwaysdata/deployer.sh
# DEUX fois ; puis rejoue les smokes e2e contre son adresse (E2E_BASE_URL), pour CHAQUE
# combinaison adaptateur HTTP (apiplatform, vanilla) × persistance (cqrs, doctrine).
# Le gate `integration` y est aussi rejoué, sur MariaDB, avec le login sans privilège.
#
# Ce gate ne prouve pas l'hébergeur lui-même : il prouve que le kit et son script tiennent leurs
# promesses avant d'y aller. Ce qui ne se prouve que là-bas reste « non prouvé chez l'hébergeur ».
#   KIT_PHP_VERSION (défaut 8.3) : version de PHP de la cible ET de la construction de vendor/.
set -Eeuo pipefail
unset E2E_PROFIL E2E_PAUSE   # la répétition choisit elle-même le profil du smoke
# Le gate ne meurt jamais sans dire où : ligne et commande de tout arrêt inattendu.
trap 'echo "✗ arrêt inattendu ligne $LINENO : $BASH_COMMAND" >&2' ERR
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_php_image; ensure_vendor

CIBLE=kit-php-cible; BASE_DB=kit-php-mariadb; RESEAU=kit-php-repet
# Montage de PHP sur la cible : fcgid (Apache + mod_fcgid + php-cgi, celui relevé chez l'hébergeur,
# défaut) ou fpm (Apache + PHP-FPM, à la demande : KIT_CIBLE=fpm).
KIT_CIBLE="${KIT_CIBLE:-fcgid}"
case "$KIT_CIBLE" in fcgid) VARIANTE=cli; MONTAGE="Apache + mod_fcgid + php-cgi" ;; fpm) VARIANTE=fpm; MONTAGE="Apache + PHP-FPM" ;; *) echo "KIT_CIBLE : fcgid ou fpm"; exit 2 ;; esac
IMAGE_CIBLE="todo-kit-php-cible:$KIT_PHP_VERSION-$KIT_CIBLE"
COMPTE=repet; INSTANCE=kit
DOSSIER="/home/$COMPTE/$INSTANCE"; DB="${COMPTE}_${INSTANCE}"; DB_INTEG="${COMPTE}_integ"
PORT_SSH=12322; PORT_SITE=18443
ADRESSE="https://127.0.0.1:$PORT_SITE"
TMP="$(mktemp -d)"
JOURNAL="$TMP/deployer.log"

fail=0
ok() { echo "  ✓ $1"; }
ko() { echo "  ✗ $1"; fail=1; }
verifier() { local l="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$l"; else ko "$l"; fi; }
sur_cible() { docker exec -u "$COMPTE" "$CIBLE" sh -c "$1"; }
racine_cible() { docker exec "$CIBLE" sh -c "$1"; }
par_ssh() { ssh -F "$TMP/ssh_config" -o BatchMode=yes cible "$@"; }
# SQL d'administration de la base gérée (ce que fait l'administration de l'hébergeur) : le mot de
# passe root reste dans le conteneur, il est lu là-bas.
admin_sql() { docker exec -i "$BASE_DB" sh -c 'exec mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'; }
sante() { curl -s --max-time 10 "$ADRESSE/api/health" 2>/dev/null || true; }
champ() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }
# attendre_sante <motif> : la sonde de santé contient le motif (au plus 60 s).
attendre_sante() {
  local i
  for i in $(seq 1 60); do case "$(sante)" in *"$1"*) return 0 ;; esac; sleep 1; done
  return 1
}

nettoyer() {
  docker rm -f "$CIBLE" "$BASE_DB" >/dev/null 2>&1 || true
  docker network rm "$RESEAU" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap nettoyer EXIT
nettoyer; mkdir -p "$TMP"

echo "▶ cible jetable (Debian 12, $MONTAGE, PHP $KIT_PHP_VERSION, sshd, compte « $COMPTE » sans privilège)"
# Construite à chaque passage : le cache de Docker rend cela immédiat tant que harness/cible ne change pas.
docker build -q -t "$IMAGE_CIBLE" --build-arg PHP_VERSION="$KIT_PHP_VERSION" --build-arg VARIANTE="$VARIANTE" "$ROOT/harness/cible" >/dev/null
docker network create "$RESEAU" >/dev/null
( umask 077; printf 'MARIADB_ROOT_PASSWORD=%s\n' "$(openssl rand -hex 24)" > "$TMP/mariadb.env" )
docker run -d --name "$BASE_DB" --network "$RESEAU" --env-file "$TMP/mariadb.env" mariadb:lts >/dev/null
docker run -d --name "$CIBLE" --network "$RESEAU" -p "127.0.0.1:$PORT_SSH:22" -p "127.0.0.1:$PORT_SITE:443" "$IMAGE_CIBLE" >/dev/null
ssh-keygen -q -t ed25519 -N '' -f "$TMP/cle"
docker exec -i -u "$COMPTE" "$CIBLE" sh -c 'umask 077; cat > ~/.ssh/authorized_keys' < "$TMP/cle.pub"
cat > "$TMP/ssh_config" <<CONF
Host cible
  HostName 127.0.0.1
  Port $PORT_SSH
  User $COMPTE
  IdentityFile $TMP/cle
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
CONF
for _ in $(seq 1 60); do par_ssh true 2>/dev/null && break; sleep 0.5; done
verifier "la cible répond en SSH, sous un compte sans privilège" par_ssh 'test "$(id -u)" != 0'
verifier "la cible n'a ni Composer ni git (rien ne peut s'y installer)" par_ssh '! command -v composer && ! command -v git'
# Le certificat autosigné de la cible, pour que curl vérifie TLS comme en production.
for _ in $(seq 1 60); do docker exec "$CIBLE" test -s /etc/ssl/kit/cert.pem 2>/dev/null && break; sleep 0.5; done
docker exec "$CIBLE" cat /etc/ssl/kit/cert.pem > "$TMP/cert.pem"
export CURL_CA_BUNDLE="$TMP/cert.pem"

echo "▶ base gérée : MariaDB, login « $DB » sans privilège ; mot de passe tiré sur la cible"
for _ in $(seq 1 90); do echo 'SELECT 1;' | admin_sql >/dev/null 2>&1 && break; sleep 1; done
VERSION_BASE="$(echo 'SELECT VERSION();' | admin_sql | tail -1)"
echo "  · $VERSION_BASE (image mariadb:lts)"
# Ce que le porteur fait dans l'administration de l'hébergeur. Le mot de passe naît sur la cible
# et n'est jamais affiché : il passe d'un conteneur à l'autre par un tube.
sur_cible "umask 077; mkdir -p $DOSSIER; openssl rand -hex 24 > $DOSSIER/.dbpass"
( umask 077; printf 'DB_HOST=%s\nDB_PORT=3306\nDB_NAME=%s\nDB_USER=%s\nDB_PASSWORD=%s\n' "$BASE_DB" "$DB_INTEG" "$DB_INTEG" "$(openssl rand -hex 24)" > "$TMP/integ.env" )
{
  printf "CREATE DATABASE %s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n" "$DB"
  printf "CREATE USER '%s'@'%%' IDENTIFIED BY '%s';\n" "$DB" "$(sur_cible "cat $DOSSIER/.dbpass")"
  printf "GRANT ALL PRIVILEGES ON %s.* TO '%s'@'%%';\n" "$DB" "$DB"
  printf "CREATE DATABASE %s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n" "$DB_INTEG"
  printf "CREATE USER '%s'@'%%' IDENTIFIED BY '%s';\n" "$DB_INTEG" "$(sed -n 's/^DB_PASSWORD=//p' "$TMP/integ.env")"
  printf "GRANT ALL PRIVILEGES ON %s.* TO '%s'@'%%';\nFLUSH PRIVILEGES;\n" "$DB_INTEG" "$DB_INTEG"
} | admin_sql

echo "▶ gate integration rejoué sur MariaDB, login sans privilège (CQRS et Doctrine)"
if docker run --rm --network "$RESEAU" -u "$(id -u):$(id -g)" -e HOME=/tmp -e TZ=UTC --env-file "$TMP/integ.env" \
     -v "$ROOT":/app -w /app todo-kit-php:local php harness/integration-todos.php > "$TMP/integ.log" 2>&1; then
  ok "$(tail -1 "$TMP/integ.log") sur $VERSION_BASE"; INTEG_MARIADB=oui
else
  grep -E '✗|Fatal|rror' "$TMP/integ.log" | head -10; ko "integration sur MariaDB"; INTEG_MARIADB=non
fi

echo "▶ garde-fous de deployer.sh (refus avant toute action)"
refuse() { ! bash "$ROOT/deploiement/alwaysdata/deployer.sh" "$@" >/dev/null 2>&1; }
verifier "adresse publique en http:// → refus" refuse cible "$COMPTE" "$INSTANCE" "http://127.0.0.1:$PORT_SITE"
verifier "hôte qui commence par un tiret → refus" refuse "-oProxyCommand=true" "$COMPTE" "$INSTANCE" "$ADRESSE"
verifier "KIT_PHP_VERSION fantaisiste → refus" env KIT_PHP_VERSION='8.3; id' bash -c "! bash '$ROOT/deploiement/alwaysdata/deployer.sh' cible '$COMPTE' '$INSTANCE' '$ADRESSE' >/dev/null 2>&1"

deployer() {
  KIT_SSH="ssh -F $TMP/ssh_config -o BatchMode=yes" KIT_SCP="scp -q -F $TMP/ssh_config -o BatchMode=yes" \
  KIT_DB_HOST="$BASE_DB" bash "$ROOT/deploiement/alwaysdata/deployer.sh" cible "$COMPTE" "$INSTANCE" "$ADRESSE"
}

echo "▶ premier déploiement"
if deployer > "$JOURNAL.1" 2>&1; then ok "deployer.sh sort en 0"; else ko "deployer.sh (premier passage)"; cat "$JOURNAL.1"; fi
sed 's/^/    | /' "$JOURNAL.1"
V1="$(sur_cible "basename \$(readlink $DOSSIER/courant)")"
verifier "configuration créée au premier passage" grep -q 'configuration créée' "$JOURNAL.1"
verifier "les trois migrations sont jouées, par bin/migrate.php" grep -q 'migrations : 3 appliquée(s)' "$JOURNAL.1"
verifier "configuration de l'instance : droits 600, hors de la racine du site" sur_cible "test \"\$(stat -c %a $DOSSIER/config.php)\" = 600 && test \"\$(stat -c %a $DOSSIER/.dbpass)\" = 600"
verifier "la configuration ferme l'inscription et vise l'adaptateur de référence" sur_cible "grep -q \"'registration' => 'closed'\" $DOSSIER/config.php && grep -q \"'http' => 'apiplatform'\" $DOSSIER/config.php"
verifier "vendor/ est arrivé par l'archive (le serveur n'a pas Composer)" sur_cible "test -f $DOSSIER/courant/vendor/autoload.php"
verifier "aucune dépendance de développement ni configuration locale n'est partie" sur_cible "test ! -e $DOSSIER/courant/harness && test ! -e $DOSSIER/courant/tests && test -L $DOSSIER/courant/src/config.php"
verifier "cache du noyau préchauffé sur le poste : rien n'a été compilé sur le serveur" sur_cible "test -n \"\$(find $DOSSIER/courant/var/cache -name '*KernelProdContainer.php')\" && test -z \"\$(find $DOSSIER/courant/var/cache -path '*Container*' -newer $DOSSIER/courant/src/config.php)\""
verifier "journaux, sessions et compteurs dans var/ de l'instance (pas dans /tmp)" sur_cible "test -d $DOSSIER/var/log && test -d $DOSSIER/var/sessions && test -z \"\$(ls /tmp | grep -i -E 'todo|kit|symfony' || true)\""
verifier "les migrations sont jouées AVANT la bascule du lien" bash -c "test \"\$(grep -n 'migrations :' '$JOURNAL.1' | cut -d: -f1)\" -lt \"\$(grep -n 'bascule faite' '$JOURNAL.1' | cut -d: -f1)\""
verifier "rien du poste n'est figé dans le cache compilé (ni dossier ni secret du préchauffage)" sur_cible "! grep -rqE \"kit-warmup|'warmup'\" $DOSSIER/courant/var/cache"
verifier "aucun fichier caché du kit n'est parti dans la version (hors public/.htaccess ; vendor/ et le cache à part)" sur_cible "test -z \"\$(find $DOSSIER/courant/ -name '.*' ! -name .htaccess ! -path '*/vendor/*' ! -path '*/var/*')\""
verifier "sonde de santé : version $V1" bash -c "curl -s '$ADRESSE/api/health' | grep -q '\"version\":\"$V1\"'"
SECRET_NOYAU="$(racine_cible "sed -n \"s/.*'secret' => '\\([0-9a-f]*\\)'.*/\\1/p\" $DOSSIER/config.php")"
MDP_BASE="$(racine_cible "cat $DOSSIER/.dbpass")"
verifier "le secret du noyau a été tiré sur le serveur (64 hexadécimaux)" test "${#SECRET_NOYAU}" = 64
if grep -qF -e "$SECRET_NOYAU" -e "$MDP_BASE" "$JOURNAL.1"; then ko "un secret figure dans la sortie de deployer.sh"; else ok "aucun secret dans la sortie de deployer.sh"; fi
SOMME_CONFIG="$(racine_cible "sha256sum $DOSSIER/config.php | cut -d' ' -f1")"

echo "▶ comptes du smoke et données, par commandes courtes en SSH"
A_EMAIL=a@exemple.test; B_EMAIL=b@exemple.test
A_PASS="$(openssl rand -hex 16)"; B_PASS="$(openssl rand -hex 16)"
printf '%s\n' "$A_PASS" | par_ssh "cd $DOSSIER/courant && php bin/account.php create $A_EMAIL" >/dev/null && \
printf '%s\n' "$B_PASS" | par_ssh "cd $DOSSIER/courant && php bin/account.php create $B_EMAIL" >/dev/null && ok "deux comptes créés par php bin/account.php create (mot de passe sur l'entrée standard)" || ko "création des comptes"
jeton() { par_ssh "cd $DOSSIER/courant && php bin/account.php token $1" 2>/dev/null; }
printf 'Authorization: Bearer %s' "$(jeton "$A_EMAIL")" > "$TMP/temoin.hdr"
TEMOIN="$(curl -s -X POST "$ADRESSE/api/todos" -H "@$TMP/temoin.hdr" -H 'Content-Type: application/json' -d '{"title":"donnée posée avant le second passage"}' | champ id)"
verifier "une donnée témoin est posée" test -n "$TEMOIN"

echo "▶ second déploiement (rejouer ne casse rien)"
sleep 1
if deployer > "$JOURNAL.2" 2>&1; then ok "deployer.sh sort en 0"; else ko "deployer.sh (second passage)"; cat "$JOURNAL.2"; fi
sed 's/^/    | /' "$JOURNAL.2"
V2="$(sur_cible "basename \$(readlink $DOSSIER/courant)")"
verifier "une nouvelle version est servie ($V2)" test "$V2" != "$V1"
verifier "aucune migration rejouée" grep -q 'migrations : 0 appliquée(s)' "$JOURNAL.2"
verifier "configuration gardée" grep -q 'configuration gardée' "$JOURNAL.2"
verifier "configuration inchangée (même somme de contrôle)" test "$(racine_cible "sha256sum $DOSSIER/config.php | cut -d' ' -f1")" = "$SOMME_CONFIG"
verifier "version précédente présente, désignée par le lien « precedent »" sur_cible "test \"\$(readlink $DOSSIER/precedent)\" = versions/$V1 && test -f $DOSSIER/versions/$V1/public/index.php"
verifier "données intactes : la donnée témoin est toujours là" bash -c "curl -s '$ADRESSE/api/todos/$TEMOIN' -H '@$TMP/temoin.hdr' | grep -q 'avant le second passage'"
verifier "les migrations tracées sont toujours trois" test "$(echo "SELECT COUNT(*) FROM $DB.schema_migrations;" | admin_sql | tail -1)" = 3
verifier "le login de l'application n'a aucun privilège global" bash -c "echo \"SHOW GRANTS FOR '$DB'@'%';\" | docker exec -i $BASE_DB sh -c 'exec mariadb -uroot -p\"\$MARIADB_ROOT_PASSWORD\"' | grep 'ON \*\.\*' | grep -q 'GRANT USAGE'"
if grep -qF -e "$SECRET_NOYAU" -e "$MDP_BASE" "$JOURNAL.2"; then ko "un secret figure dans la sortie de deployer.sh"; else ok "aucun secret dans la sortie de deployer.sh"; fi

# toutes_versions <version> : 12 requêtes de suite rendent TOUTES cette version (la cible a 4
# processus PHP : un seul resté sur l'ancien code ferait échouer).
toutes_versions() {
  local i
  for i in $(seq 1 12); do case "$(sante)" in *"\"version\":\"$1\""*) : ;; *) return 1 ;; esac; done
}
verifier "après le déploiement, tous les processus PHP servent $V2 (12 requêtes de suite)" toutes_versions "$V2"

echo "▶ retour arrière : le lien « courant » revient sur la version précédente, puis repart"
par_ssh "cd $DOSSIER && ln -sfn \"\$(readlink precedent)\" courant.nouveau && mv -T courant.nouveau courant"
verifier "retour arrière vu AUSSITÔT par tous les processus PHP ($V1, 12 requêtes de suite, sans redémarrer PHP)" toutes_versions "$V1"
par_ssh "cd $DOSSIER && ln -sfn versions/$V2 courant.nouveau && mv -T courant.nouveau courant"
verifier "bascule inverse vue aussitôt par tous les processus PHP ($V2, 12 requêtes de suite)" toutes_versions "$V2"

echo "▶ ce que PHP reçoit du serveur ($MONTAGE)"
# (La bascule vue aussitôt par tous les processus, ci-dessus, prouve aussi que SCRIPT_FILENAME
# arrive NON résolu : sinon public/index.php ne pourrait pas relire le lien « courant ».)
verifier "l'en-tête Authorization arrive à PHP par la réécriture du .htaccess (jeton porteur accepté)" test "$(curl -s -o /dev/null -w '%{http_code}' "$ADRESSE/api/me" -H "@$TMP/temoin.hdr")" = 200
verifier "… et il est bien exigé (sans lui : 401)" test "$(curl -s -o /dev/null -w '%{http_code}' "$ADRESSE/api/me")" = 401

echo "▶ sans mod_rewrite : le site ne sert rien plutôt que servir à moitié"
racine_cible "a2dismod -f rewrite >/dev/null && apache2ctl graceful" && sleep 2
for chemin in / /index.php /api/health /src/config.php /todos-island/index.js; do
  verifier "sans mod_rewrite : GET $chemin → 503" test "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$ADRESSE$chemin")" = 503
done
racine_cible "a2enmod rewrite >/dev/null && apache2ctl graceful" && sleep 2
if attendre_sante '"status":"ok"'; then ok "mod_rewrite revenu : la sonde de santé repasse à 200"; else ko "la sonde ne repasse pas à 200"; fi

echo "▶ smokes e2e contre l'adresse de la cible, pour chaque combinaison (la configuration de l'instance choisit)"
declare -A RESULTAT
for http in apiplatform vanilla; do
  for persistence in cqrs doctrine; do
    par_ssh "sed -i \"s/'http' => '[a-z]*'/'http' => '$http'/; s/'persistence' => '[a-z]*'/'persistence' => '$persistence'/\" $DOSSIER/config.php"
    if ! attendre_sante "\"http\":\"$http\",\"persistence\":\"$persistence\""; then
      ko "$http × $persistence : la sonde de santé n'annonce pas cette combinaison"; RESULTAT["$http/$persistence"]="🔴"; continue
    fi
    if [ "$http" = apiplatform ]; then
      E2E_BASE_URL="$ADRESSE" E2E_EXPECT_PERSISTENCE="$persistence" E2E_A_EMAIL="$A_EMAIL" E2E_A_PASSWORD="$A_PASS" \
        E2E_B_EMAIL="$B_EMAIL" E2E_B_PASSWORD="$B_PASS" bash "$ROOT/harness/e2e-apiplatform.sh" > "$TMP/smoke.log" 2>&1 && r=0 || r=$?
    else
      E2E_BASE_URL="$ADRESSE" E2E_EXPECT_PERSISTENCE="$persistence" E2E_A_TOKEN="$(jeton "$A_EMAIL")" E2E_B_TOKEN="$(jeton "$B_EMAIL")" \
        bash "$ROOT/harness/e2e-smoke.sh" > "$TMP/smoke.log" 2>&1 && r=0 || r=$?
    fi
    n="$(grep -c '✓' "$TMP/smoke.log" || true)"
    if [ "$r" = 0 ]; then ok "$http × $persistence : smoke vert ($n vérifications)"; RESULTAT["$http/$persistence"]="🟢 ($n)"
    else grep -E '✗' "$TMP/smoke.log" | sed 's/^/    /'; ko "$http × $persistence : smoke rouge"; RESULTAT["$http/$persistence"]="🔴"; fi
  done
done
par_ssh "sed -i \"s/'http' => '[a-z]*'/'http' => 'apiplatform'/; s/'persistence' => '[a-z]*'/'persistence' => 'cqrs'/\" $DOSSIER/config.php"
attendre_sante '"http":"apiplatform","persistence":"cqrs"' || ko "retour à la combinaison de référence"
# Le profil public (celui qu'on joue contre un hébergeur réel) est prouvé ici, sans pause.
E2E_PROFIL=public E2E_PAUSE=0 E2E_BASE_URL="$ADRESSE" E2E_EXPECT_PERSISTENCE=cqrs E2E_A_EMAIL="$A_EMAIL" E2E_A_PASSWORD="$A_PASS" \
  E2E_B_EMAIL="$B_EMAIL" E2E_B_PASSWORD="$B_PASS" bash "$ROOT/harness/e2e-apiplatform.sh" > "$TMP/smoke-public.log" 2>&1 && r=0 || r=$?
if [ "$r" = 0 ]; then ok "profil public du smoke : vert ($(grep -c '✓' "$TMP/smoke-public.log" || true) vérifications)"
else grep -E '✗' "$TMP/smoke-public.log" | sed 's/^/    /'; ko "profil public du smoke : rouge"; fi
verifier "le smoke a nettoyé derrière lui : seule la donnée témoin reste" test "$(echo "SELECT COUNT(*) FROM $DB.todos;" | admin_sql | tail -1)" = 1

echo "▶ @security — base injoignable : 503 générique, sans trace ni identifiant"
docker stop "$BASE_DB" >/dev/null
for chemin in /api/health /api/todos; do
  c="$(curl -s -o "$TMP/503" -w '%{http_code}' --max-time 30 "$ADRESSE$chemin" -H "@$TMP/temoin.hdr")"
  if [ "$c" = 503 ] && grep -q '"status":503' "$TMP/503" && ! grep -qiE "SQLSTATE|PDO|$BASE_DB|$DB|refused|getaddrinfo|stack|trace|\.php|#[0-9]" "$TMP/503"; then
    ok "base arrêtée : GET $chemin → 503 générique"
  else
    ko "base arrêtée : GET $chemin → $c $(head -c 200 "$TMP/503")"
  fi
done
racine_cible "cat $DOSSIER/var/log/* 2>/dev/null" > "$TMP/journal-panne" || true
if grep -qE "SQLSTATE\[|$BASE_DB|'$DB'|getaddrinfo" "$TMP/journal-panne"; then ko "le journal du noyau porte le message de la panne de base (hôte ou identifiant)"; else ok "le journal du noyau ne porte ni hôte ni identifiant de la base pendant la panne"; fi
docker start "$BASE_DB" >/dev/null
if attendre_sante '"status":"ok"'; then ok "base revenue : la sonde de santé repasse à 200"; else ko "la sonde ne repasse pas à 200"; fi

echo "▶ @security — aucun secret en clair dans les journaux ni dans la base de la cible"
racine_cible "cat $DOSSIER/var/log/* /var/log/apache2/*.log /var/log/php-fpm.log 2>/dev/null" > "$TMP/journaux" || true
printf 'SELECT * FROM %s.accounts; SELECT * FROM %s.access_tokens;\n' "$DB" "$DB" | admin_sql > "$TMP/tables"
if grep -qF -e "$A_PASS" -e "$B_PASS" -e "$SECRET_NOYAU" -e "$MDP_BASE" "$TMP/journaux" "$TMP/tables" || grep -q 'kit_[A-Za-z0-9_-]\{40,\}' "$TMP/journaux" "$TMP/tables"; then
  ko "un mot de passe, un jeton ou un secret figure en clair"
else
  ok "ni mot de passe, ni jeton, ni secret dans les journaux du noyau, d'Apache, de PHP, ni dans les tables"
fi
verifier "les mots de passe en base sont des hachages bcrypt" test "$(printf 'SELECT COUNT(*) FROM %s.accounts WHERE password_hash NOT LIKE "$2y$%%";\n' "$DB" | admin_sql | tail -1)" = 0
verifier "le fuseau de la cible (Europe/Paris) ne décale pas les dates : elles sortent en UTC" bash -c "curl -s '$ADRESSE/api/todos/$TEMOIN' -H '@$TMP/temoin.hdr' | grep -q '\"createdAt\":\"[0-9T:-]*+00:00\"'"

echo ""
echo "Combinaisons prouvées par la répétition locale du $(date -u +%Y-%m-%d) — cible PHP $(sur_cible 'php -r "echo PHP_VERSION;"'), $MONTAGE, $VERSION_BASE"
echo "| Adaptateur HTTP | Persistance | Smoke e2e contre l'adresse de la cible |"
echo "|---|---|---|"
for http in apiplatform vanilla; do for persistence in cqrs doctrine; do
  echo "| $http | $persistence | ${RESULTAT["$http/$persistence"]:-non joué} |"
done; done
echo "| (gate integration, CQRS et Doctrine, login sans privilège) | MariaDB | $INTEG_MARIADB |"
echo "Répétition locale ; non prouvé chez l'hébergeur."
echo ""
if [ "$fail" = 0 ]; then echo "deploiement (répétition locale): 🟢"; else echo "deploiement (répétition locale): 🔴"; fi
exit "$fail"
