#!/usr/bin/env bash
# Gate `deploiement` — RÉPÉTITION LOCALE du déploiement sur hébergement infogéré.
#
# Monte une cible jetable qui ressemble à l'hébergeur (Debian 12, compte sans privilège joignable
# par SSH, aucun compilateur ; base PostgreSQL à login sans privilège), y joue le VRAI script
# deploiement/alwaysdata/deployer.sh deux fois, lance le site comme le fait la plateforme (adresse
# IPv6 et port fournis par IP et PORT), et rejoue le smoke e2e contre son adresse, pour chaque
# adaptateur de persistance. L'API de l'hébergeur est tenue par un faux serveur local
# (harness/faux-hebergeur.py) : le script y crée la base, son utilisateur et le site, et y demande
# les redémarrages ; aucun appel ne part vers l'hébergeur réel. Ce gate ne prouve pas l'hébergeur
# lui-même : il prouve que le kit et son script tiennent leurs promesses avant d'y aller.
set -Eeuo pipefail
unset E2E_PROFIL E2E_PAUSE   # la répétition choisit elle-même le profil du smoke
# Le gate ne meurt jamais sans dire où.
trap 'echo "✗ arrêt inattendu ligne $LINENO : $BASH_COMMAND" >&2' ERR
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image; ensure_postgres

CIBLE=kit-actix-cible
COMPTE=repet; INSTANCE=kit; BASE_DB="${COMPTE}_${INSTANCE}"
DOSSIER="/home/$COMPTE/$INSTANCE"
PORT_SSH=12222; PORT_SITE=18090; PORT_API=18091
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
  [ -z "${PID_API:-}" ] || kill "$PID_API" 2>/dev/null || true
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

# Ce que fait l'hébergeur quand son API crée un login et une base. Le mot de passe arrive par
# l'entrée standard et n'est jamais affiché.
creer_utilisateur() {
  local mdp; mdp="$(cat)"
  case "$1$mdp" in *[!A-Za-z0-9_]*) return 1 ;; esac
  printf "CREATE ROLE %s LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '%s';\n" "$1" "$mdp" | admin
}
creer_base() {
  case "$1" in *[!A-Za-z0-9_]*) return 1 ;; esac
  printf 'CREATE DATABASE %s OWNER %s;\n' "$1" "$1" | admin
}
printf 'DROP DATABASE IF EXISTS %s WITH (FORCE);\nDROP ROLE IF EXISTS %s;\n' "$BASE_DB" "$BASE_DB" | admin

# La plateforme : elle arrête le programme par SIGTERM et le relance avec IP et PORT.
redemarrer_site() {
  docker exec "$CIBLE" pkill -TERM -u "$COMPTE" -x server 2>/dev/null || true
  for _ in $(seq 1 20); do docker exec "$CIBLE" pgrep -u "$COMPTE" -x server >/dev/null 2>&1 || break; sleep 0.25; done
  docker exec -d -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" \
    sh -c "exec $DOSSIER/lancer.sh >> /home/$COMPTE/site.log 2>&1"
}
export -f redemarrer_site creer_utilisateur creer_base admin
export CIBLE COMPTE PORT_SITE DOSSIER

echo "▶ faux serveur de l'API de l'hébergeur (aucun appel ne part vers l'hébergeur réel)"
jeton="jeton-de-repetition-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf 'ALWAYSDATA_TOKEN=%s\n' "$jeton" > "$TMP/env-avec-jeton"; : > "$TMP/env-sans-jeton"; : > "$TMP/api.log"
FAUX_JETON="$jeton" FAUX_COMPTE="$COMPTE" FAUX_PORT="$PORT_API" FAUX_JOURNAL="$TMP/api.log" \
FAUX_CREER_UTILISATEUR=creer_utilisateur FAUX_CREER_BASE=creer_base FAUX_REDEMARRER=redemarrer_site \
  python3 -I "$ROOT/harness/faux-hebergeur.py" & PID_API=$!
for _ in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:$PORT_API/" && break; sleep 0.2; done
: > "$TMP/api.log"   # l'attente ci-dessus n'est pas un appel du script

