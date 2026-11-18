#!/usr/bin/env bash
# Gate `deploiement` — RÉPÉTITION LOCALE du déploiement sur hébergement infogéré.
#
# Monte une cible jetable qui ressemble à l'hébergeur (Debian 12, Python 3.12 au chemin où
# l'hébergeur le fournit, uWSGI 2.0.x, compte sans privilège joignable par SSH, aucune dépendance
# du kit ; base PostgreSQL à login sans privilège), y joue le VRAI script
# deploiement/alwaysdata/deployer.sh DEUX fois, lance le site comme le fait la plateforme (adresse
# IPv6 et port fournis par IP et PORT), puis rejoue le smoke e2e contre son adresse pour CHAQUE
# combinaison : montage (A uvicorn, B uWSGI + pont) × adaptateur HTTP × adaptateur de persistance.
# Il essaie aussi les limites du pont ASGI→WSGI et vérifie que le guide dit ce que l'essai montre.
#
# Ce gate ne prouve pas l'hébergeur lui-même : il prouve que le kit et son script tiennent leurs
# promesses avant d'y aller. Il ne se connecte à aucun compte réel (hôte factice, clé jetable).
set -Eeuo pipefail
# Un arrêt hors vérification dit où il a lieu : jamais de sortie muette.
piege() { trap 'echo "✗ arrêt inattendu ligne $LINENO : $BASH_COMMAND" >&2' ERR; }
piege
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_postgres
# Aucun réglage de déploiement réel ne doit fuir dans la répétition.
unset ALWAYSDATA_SITE ALWAYSDATA_TOKEN KIT_DOSSIER KIT_PYTHON E2E_BASE_URL

CIBLE=kit-fastapi-cible
IMAGE_CIBLE=todo-kit-fastapi-cible:local
COMPTE=repet; INSTANCE=kitfastapi; BASE_DB="${COMPTE}_${INSTANCE}"
DOSSIER="/home/$COMPTE/$INSTANCE"
PORT_SSH=12223; PORT_SITE=18091; PORT_SONDE=18092
ADRESSE="http://[::1]:$PORT_SITE"
UWSGI=/usr/alwaysdata/uwsgi/bin/uwsgi
JOURNAL="/home/$COMPTE/site.log"
TMP="$(mktemp -d)"; chmod 700 "$TMP"
MONTAGE=A

fail=0
ok() { echo "  ✓ $1"; }
ko() { echo "  ✗ $1"; fail=1; }
verifier() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
sur_cible() { docker exec -u "$COMPTE" "$CIBLE" sh -c "$1"; }
sql() { docker exec todo-postgres psql -U "$BASE_DB" -d "$BASE_DB" -tAc "$1"; }
admin() { docker exec -i todo-postgres psql -U todo -d todo -q -v ON_ERROR_STOP=1 >/dev/null; }
alea() { head -c "${1:-18}" /dev/urandom | od -An -tx1 | tr -d ' \n'; }

nettoyer() {
  docker rm -f "$CIBLE" >/dev/null 2>&1 || true
  printf 'DROP DATABASE IF EXISTS %s WITH (FORCE);\nDROP ROLE IF EXISTS %s;\n' "$BASE_DB" "$BASE_DB" | admin || true
  rm -rf "$TMP"
}
trap nettoyer EXIT

echo "▶ cible jetable (Debian 12, Python 3.12, uWSGI 2.0.x, sshd, compte « $COMPTE » sans privilège)"
empreinte="$(sha256sum "$ROOT/harness/cible/Dockerfile" | cut -c1-16)"
[ "$(docker image inspect -f '{{ index .Config.Labels "kit.cible" }}' "$IMAGE_CIBLE" 2>/dev/null)" = "$empreinte" ] \
  || docker build -q --label "kit.cible=$empreinte" -t "$IMAGE_CIBLE" "$ROOT/harness/cible" >/dev/null
docker rm -f "$CIBLE" >/dev/null 2>&1 || true
docker run -d --name "$CIBLE" --network host "$IMAGE_CIBLE" >/dev/null
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
SSH_CIBLE=(ssh -F "$TMP/ssh_config" -o BatchMode=yes cible)
for _ in $(seq 1 30); do "${SSH_CIBLE[@]}" true 2>/dev/null && break; sleep 0.5; done
verifier "Python 3.12 au chemin de l'hébergeur, uWSGI 2.0.x" \
  "sur_cible '/usr/alwaysdata/python/3.12/bin/python -V' | grep -q '^Python 3\\.12\\.' && sur_cible '$UWSGI --version' | grep -q '^2\\.0\\.'"
