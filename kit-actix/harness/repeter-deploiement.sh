#!/usr/bin/env bash
# Gate `deploiement` — RÉPÉTITION LOCALE du déploiement sur hébergement infogéré.
#
# Monte une cible jetable qui ressemble à l'hébergeur (Debian 12, compte sans privilège joignable
# par SSH, aucun compilateur ; base PostgreSQL à login sans privilège), y joue le VRAI script
# deploiement/alwaysdata/deployer.sh deux fois, lance le site comme le fait la plateforme (adresse
# IPv6 et port fournis par IP et PORT), et rejoue le smoke e2e contre son adresse, pour chaque
# adaptateur de persistance. Ce gate ne prouve pas l'hébergeur lui-même : il prouve que le kit et
# son script tiennent leurs promesses avant d'y aller.
set -Eeuo pipefail
# Le gate ne meurt jamais sans dire où.
trap 'echo "✗ arrêt inattendu ligne $LINENO : $BASH_COMMAND" >&2' ERR
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres

CIBLE=kit-actix-cible
COMPTE=repet; INSTANCE=kit; BASE_DB="${COMPTE}_${INSTANCE}"
DOSSIER="/home/$COMPTE/$INSTANCE"
PORT_SSH=12222; PORT_SITE=18090
ADRESSE="http://[::1]:$PORT_SITE"
TMP="$(mktemp -d)"

fail=0
ok() { echo "  ✓ $1"; }
ko() { echo "  ✗ $1"; fail=1; }
verifier() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
sur_cible() { docker exec -u "$COMPTE" "$CIBLE" sh -c "$1"; }
sql() { docker exec todo-postgres psql -U "$BASE_DB" -d "$BASE_DB" -tAc "$1"; }
admin() { docker exec -i todo-postgres psql -U todo -d todo -q -v ON_ERROR_STOP=1 >/dev/null 2>&1; }

nettoyer() {
  docker rm -f "$CIBLE" >/dev/null 2>&1 || true
  printf 'DROP DATABASE IF EXISTS %s WITH (FORCE);\nDROP ROLE IF EXISTS %s;\n' "$BASE_DB" "$BASE_DB" | admin || true
  rm -rf "$TMP"
}
trap nettoyer EXIT

echo "▶ cible jetable (Debian 12, sshd, compte « $COMPTE » sans privilège)"
docker image inspect todo-kit-cible:local >/dev/null 2>&1 || docker build -q -t todo-kit-cible:local "$ROOT/harness/cible" >/dev/null
docker rm -f "$CIBLE" >/dev/null 2>&1 || true
docker run -d --name "$CIBLE" --network host todo-kit-cible:local >/dev/null
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
for _ in $(seq 1 30); do ssh -F "$TMP/ssh_config" -o BatchMode=yes cible true 2>/dev/null && break; sleep 0.5; done

echo "▶ base gérée : login « $BASE_DB » sans privilège, base vide ; mot de passe tiré sur la cible"
# Ce que le porteur fait dans l'administration de l'hébergeur. Le mot de passe naît sur la cible
# et n'est jamais affiché : il passe d'un conteneur à l'autre par un tube.
sur_cible "umask 077; mkdir -p $DOSSIER; head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > $DOSSIER/.pgpass.gen"
{
  printf 'DROP DATABASE IF EXISTS %s WITH (FORCE);\nDROP ROLE IF EXISTS %s;\n' "$BASE_DB" "$BASE_DB"
  printf "CREATE ROLE %s LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '%s';\n" "$BASE_DB" "$(sur_cible "cat $DOSSIER/.pgpass.gen")"
  printf 'CREATE DATABASE %s OWNER %s;\n' "$BASE_DB" "$BASE_DB"
} | admin
motdepasse="$(sur_cible "cat $DOSSIER/.pgpass.gen")"  # gardé en mémoire pour vérifier qu'il ne fuit pas

# La plateforme : elle arrête le programme par SIGTERM et le relance avec IP et PORT.
redemarrer_site() {
  docker exec "$CIBLE" pkill -TERM -u "$COMPTE" -x server 2>/dev/null || true
  for _ in $(seq 1 20); do docker exec "$CIBLE" pgrep -u "$COMPTE" -x server >/dev/null 2>&1 || break; sleep 0.25; done
  docker exec -d -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" \
    sh -c "exec $DOSSIER/lancer.sh >> /home/$COMPTE/site.log 2>&1"
}
export -f redemarrer_site
export CIBLE COMPTE PORT_SITE DOSSIER