# Le script ne voit QUE le faux serveur et le jeton de répétition : le jeton réel du projet, s'il
# existe (variable d'environnement ou fichier .env), n'est jamais lu ici.
script() {  # script <deployer|revenir> <fichier d'environnement>
  env -u ALWAYSDATA_TOKEN -u ALWAYSDATA_SITE -u KIT_REDEMARRAGE \
  ALWAYSDATA_API="http://127.0.0.1:$PORT_API/v1" KIT_ENV_FICHIER="$2" KIT_ATTENTE_CERTIFICAT=0 KIT_ATTENTE_PAS=1 \
  KIT_SSH="ssh -F $TMP/ssh_config -o BatchMode=yes" KIT_SCP="scp -q -F $TMP/ssh_config -o BatchMode=yes" \
  KIT_DB_HOTE=127.0.0.1 KIT_DB_PORT="$KIT_PG_PORT" \
    bash "$ROOT/deploiement/alwaysdata/$1.sh" cible "$COMPTE" "$INSTANCE" "$ADRESSE"
}
deployer() { script deployer "$TMP/env-avec-jeton"; }
revenir() { script revenir "$TMP/env-avec-jeton"; }
creations() { grep -cE '^POST /v1/(site|database|database/user)/ ' "$TMP/api.log" || true; }

echo ""; echo "▶ sans jeton d'API, sur une instance jamais préparée : arrêt avant tout envoi"
script deployer "$TMP/env-sans-jeton" > "$TMP/deploiement-0.log" 2>&1 && code0=0 || code0=$?
verifier "le script s'arrête (code $code0)" "[ $code0 -ne 0 ]"
verifier "il dit quoi créer à la main (base, mot de passe, site)" "grep -q 'créer à la main' '$TMP/deploiement-0.log' && grep -q '.pgpass.gen' '$TMP/deploiement-0.log' && grep -q 'un site pour' '$TMP/deploiement-0.log'"
verifier "rien n'a été envoyé sur la cible, aucun appel à l'API" "sur_cible '[ ! -e $DOSSIER ]' && [ ! -s '$TMP/api.log' ]"
smoke() { E2E_BASE_URL="$ADRESSE" bash "$ROOT/harness/e2e-smoke.sh"; }

echo ""; echo "▶ premier déploiement"
deployer > "$TMP/deploiement-1.log" 2>&1 || { cat "$TMP/deploiement-1.log"; ko "le premier déploiement échoue"; exit 1; }
sed 's/^/    /' "$TMP/deploiement-1.log" | grep -E '^    [0-4]/4|création|\.env|site redémarré' || true
motdepasse="$(sur_cible "sed -n 's/^DATABASE_URL=[^:]*:[^:]*:\([^@]*\)@.*/\1/p' $DOSSIER/.env")"  # gardé en mémoire pour vérifier qu'il ne fuit pas
verifier "la base, son utilisateur et le site ont été créés par l'API (3 créations, annoncées avant)" "[ \"\$(creations)\" = 3 ] && [ \"\$(grep -c 'création d' '$TMP/deploiement-1.log')\" = 3 ]"
verifier "le site a été redémarré par l'API, non par une commande locale" "grep -qE '^POST /v1/site/[0-9]+/restart/ 204' '$TMP/api.log'"
verifier "retour arrière sans version précédente : refusé, rien n'est changé" "! revenir > '$TMP/revenir-0.log' 2>&1 && grep -q 'aucune version précédente' '$TMP/revenir-0.log' && curl -sf --max-time 10 '$ADRESSE/api/todos' >/dev/null"
verifier "le site répond en IPv6 sur l'adresse et le port fournis par la plateforme" "curl -sf --max-time 10 '$ADRESSE/api/todos' >/dev/null"
verifier "le lanceur a été remplacé par le serveur (exec) : aucun processus lancer.sh ne reste" "! docker exec '$CIBLE' pgrep -u '$COMPTE' -f lancer.sh >/dev/null"
verifier ".env créé sur la cible, droits 600" "[ \"\$(sur_cible 'stat -c %a $DOSSIER/.env')\" = 600 ]"
verifier ".pgpass.gen supprimé une fois .env écrit" "sur_cible '[ ! -e $DOSSIER/.pgpass.gen ]'"
verifier "aucun compilateur sur la cible (le serveur ne compile rien)" "! sur_cible 'command -v cargo rustc cc gcc' >/dev/null"
verifier "le login de la base est sans privilège" "[ \"\$(sql \"SELECT rolsuper OR rolbypassrls OR rolcreaterole FROM pg_roles WHERE rolname = current_user\")\" = f ]"
echo "  smoke e2e, persistance cqrs :"
smoke | sed 's/^/  /' || ko "smoke cqrs après le premier déploiement"
echo "  smoke e2e, profil public (celui qu'on joue contre un hébergeur réel), sans pause :"
E2E_PROFIL=public E2E_PAUSE=0 smoke | sed 's/^/  /' || ko "smoke, profil public"