verifier "aucune dépendance du kit sur la cible avant le déploiement (elles arrivent préparées)" \
  "! sur_cible '/usr/alwaysdata/python/3.12/bin/python -c \"import fastapi\"' 2>/dev/null"
verifier "ni compilateur ni en-têtes de développement sur la cible (le serveur ne compile rien)" \
  "! sur_cible 'command -v gcc cc make' >/dev/null"

echo "▶ base gérée : login « $BASE_DB » sans privilège, base vide ; mot de passe tiré sur la cible"
# Ce que le porteur fait dans l'administration de l'hébergeur. Le mot de passe naît sur la cible
# et n'est jamais affiché : il passe d'un conteneur à l'autre par un tube.
sur_cible "umask 077; mkdir -p $DOSSIER; openssl rand -hex 24 > $DOSSIER/.pgpass.gen"
{
  printf 'DROP DATABASE IF EXISTS %s WITH (FORCE);\nDROP ROLE IF EXISTS %s;\n' "$BASE_DB" "$BASE_DB"
  printf "CREATE ROLE %s LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '%s';\n" "$BASE_DB" "$(sur_cible "cat $DOSSIER/.pgpass.gen")"
  printf 'CREATE DATABASE %s OWNER %s;\n' "$BASE_DB" "$BASE_DB"
} | admin
mdp_base="$(sur_cible "cat $DOSSIER/.pgpass.gen")"  # gardé en mémoire pour vérifier qu'il ne fuit pas

# --- La plateforme : elle arrête le programme par SIGTERM et le relance, avec IP et PORT (montage
# A), ou sert wsgi.py par uWSGI (montage B). Les options de uWSGI sont celles de la répétition :
# celles que l'hébergeur passe réellement restent à relever chez lui.
arreter_site() {
  local debut=$SECONDS
  docker exec "$CIBLE" pkill -TERM -u "$COMPTE" -f 'uvicorn|uwsgi' 2>/dev/null || true
  # uWSGI laisse à ses processus jusqu'à `reload-mercy` (60 s par défaut) pour finir : on attend
  # au-delà, et un arrêt de plus de 10 s est SIGNALÉ (il compte dans le délai d'un redéploiement).
  for _ in $(seq 1 300); do
    if ! docker exec "$CIBLE" pgrep -u "$COMPTE" -f 'uvicorn|uwsgi' >/dev/null 2>&1; then
      [ $((SECONDS - debut)) -le 10 ] || echo "  · arrêt lent (montage $MONTAGE) : $((SECONDS - debut)) s après SIGTERM" >&2
      return 0
    fi
    sleep 0.25
  done
  return 1
}
demarrer_site() {
  if [ "$MONTAGE" = A ]; then
    docker exec -d -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" \
      sh -c "exec $DOSSIER/lancer.sh >> $JOURNAL 2>&1"
  else
    docker exec -d -u "$COMPTE" -w "$DOSSIER" "$CIBLE" \
      sh -c "exec $UWSGI --http-socket '[::1]:$PORT_SITE' --chdir $DOSSIER --wsgi-file $DOSSIER/wsgi.py --master --processes 2 --threads 4 --enable-threads --need-app --die-on-term ${UWSGI_PLUS:-} >> $JOURNAL 2>&1"
  fi
}
attendre_sante() { for _ in $(seq 1 80); do curl -sf --max-time 5 "$ADRESSE/api/health" >/dev/null 2>&1 && return 0; sleep 0.5; done; return 1; }
# Si le programme n'a pas rendu la main à temps, la plateforme le tue : on le dit, sans le cacher.
redemarrer_site() {
  if ! arreter_site; then
    echo "  ! arrêt par SIGTERM trop lent (montage $MONTAGE) : SIGKILL" >&2
    docker exec "$CIBLE" pkill -KILL -u "$COMPTE" -f 'uvicorn|uwsgi' 2>/dev/null || true
    sleep 1
  fi
  demarrer_site
}
export -f redemarrer_site arreter_site demarrer_site piege
UWSGI_PLUS=""
export CIBLE COMPTE PORT_SITE DOSSIER MONTAGE UWSGI JOURNAL UWSGI_PLUS