deployer() {
  KIT_SSH="ssh -F $TMP/ssh_config -o BatchMode=yes" KIT_SCP="scp -q -F $TMP/ssh_config -o BatchMode=yes" \
  KIT_DB_HOTE=127.0.0.1 KIT_DB_PORT="$KIT_PG_PORT" KIT_REDEMARRAGE=redemarrer_site \
    bash "$ROOT/deploiement/alwaysdata/deployer.sh" cible "$COMPTE" "$INSTANCE" "$ADRESSE"
}
smoke() { E2E_BASE_URL="$ADRESSE" bash "$ROOT/harness/e2e-smoke.sh"; }

echo ""; echo "▶ premier déploiement"
deployer > "$TMP/deploiement-1.log" 2>&1 || { cat "$TMP/deploiement-1.log"; ko "le premier déploiement échoue"; exit 1; }
sed 's/^/    /' "$TMP/deploiement-1.log" | grep -E '^    [1-4]/4|\.env|site redémarré' || true
verifier "le site répond en IPv6 sur l'adresse et le port fournis par la plateforme" "curl -sf --max-time 10 '$ADRESSE/api/todos' >/dev/null"
verifier "le lanceur a été remplacé par le serveur (exec) : aucun processus lancer.sh ne reste" "! docker exec '$CIBLE' pgrep -u '$COMPTE' -f lancer.sh >/dev/null"
verifier ".env créé sur la cible, droits 600" "[ \"\$(sur_cible 'stat -c %a $DOSSIER/.env')\" = 600 ]"
verifier ".pgpass.gen supprimé une fois .env écrit" "sur_cible '[ ! -e $DOSSIER/.pgpass.gen ]'"
verifier "aucun compilateur sur la cible (le serveur ne compile rien)" "! sur_cible 'command -v cargo rustc cc gcc' >/dev/null"
verifier "le login de la base est sans privilège" "[ \"\$(sql \"SELECT rolsuper OR rolbypassrls OR rolcreaterole FROM pg_roles WHERE rolname = current_user\")\" = f ]"
echo "  smoke e2e, persistance cqrs :"
smoke | sed 's/^/  /' || ko "smoke cqrs après le premier déploiement"