# Une donnée témoin et l'état des migrations, pour le second passage.
temoin=$(curl -s -X POST "$ADRESSE/api/todos" -H 'Content-Type: application/json' -d '{"title":"donnée témoin"}' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
migrations_avant="$(sql 'SELECT version, installed_on FROM _sqlx_migrations ORDER BY version')"
env_avant="$(sur_cible "sha256sum $DOSSIER/.env")"

echo ""; echo "▶ second déploiement (rejouer ne casse rien)"
deployer > "$TMP/deploiement-2.log" 2>&1 || { cat "$TMP/deploiement-2.log"; ko "le second déploiement échoue"; }
verifier "rien n'est recréé chez l'hébergeur : toujours 3 créations, aucune de plus" "[ \"\$(creations)\" = 3 ] && ! grep -q 'création d' '$TMP/deploiement-2.log'"
verifier "aucune migration rejouée (versions et dates inchangées)" "[ \"\$(sql 'SELECT version, installed_on FROM _sqlx_migrations ORDER BY version')\" = \"\$migrations_avant\" ]"
verifier "au moins une migration tracée" "[ -n \"\$migrations_avant\" ]"
verifier "les données sont intactes (la donnée témoin est toujours là)" "curl -s '$ADRESSE/api/todos' | grep -q '\"id\":\"$temoin\"'"
verifier ".env inchangé (jamais réécrit)" "[ \"\$(sur_cible 'sha256sum $DOSSIER/.env')\" = \"\$env_avant\" ]"
verifier "la version précédente est sur la cible (binaires, lanceur, front)" "sur_cible '[ -x $DOSSIER/server.precedent ] && [ -x $DOSSIER/migrate.precedent ] && [ -x $DOSSIER/lancer.sh.precedent ] && [ -d $DOSSIER/public.precedent ]'"
verifier "le témoin .migrer a été consommé" "sur_cible '[ ! -e $DOSSIER/.migrer ]'"

echo ""; echo "▶ retour arrière (revenir.sh), puis retour à la version quittée"
# Les deux versions sortent du même code : une marque posée dans le front de la précédente les distingue.
sur_cible "echo version-precedente > $DOSSIER/public.precedent/marque-de-version.txt"
revenir > "$TMP/revenir-1.log" 2>&1 || { cat "$TMP/revenir-1.log"; ko "le retour arrière échoue"; }
verifier "la version précédente est en service (sa marque est servie)" "curl -s --max-time 10 '$ADRESSE/marque-de-version.txt' | grep -qx 'version-precedente'"
verifier "le site répond, la donnée témoin est là, aucune migration jouée ni défaite" "curl -s '$ADRESSE/api/todos' | grep -q '\"id\":\"$temoin\"' && [ \"\$(sql 'SELECT version, installed_on FROM _sqlx_migrations ORDER BY version')\" = \"\$migrations_avant\" ] && sur_cible '[ ! -e $DOSSIER/.migrer ]'"
revenir > "$TMP/revenir-2.log" 2>&1 || { cat "$TMP/revenir-2.log"; ko "le second retour échoue"; }
verifier "rejoué, le script remet la version quittée (la marque n'est plus servie)" "! curl -s --max-time 10 '$ADRESSE/marque-de-version.txt' | grep -qx 'version-precedente' && curl -sf --max-time 10 '$ADRESSE/api/todos' >/dev/null"
verifier "les retours n'ont rien créé chez l'hébergeur" "[ \"\$(creations)\" = 3 ]"

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
verifier "un mot de passe a bien été tiré pour la base (48 caractères)" "[ \${#motdepasse} = 48 ]"
verifier "ni le mot de passe de la base, ni le jeton d'API n'apparaissent dans le journal du site, les sorties des scripts ou le journal de l'API" \
  "! { sur_cible 'cat /home/$COMPTE/site.log'; cat '$TMP'/deploiement-[012].log '$TMP'/revenir-[012].log '$TMP/api.log'; printf '%s' \"\$sortie\" \"\$refus\" \"\$panne\"; } | grep -qF -e \"\$motdepasse\" -e \"\$jeton\""
memes_gestes() {
  local k f
  for k in kit-fastapi kit-php; do
    [ -d "$ROOT/../$k/deploiement/alwaysdata" ] || continue   # un projet dérivé n'a qu'un kit
    for f in deploiement/alwaysdata/hebergeur.sh deploiement/alwaysdata/hebergeur.py harness/faux-hebergeur.py; do
      cmp -s "$ROOT/$f" "$ROOT/../$k/$f" || return 1
    done
  done
}
verifier "les gestes communs sont les mêmes fichiers dans les trois kits" "memes_gestes"

echo ""
if [ "$fail" = 0 ]; then echo "deploiement (répétition locale, cqrs et orm): 🟢"; else echo "deploiement (répétition locale): 🔴"; fi
exit "$fail"