deployer() {
  KIT_SSH="ssh -F $TMP/ssh_config -o BatchMode=yes" KIT_SCP="scp -q -F $TMP/ssh_config -o BatchMode=yes" \
  KIT_DB_HOTE=127.0.0.1 KIT_DB_PORT="$KIT_PG_PORT" KIT_REDEMARRAGE=redemarrer_site \
    bash "$ROOT/deploiement/alwaysdata/deployer.sh" cible "$COMPTE" "$INSTANCE" "$ADRESSE"
}
EMAIL_A="a-$(alea 4)@exemple.test"; MDP_A="$(alea)"; EMAIL_B="b-$(alea 4)@exemple.test"; MDP_B="$(alea)"
smoke() {
  E2E_BASE_URL="$ADRESSE" E2E_EMAIL_A="$EMAIL_A" E2E_PASSWORD_A="$MDP_A" \
  E2E_EMAIL_B="$EMAIL_B" E2E_PASSWORD_B="$MDP_B" bash "$ROOT/harness/e2e-smoke.sh"
}
# Le témoin de migration porte l'identifiant de la version à laquelle il s'adresse.
poser_temoin() { sur_cible "basename \"\$(readlink $DOSSIER/courant)\" > $DOSSIER/${1:-.migrer}"; }
sans_temoin() { sur_cible "[ -z \"\$(ls -A $DOSSIER | grep migrer)\" ]"; }
migrations() { sql 'SELECT version, checksum, applied_at FROM schema_migrations ORDER BY version'; }

echo ""; echo "▶ premier déploiement (montage A : programme utilisateur, uvicorn)"
deployer > "$TMP/deploiement-1.log" 2>&1 || { cat "$TMP/deploiement-1.log"; ko "le premier déploiement échoue"; exit 1; }
grep -E '^[1-4]/4|\.env|version |site redémarré|livraison' "$TMP/deploiement-1.log" | sed 's/^/    /' || true
verifier "le site répond en IPv6 sur l'adresse et le port fournis par la plateforme" "attendre_sante"
verifier "le lanceur a été remplacé par uvicorn (exec) : aucun processus lancer.sh ne reste" \
  "! docker exec '$CIBLE' pgrep -u '$COMPTE' -f lancer.sh >/dev/null && docker exec '$CIBLE' pgrep -u '$COMPTE' -f 'python -m uvicorn' >/dev/null"
verifier "le programme tourne avec le Python 3.12 fourni par l'hébergeur" \
  "docker exec '$CIBLE' pgrep -u '$COMPTE' -af uvicorn | grep -q '^[0-9]* /usr/alwaysdata/python/3.12/bin/python'"
verifier ".env créé sur la cible, droits 600" "[ \"\$(sur_cible 'stat -c %a $DOSSIER/.env')\" = 600 ]"
verifier ".pgpass.gen supprimé une fois .env écrit" "sur_cible '[ ! -e $DOSSIER/.pgpass.gen ]'"
cle_instance="$(sur_cible "grep '^TODO_SECRET_KEY=' $DOSSIER/.env | cut -d\"'\" -f2")"  # gardée en mémoire, jamais affichée
verifier ".env : clé d'instance de 64 caractères, tirée sur la cible" "[[ \"\$cle_instance\" =~ ^[0-9a-f]{64}\$ ]]"
verifier ".env : inscription fermée" "sur_cible \"grep -q '^TODO_REGISTRATION=.closed.\\$' $DOSSIER/.env\""
verifier "le login de la base est sans privilège" \
  "[ \"\$(sql \"SELECT rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb FROM pg_roles WHERE rolname = current_user\")\" = f ]"
verifier "les migrations ont été jouées par le lanceur, le témoin .migrer est consommé" \
  "[ \"\$(sql 'SELECT COUNT(*) FROM schema_migrations')\" = 2 ] && sur_cible '[ ! -e $DOSSIER/.migrer ]'"

echo "▶ comptes du smoke : créés sur la cible par la commande du kit (mot de passe sur l'entrée standard)"
printf '%s\n' "$MDP_A" | "${SSH_CIBLE[@]}" "$DOSSIER/lancer.sh outil app.accounts create $EMAIL_A" | sed 's/^/    /'
printf '%s\n' "$MDP_B" | "${SSH_CIBLE[@]}" "$DOSSIER/lancer.sh outil app.accounts create $EMAIL_B" | sed 's/^/    /'
verifier "deux comptes en base, mots de passe hachés en Argon2id" \
  "[ \"\$(sql \"SELECT COUNT(*) FROM accounts WHERE password_hash LIKE '\\\$argon2id\\\$%'\")\" = 2 ]"