# Une donnée témoin et l'état des migrations, pour le second passage.
temoin=$(curl -s -X POST "$ADRESSE/api/todos" -H 'Content-Type: application/json' -d '{"title":"donnée témoin"}' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
migrations_avant="$(sql 'SELECT version, installed_on FROM _sqlx_migrations ORDER BY version')"
env_avant="$(sur_cible "sha256sum $DOSSIER/.env")"

echo ""; echo "▶ second déploiement (rejouer ne casse rien)"
deployer > "$TMP/deploiement-2.log" 2>&1 || { cat "$TMP/deploiement-2.log"; ko "le second déploiement échoue"; }
verifier "aucune migration rejouée (versions et dates inchangées)" "[ \"\$(sql 'SELECT version, installed_on FROM _sqlx_migrations ORDER BY version')\" = \"\$migrations_avant\" ]"
verifier "au moins une migration tracée" "[ -n \"\$migrations_avant\" ]"
verifier "les données sont intactes (la donnée témoin est toujours là)" "curl -s '$ADRESSE/api/todos' | grep -q '\"id\":\"$temoin\"'"
verifier ".env inchangé (jamais réécrit)" "[ \"\$(sur_cible 'sha256sum $DOSSIER/.env')\" = \"\$env_avant\" ]"
verifier "la version précédente du binaire est sur la cible" "sur_cible '[ -x $DOSSIER/server.precedent ] && [ -x $DOSSIER/migrate.precedent ] && [ -d $DOSSIER/public.precedent ]'"
verifier "le témoin .migrer a été consommé" "sur_cible '[ ! -e $DOSSIER/.migrer ]'"

echo ""; echo "▶ second adaptateur de persistance (sea-orm), choisi dans .env par le porteur"
sur_cible "sed -i 's/^TODO_PERSISTENCE=.*/TODO_PERSISTENCE=orm/' $DOSSIER/.env"
redemarrer_site
for _ in $(seq 1 40); do curl -sf --max-time 5 "$ADRESSE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done
verifier "le serveur annonce la persistance orm dans son journal" "sur_cible 'tail -n 3 /home/$COMPTE/site.log' | grep -q 'persistance orm'"
echo "  smoke e2e, persistance orm :"
smoke | sed 's/^/  /' || ko "smoke orm"
verifier "la donnée témoin, écrite par cqrs, est lue par orm" "curl -s '$ADRESSE/api/todos' | grep -q '\"id\":\"$temoin\"'"
sur_cible "sed -i 's/^TODO_PERSISTENCE=.*/TODO_PERSISTENCE=cqrs/' $DOSSIER/.env"

echo ""; echo "▶ arrêt par la plateforme, puis relance"
docker exec "$CIBLE" pkill -TERM -u "$COMPTE" -x server
for _ in $(seq 1 20); do docker exec "$CIBLE" pgrep -u "$COMPTE" -x server >/dev/null 2>&1 || break; sleep 0.25; done
verifier "SIGTERM arrête le programme" "! docker exec '$CIBLE' pgrep -u '$COMPTE' -x server >/dev/null"
redemarrer_site
for _ in $(seq 1 40); do curl -sf --max-time 5 "$ADRESSE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done
verifier "relancé sans intervention, le site répond et la donnée témoin est là" "curl -s '$ADRESSE/api/todos' | grep -q '\"id\":\"$temoin\"'"
curl -s -o /dev/null -X DELETE "$ADRESSE/api/todos/$temoin"

echo ""; echo "▶ panne de la base : réponse générique, sans trace ni identifiant"
# La base devient injoignable pour ce seul login (le conteneur PostgreSQL est partagé).
printf "ALTER ROLE %s NOLOGIN;\nSELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '%s';\n" "$BASE_DB" "$BASE_DB" | admin
panne="$(curl -s --max-time 20 -w '\n%{http_code}' "$ADRESSE/api/todos")"
printf 'ALTER ROLE %s LOGIN;\n' "$BASE_DB" | admin
verifier "GET /api/todos pendant la panne → 500" "[ \"\$(printf '%s' \"\$panne\" | tail -n1)\" = 500 ]"
verifier "corps générique : ni nom du login, ni message du pilote, ni adresse de la base" "! printf '%s' \"\$panne\" | grep -qiE '$BASE_DB|sqlx|postgres|password|FATAL|127\.0\.0\.1'"
for _ in $(seq 1 20); do curl -sf --max-time 5 "$ADRESSE/api/todos" >/dev/null 2>&1 && break; sleep 0.5; done
verifier "la base revenue, le site répond de nouveau sans redémarrage" "curl -sf --max-time 5 '$ADRESSE/api/todos' >/dev/null"

echo ""; echo "▶ lanceur sans fichier d'environnement"
docker exec "$CIBLE" pkill -TERM -u "$COMPTE" -x server || true
sur_cible "mv $DOSSIER/.env $DOSSIER/.env.de-cote"
# Échec attendu : dans une liste `&& ||`, il ne déclenche ni `set -e` ni le piège ERR.
sortie="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" "$DOSSIER/lancer.sh" 2>&1)" && code=0 || code=$?
sur_cible "mv $DOSSIER/.env.de-cote $DOSSIER/.env"
verifier "le programme refuse de démarrer (code $code)" "[ $code -ne 0 ]"
verifier "son message nomme la variable manquante (DATABASE_URL)" "printf '%s' \"\$sortie\" | grep -q 'DATABASE_URL'"

echo ""; echo "▶ témoin négatif : une migration déjà passée dont la somme a changé est refusée"
somme="$(sql "SELECT encode(checksum, 'hex') FROM _sqlx_migrations WHERE version = 1")"
sql "UPDATE _sqlx_migrations SET checksum = '\\x00' WHERE version = 1" >/dev/null
sur_cible "touch $DOSSIER/.migrer"
refus="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" "$DOSSIER/lancer.sh" 2>&1)" && code_refus=0 || code_refus=$?
sql "UPDATE _sqlx_migrations SET checksum = decode('$somme', 'hex') WHERE version = 1" >/dev/null
verifier "le lanceur s'arrête sur l'échec des migrations (code $code_refus), le serveur ne démarre pas" "[ $code_refus -ne 0 ] && ! docker exec '$CIBLE' pgrep -u '$COMPTE' -x server >/dev/null"
verifier "le message dit que la migration a été modifiée" "printf '%s' \"\$refus\" | grep -qi 'modified'"
verifier "le témoin .migrer reste : l'échec ne se rattrape pas en silence" "sur_cible '[ -e $DOSSIER/.migrer ]'"
sur_cible "rm -f $DOSSIER/.migrer"

echo ""; echo "▶ aucun secret dans les journaux ni dans les sorties du script"
verifier "le mot de passe de la base n'apparaît ni dans le journal du site, ni dans les sorties du déploiement" \
  "! { sur_cible 'cat /home/$COMPTE/site.log'; cat '$TMP/deploiement-1.log' '$TMP/deploiement-2.log'; printf '%s' \"\$sortie\" \"\$refus\" \"\$panne\"; } | grep -qF \"\$motdepasse\""

echo ""
if [ "$fail" = 0 ]; then echo "deploiement (répétition locale, cqrs et orm): 🟢"; else echo "deploiement (répétition locale): 🔴"; fi
exit "$fail"