verifier "la commande refuse un second compte au même courriel" \
  "! printf '%s\n' \"\$MDP_A\" | \"\${SSH_CIBLE[@]}\" '$DOSSIER/lancer.sh outil app.accounts create $EMAIL_A' >/dev/null 2>&1"

# Depuis un terminal, sans entrée standard : le mot de passe est tiré et affiché une seule fois.
sortie_tire="$(docker exec -t -u "$COMPTE" "$CIBLE" "$DOSSIER/lancer.sh" outil app.accounts create "c-$(alea 4)@exemple.test" | tr -d '\r')"
MDP_C="$(printf '%s\n' "$sortie_tire" | sed -n 's/^mot de passe (affiché cette seule fois) : //p')"
verifier "depuis un terminal : mot de passe tiré (24 caractères au moins), affiché une fois, compte créé" \
  "[ \"\${#MDP_C}\" -ge 24 ] && [ \"\$(sql 'SELECT COUNT(*) FROM accounts')\" = 3 ]"

# Une combinaison = un montage, un adaptateur HTTP, un adaptateur de persistance. Le porteur
# choisit les adaptateurs en modifiant deux lignes non secrètes de .env, puis redémarre le site.
declare -A RESULTAT
combinaison() {  # $1 montage, $2 http, $3 persistance
  MONTAGE="$1"; export MONTAGE
  sur_cible "sed -i -e \"s/^TODO_HTTP=.*/TODO_HTTP='$2'/\" -e \"s/^TODO_PERSISTENCE=.*/TODO_PERSISTENCE='$3'/\" $DOSSIER/.env"
  redemarrer_site
  local cle="$1/$2/$3"
  if ! attendre_sante; then
    ko "combinaison $cle : le site ne répond pas"; RESULTAT[$cle]="🔴"
    sur_cible "tail -n 15 $JOURNAL" | sed 's/^/      /'
    return 0
  fi
  if smoke > "$TMP/smoke.log" 2>&1; then
    ok "combinaison $cle : smoke e2e vert ($(grep -c '✓' "$TMP/smoke.log") vérifications)"; RESULTAT[$cle]="🟢"
  else
    ko "combinaison $cle : smoke e2e rouge"; RESULTAT[$cle]="🔴"
    grep -E '✗|🔴' "$TMP/smoke.log" | sed 's/^/      /' || true
  fi
}

echo ""; echo "▶ smoke e2e après le premier déploiement"
combinaison A fastapi cqrs

# Une donnée témoin (un todo du compte A), l'état des migrations et celui de .env, pour le second passage.
printf '{"email":"%s","password":"%s"}' "$EMAIL_A" "$MDP_A" > "$TMP/a.json"
jeton=$(curl -s --max-time 20 -X POST "$ADRESSE/api/auth/token" -H 'Content-Type: application/json' --data-binary "@$TMP/a.json" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
printf 'Authorization: Bearer %s\n' "$jeton" > "$TMP/a.h"
temoin=$(curl -s --max-time 20 -X POST "$ADRESSE/api/todos" -H "@$TMP/a.h" -H 'Content-Type: application/json' -d '{"title":"donnée témoin"}' \
  | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
temoin_la() { [ -n "$temoin" ] && curl -s --max-time 20 -H "@$TMP/a.h" "$ADRESSE/api/todos/$temoin" | grep -q '"title":"donnée témoin"'; }
verifier "donnée témoin créée par le compte A" "temoin_la"
migrations_avant="$(migrations)"
env_avant="$(sur_cible "sha256sum $DOSSIER/.env")"
version_avant="$(sur_cible "readlink $DOSSIER/courant")"

echo ""; echo "▶ second déploiement (rejouer ne casse rien)"
sleep 1  # l'identifiant d'une version porte la seconde de son arrivée
deployer > "$TMP/deploiement-2.log" 2>&1 || { cat "$TMP/deploiement-2.log"; ko "le second déploiement échoue"; }
grep -E '\.env|version |site redémarré' "$TMP/deploiement-2.log" | sed 's/^/    /' || true
verifier "au moins une migration tracée" "[ -n \"\$migrations_avant\" ]"
verifier "aucune migration rejouée (versions, sommes et dates inchangées)" "[ \"\$(migrations)\" = \"\$migrations_avant\" ]"
verifier "les données sont intactes (la donnée témoin est toujours là, le jeton de A vaut toujours)" "temoin_la"
verifier ".env inchangé (jamais réécrit)" "[ \"\$(sur_cible 'sha256sum $DOSSIER/.env')\" = \"\$env_avant\" ]"
verifier "la version précédente est sur la cible, entière (lien precedent → l'ancienne version, avec son lanceur et son wsgi.py)" \
  "[ \"\$(sur_cible 'readlink $DOSSIER/precedent')\" = \"\$version_avant\" ] && sur_cible '[ -d $DOSSIER/precedent/app ] && [ -x $DOSSIER/precedent/lancer.sh ] && [ -f $DOSSIER/precedent/wsgi.py ]'"
verifier "les points d'entrée du site sont des liens vers la version courante : ils basculent avec le code" \
  "[ \"\$(sur_cible 'readlink $DOSSIER/lancer.sh')\" = courant/lancer.sh ] && [ \"\$(sur_cible 'readlink $DOSSIER/wsgi.py')\" = courant/wsgi.py ]"
verifier "la version courante a changé, deux versions gardées en tout" \
  "[ \"\$(sur_cible 'readlink $DOSSIER/courant')\" != \"\$version_avant\" ] && [ \"\$(sur_cible 'ls $DOSSIER/versions | wc -l')\" = 2 ]"
verifier "le témoin .migrer a été consommé" "sur_cible '[ ! -e $DOSSIER/.migrer ]'"
verifier "aucun fichier provisoire ne reste (.nouveau)" "! sur_cible 'ls -A $DOSSIER $DOSSIER/versions' | grep -q nouveau"

echo ""; echo "▶ garde-fous du script de déploiement"
set +e; trap - ERR
bash "$ROOT/deploiement/alwaysdata/deployer.sh" "-oProxyCommand=true" "$COMPTE" "$INSTANCE" "$ADRESSE" > "$TMP/hote.log" 2>&1; code_hote=$?
set -e; piege
verifier "un hôte ssh qui commence par un tiret est refusé avant toute commande (code $code_hote)" \
  "[ $code_hote -eq 2 ] && grep -q 'hôte ssh' '$TMP/hote.log'"
# Troisième passage, avec une AUTRE adresse publique et sans redémarrage : .env n'est pas réécrit,
# le script prévient. Un témoin adressé à la nouvelle version est posé ; l'ancienne ne tourne plus.
arreter_site
KIT_SSH="ssh -F $TMP/ssh_config -o BatchMode=yes" KIT_SCP="scp -q -F $TMP/ssh_config -o BatchMode=yes" \
KIT_DB_HOTE=127.0.0.1 KIT_DB_PORT="$KIT_PG_PORT" \
  bash "$ROOT/deploiement/alwaysdata/deployer.sh" cible "$COMPTE" "$INSTANCE" "http://[::1]:18099" > "$TMP/deploiement-3.log" 2>&1 \
  || { cat "$TMP/deploiement-3.log"; ko "le troisième déploiement échoue"; }
verifier "adresse différente de celle de .env : le script prévient, .env reste inchangé" \
  "grep -q 'ATTENTION' '$TMP/deploiement-3.log' && [ \"\$(sur_cible 'sha256sum $DOSSIER/.env')\" = \"\$env_avant\" ]"
verifier "le témoin est posé avec l'identifiant de la nouvelle version" \
  "[ \"\$(sur_cible 'cat $DOSSIER/.migrer')\" = \"\$(sur_cible 'basename \$(readlink $DOSSIER/courant)')\" ]"
# Un témoin adressé à une autre version (le cas d'un réveil de l'ancienne pendant un déploiement).
sur_cible "echo une-autre-version > $DOSSIER/.migrer"
MONTAGE=A; export MONTAGE; demarrer_site
verifier "un témoin adressé à une autre version n'est pas consommé par le lanceur" \
  "attendre_sante && [ \"\$(sur_cible 'cat $DOSSIER/.migrer')\" = une-autre-version ]"
arreter_site
poser_temoin

echo ""; echo "▶ chaque combinaison : montage × adaptateur HTTP × adaptateur de persistance"
for http in fastapi starlette; do for persistance in cqrs orm; do
  combinaison A "$http" "$persistance"
done; done
verifier "montage A : la donnée témoin a traversé tous les adaptateurs" "temoin_la"

# Montage B. Le témoin .migrer est reposé : wsgi.py doit le consommer sans rien rejouer.
arreter_site
verifier "montage A : le témoin adressé à la version courante a été consommé" "sans_temoin"
poser_temoin
for http in fastapi starlette; do for persistance in cqrs orm; do
  combinaison B "$http" "$persistance"
done; done
verifier "montage B : servi par uWSGI (maître et processus de travail), plus aucun uvicorn" \
  "[ \"\$(docker exec '$CIBLE' pgrep -u '$COMPTE' -fc 'uwsgi')\" -ge 3 ] && ! docker exec '$CIBLE' pgrep -u '$COMPTE' -f uvicorn >/dev/null"
verifier "montage B : wsgi.py a consommé le témoin .migrer sans rejouer de migration" \
  "sans_temoin && [ \"\$(migrations)\" = \"\$migrations_avant\" ]"
verifier "montage B : la donnée témoin écrite sous uvicorn est lue sous uWSGI" "temoin_la"

echo ""; echo "▶ arrêt par la plateforme, puis relance (les deux montages)"
for m in B A; do
  MONTAGE="$m"; export MONTAGE
  [ "$m" = A ] && { redemarrer_site; attendre_sante; }
  verifier "montage $m : SIGTERM arrête le programme" "arreter_site"
  demarrer_site
  verifier "montage $m : relancé sans intervention, le site répond et la donnée témoin est là" "attendre_sante && temoin_la"
done
curl -s -o /dev/null --max-time 20 -X DELETE -H "@$TMP/a.h" "$ADRESSE/api/todos/$temoin"
verifier "outil : revoke révoque les sessions et jetons du compte (le jeton de A est refusé ensuite)" \
  "\"\${SSH_CIBLE[@]}\" '$DOSSIER/lancer.sh outil app.accounts revoke $EMAIL_A' | grep -q 'révoqué' && [ \"\$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H '@$TMP/a.h' '$ADRESSE/api/todos')\" = 401 ]"

echo ""; echo "▶ retour arrière et migrations par l'outil, sur la cible"
arreter_site
verifier "outil : status dit toutes les migrations passées" \
  "[ \"\$(\"\${SSH_CIBLE[@]}\" '$DOSSIER/lancer.sh outil app.migrate status' | grep -c 'passée\$')\" = 2 ]"
verifier "outil : down annule la dernière migration" \
  "\"\${SSH_CIBLE[@]}\" '$DOSSIER/lancer.sh outil app.migrate down' | grep -q '0002_accounts_and_owner annulée'"
verifier "retour arrière du code : le lien courant revient à la version précédente d'un seul geste" \
  "sur_cible 'cd $DOSSIER && ln -sfn \"\$(readlink precedent)\" courant.nouveau && mv -Tf courant.nouveau courant && [ \"\$(readlink courant)\" = \"\$(readlink precedent)\" ]'"
# Montage B sur une base à migrer : wsgi.py joue la migration manquante, une fois, avec deux processus.
MONTAGE=B; export MONTAGE
# D'abord l'échec : base injoignable au moment de migrer. Le site ne doit PAS servir, le témoin rester.
poser_temoin
sur_cible "sed -i \"s/^DB_PORT=.*/DB_PORT='1'/\" $DOSSIER/.env"
demarrer_site
sleep 6
verifier "montage B : si la migration échoue, uWSGI ne sert pas et le témoin reste (le contrôle du script le verrait)" \
  "! curl -sf --max-time 3 '$ADRESSE/api/health' >/dev/null 2>&1 && [ \"\$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 '$ADRESSE/')\" != 200 ] && ! sans_temoin"
arreter_site || docker exec "$CIBLE" pkill -KILL -u "$COMPTE" -f uwsgi || true
sur_cible "sed -i \"s/^DB_PORT=.*/DB_PORT='$KIT_PG_PORT'/\" $DOSSIER/.env"
# Puis un témoin laissé par un processus tué en route (.migrer.<pid>), et `--lazy-apps` : chaque
# processus importe wsgi.py de son côté ; tous voient le témoin, tous passent par l'outil.
sur_cible "mv $DOSSIER/.migrer $DOSSIER/.migrer.99999"
lignes_avant="$(sur_cible "wc -l < $JOURNAL")"
journal_depuis() { sur_cible "tail -n +$((lignes_avant + 1)) $JOURNAL"; }
UWSGI_PLUS=--lazy-apps demarrer_site
verifier "montage B, lazy-apps : deux processus importent wsgi.py, la migration manquante est jouée une seule fois" \
  "attendre_sante && [ \"\$(sql 'SELECT COUNT(*) FROM schema_migrations')\" = 2 ] && sans_temoin"
verifier "montage B, lazy-apps : chaque processus a bien chargé l'application lui-même" \
  "[ \"\$(journal_depuis | grep -c 'WSGI app 0 .* ready')\" -ge 2 ]"
verifier "montage B, lazy-apps : la migration manquante est jouée une seule fois, aucun échec au journal" \
  "[ \"\$(journal_depuis | grep -c 'migrate up : 0002_accounts_and_owner')\" = 1 ] && ! journal_depuis | grep -qi 'REFUS\|Traceback'"
arreter_site

echo ""; echo "▶ le lanceur refuse de démarrer sans configuration sûre"
set +e; trap - ERR
sur_cible "mv $DOSSIER/.env $DOSSIER/.env.de-cote"
sortie_sans="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" "$DOSSIER/lancer.sh" 2>&1)"; code_sans=$?
sur_cible "mv $DOSSIER/.env.de-cote $DOSSIER/.env; chmod 644 $DOSSIER/.env"
sortie_644="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" "$DOSSIER/lancer.sh" 2>&1)"; code_644=$?
sortie_wsgi="$(docker exec -u "$COMPTE" -w "$DOSSIER" "$CIBLE" /usr/alwaysdata/python/3.12/bin/python -c 'import wsgi' 2>&1)"; code_wsgi=$?
sur_cible "chmod 600 $DOSSIER/.env"
sur_cible "sed -i 's/^TODO_PUBLIC_URL=/X_TODO_PUBLIC_URL=/' $DOSSIER/.env"
sortie_url="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" timeout 20 "$DOSSIER/lancer.sh" 2>&1)"; code_url=$?
sur_cible "sed -i 's/^X_TODO_PUBLIC_URL=/TODO_PUBLIC_URL=/' $DOSSIER/.env"
sur_cible "chmod 600 $DOSSIER/.env; sed -i \"s/^TODO_SECRET_KEY=.*/TODO_SECRET_KEY='$(alea 4)'/\" $DOSSIER/.env"  # 8 caractères : trop courte
sortie_cle="$(docker exec -u "$COMPTE" -e IP=::1 -e PORT="$PORT_SITE" "$CIBLE" timeout 20 "$DOSSIER/lancer.sh" 2>&1)"; code_cle=$?
set -e; piege
verifier "sans .env : refus (code $code_sans), message explicite" "[ $code_sans -ne 0 ] && printf '%s' \"\$sortie_sans\" | grep -q '.env absent'"
verifier ".env lisible par d'autres (644) : lancer.sh refuse (code $code_644)" "[ $code_644 -ne 0 ] && printf '%s' \"\$sortie_644\" | grep -q 'droits 600'"
verifier ".env lisible par d'autres (644) : wsgi.py refuse aussi (code $code_wsgi)" "[ $code_wsgi -ne 0 ] && printf '%s' \"\$sortie_wsgi\" | grep -q 'droits 600'"
verifier "adresse publique absente : l'application refuse de démarrer et nomme la variable (code $code_url)" "[ $code_url -ne 0 ] && printf '%s' \"\$sortie_url\" | grep -q 'TODO_PUBLIC_URL est absente'"
verifier "clé d'instance trop courte : l'application refuse de démarrer (code $code_cle)" "[ $code_cle -ne 0 ] && printf '%s' \"\$sortie_cle\" | grep -q 'TODO_SECRET_KEY'"

echo ""; echo "▶ limites du pont ASGI→WSGI sous uWSGI : essayées, pas supposées"
docker cp -q "$ROOT/harness/pont" "$CIBLE:/tmp/pont"
docker exec "$CIBLE" chmod -R a+rX /tmp/pont
docker exec -u "$COMPTE" "$CIBLE" sh /tmp/pont/essayer.sh "$DOSSIER/courant/deps" "$PORT_SONDE" > "$TMP/pont.txt" 2>"$TMP/pont.err" || ko "l'essai du pont échoue : $(tail -n 3 "$TMP/pont.err")"
sed 's/^/    /' "$TMP/pont.txt"
pont() { grep "^$1 " "$TMP/pont.txt" | grep -q "\"$2\": $3"; }
for v in kit-threads kit-enable-threads kit-un-processus; do
  verifier "$v : le pont du kit répond, dix fois de suite" "pont $v repond true && pont $v repond_dix_fois true"
  verifier "$v : le cycle de vie ASGI (lifespan) n'est PAS transmis, la tâche de fond qu'il lance ne tourne pas" \
    "pont $v lifespan false && pont $v tache_de_fond_du_lifespan false"
  verifier "$v : une réponse en flux arrive au fil de l'eau" "pont $v flux_au_fil_de_l_eau true"
  verifier "$v : une tâche lancée après la réponse s'exécute" "pont $v tache_apres_reponse true"
  verifier "$v : WebSocket refusé (pas de 101)" "grep '^$v ' '$TMP/pont.txt' | grep -q '\"websocket\": \"HTTP/1.1 4' "
  verifier "$v : les fils de l'application avancent quand le serveur ne reçoit rien" "pont $v fils_actifs_au_repos true"
done
# Constat, pas exigence : ce uWSGI-ci (paquet pyuwsgi) laisse tourner les fils de l'application
# même sans `enable-threads` ; celui de l'hébergeur n'a pas été essayé. Le guide le dit ainsi.
echo "  · kit-sans-fils (uWSGI sans enable-threads) : fils de l'application actifs au repos = $(grep '^kit-sans-fils ' "$TMP/pont.txt" | sed -n 's/.*"fils_actifs_au_repos": \([a-z]*\).*/\1/p')"
verifier "kit-sans-fils : le pont du kit répond, dix fois de suite" "pont kit-sans-fils repond_dix_fois true"
verifier "naif-threads : un pont créé à l'import puis dédoublé ne répond plus (d'où le pont créé par processus dans wsgi.py)" \
  "pont naif-threads repond false"
verifier "naif-lazy-apps : le pont naïf répond si uWSGI charge l'application dans chaque processus (lazy-apps)" \
  "pont naif-lazy-apps repond true"

echo ""; echo "▶ aucun secret dans les journaux ni dans les sorties du script"
{ sur_cible "cat $JOURNAL"; cat "$TMP/deploiement-1.log" "$TMP/deploiement-2.log" "$TMP/deploiement-3.log"; printf '%s\n' "$sortie_sans" "$sortie_644" "$sortie_wsgi" "$sortie_url" "$sortie_cle"; } > "$TMP/sorties"
printf '%s\n' "$mdp_base" "$cle_instance" "$MDP_A" "$MDP_B" "$MDP_C" "$jeton" > "$TMP/secrets"
verifier "les sorties et le journal ne sont pas vides, les secrets à chercher non plus" \
  "[ -s '$TMP/sorties' ] && [ \"\$(grep -c . '$TMP/secrets')\" = 6 ]"
verifier "ni mot de passe de la base, ni clé d'instance, ni mot de passe de compte, ni jeton dans le journal du site ou les sorties du déploiement" \
  "! grep -qFf '$TMP/secrets' '$TMP/sorties'"

echo ""; echo "▶ le guide publie le tableau des combinaisons et les limites essayées"
GUIDE="$ROOT/deploiement/alwaysdata/README.md"
for cle in A/fastapi/cqrs A/fastapi/orm A/starlette/cqrs A/starlette/orm B/fastapi/cqrs B/fastapi/orm B/starlette/cqrs B/starlette/orm; do
  IFS=/ read -r m h p <<<"$cle"
  verifier "guide : la combinaison $cle y figure" "grep -Eq '^\\| *$m *\\| *$h *\\| *$p *\\|' '$GUIDE'"
done
verifier "guide : dit « non prouvé chez l'hébergeur »" "grep -q \"non prouvé chez l'hébergeur\" '$GUIDE'"

echo ""
echo "  Combinaisons jouées (répétition locale du $(date +%Y-%m-%d) ; non prouvé chez l'hébergeur) :"
echo "  | Montage | HTTP | Persistance | Smoke e2e |"
echo "  |---|---|---|---|"
for cle in A/fastapi/cqrs A/fastapi/orm A/starlette/cqrs A/starlette/orm B/fastapi/cqrs B/fastapi/orm B/starlette/cqrs B/starlette/orm; do
  IFS=/ read -r m h p <<<"$cle"
  echo "  | $m | $h | $p | ${RESULTAT[$cle]:-non joué} |"
  [ "${RESULTAT[$cle]:-}" = "🟢" ] || fail=1
done

echo ""
if [ "$fail" = 0 ]; then echo "deploiement (répétition locale, 8 combinaisons, deux montages): 🟢"; else echo "deploiement (répétition locale): 🔴"; fi
exit "$fail"
