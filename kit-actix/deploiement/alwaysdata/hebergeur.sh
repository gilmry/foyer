# Gestes communs à deployer.sh et revenir.sh auprès de l'hébergeur. Sourcé, jamais lancé seul.
# Le même fichier sert les trois kits ; ce qui change d'un kit à l'autre arrive par des variables.
#
# Attendu de l'appelant : HOTE COMPTE INSTANCE ADRESSE DOSSIER RACINE ICI, le tableau SSH, et
#   KIT_BASE_MOTEUR     POSTGRESQL ou MYSQL
#   KIT_FICHIER_MDP     fichier du mot de passe de la base, dans le dossier de l'instance
#   KIT_FICHIER_CONFIG  fichier de configuration de l'instance (sa présence dit « déjà préparée »)
#   KIT_SITE_REGLAGES   réglages du site à créer, en JSON (type, commande ou racine…)
# Réglable : KIT_ATTENTE_CERTIFICAT, secondes laissées à un site neuf pour recevoir son certificat
#   avant le premier contrôle (défaut 180 ; la répétition locale met 0) ; KIT_ATTENTE_ESSAIS,
#   nombre d'essais du contrôle pour un site déjà en place (défaut 30, à 3 secondes d'intervalle).
# Rien ici ne modifie ni ne supprime une base, un utilisateur ou un site existants.

api() { KIT_ENV_FICHIER="${KIT_ENV_FICHIER:-$RACINE/.env}" python3 -I "$ICI/hebergeur.py" "$@"; }

# hebergeur_preparer : s'assure que la base, son utilisateur et le site existent, AVANT tout envoi.
#   Avec un jeton d'API : crée ce qui manque, après l'avoir annoncé. Rejouable : ce qui existe est
#   retrouvé (base et utilisateur par leur nom, site par son adresse) et n'est pas touché.
#   Sans jeton : ne peut rien créer ; s'arrête si l'instance n'a jamais été préparée.
# Pose SITE (numéro du site, ou vide) et SITE_NEUF (1 si le site vient d'être créé).
hebergeur_preparer() {
  SITE="${ALWAYSDATA_SITE:-}"; SITE_NEUF=0
  local etat utilisateur base site prepare
  prepare="$("${SSH[@]}" -- "$HOTE" "[ -f '$DOSSIER/$KIT_FICHIER_CONFIG' ] && echo config || { [ -s '$DOSSIER/$KIT_FICHIER_MDP' ] && echo mdp || echo rien; }")"
  if ! api jeton; then
    if [ "$prepare" = rien ]; then
      cat <<FIN
arrêt avant tout envoi : aucun jeton d'API, et l'instance n'a jamais été préparée.
  Soit ranger le jeton de l'hébergeur dans $RACINE/.env (ALWAYSDATA_TOKEN=…, fichier ignoré par
  git) et rejouer : le script créera la base, son utilisateur et le site.
  Soit les créer à la main, comme le dit le guide (deploiement/alwaysdata/README.md) :
    - une base $KIT_BASE_MOTEUR ${COMPTE}_${INSTANCE} et un utilisateur du même nom, tous droits sur elle seule ;
    - son mot de passe dans $DOSSIER/$KIT_FICHIER_MDP, sur le serveur (droits 600) ;
    - un site pour $ADRESSE, réglages : $KIT_SITE_REGLAGES
FIN
      exit 1
    fi
    echo "  pas de jeton d'API : la base et le site sont supposés créés à la main"
    return 0
  fi
  etat="$(api etat "$COMPTE" "$INSTANCE" "$KIT_BASE_MOTEUR" "$ADRESSE")"
  utilisateur="$(printf '%s\n' "$etat" | sed -n 's/^utilisateur=//p')"
  base="$(printf '%s\n' "$etat" | sed -n 's/^base=//p')"
  site="$(printf '%s\n' "$etat" | sed -n 's/^site=//p')"
  [ -n "$utilisateur" ] && [ -n "$base" ] && [ -n "$site" ] || { echo "échec : état de l'hébergeur illisible"; exit 1; }
  echo "  chez l'hébergeur : utilisateur de base $utilisateur, base $base, site $site"

  if [ "$utilisateur" = absent ]; then
    if [ "$prepare" = config ]; then
      echo "échec : l'instance a déjà sa configuration mais l'utilisateur de base ${COMPTE}_${INSTANCE} n'existe pas chez l'hébergeur."
      echo "  Le script ne devine pas : vérifier le compte et le nom de l'instance."
      exit 1
    fi
    echo "  création de l'utilisateur de base ${COMPTE}_${INSTANCE} (mot de passe tiré sur le serveur)"
    # Le mot de passe naît sur le serveur. Il traverse le poste dans un tube, de la sortie de ssh à
    # l'entrée de l'appel à l'API : ni argument de commande, ni fichier, ni affichage.
    "${SSH[@]}" -- "$HOTE" "umask 077; mkdir -p '$DOSSIER'; [ -s '$DOSSIER/$KIT_FICHIER_MDP' ] || head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > '$DOSSIER/$KIT_FICHIER_MDP'; cat '$DOSSIER/$KIT_FICHIER_MDP'" \
      | api creer-utilisateur "$COMPTE" "$INSTANCE" "$KIT_BASE_MOTEUR"
  elif [ "$prepare" = rien ]; then
    echo "échec : l'utilisateur de base ${COMPTE}_${INSTANCE} existe chez l'hébergeur, mais son mot de passe n'est pas sur le serveur."
    echo "  Le script ne change pas un mot de passe qu'il n'a pas posé : le ranger dans $DOSSIER/$KIT_FICHIER_MDP (droits 600), puis rejouer."
    exit 1
  fi
  if [ "$base" = absent ]; then
    echo "  création de la base ${COMPTE}_${INSTANCE} ($KIT_BASE_MOTEUR), droits donnés à son seul utilisateur"
    api creer-base "$COMPTE" "$INSTANCE" "$KIT_BASE_MOTEUR"
  fi
  if [ -n "$SITE" ]; then
    # Le site est désigné par son numéro : le script n'en crée pas d'autre, même si l'adresse
    # publique n'y est pas encore rattachée.
    echo "  site n° $SITE désigné par ALWAYSDATA_SITE : aucun site créé"
  elif [ "$site" = absent ]; then
    echo "  création du site « $INSTANCE » pour $ADRESSE, réglages : $KIT_SITE_REGLAGES"
    site="$(api creer-site "$COMPTE" "$INSTANCE" "$ADRESSE" "$KIT_SITE_REGLAGES")"
    case "$site" in ''|*[!0-9]*) echo "échec : numéro du site créé illisible"; exit 1 ;; esac
    SITE_NEUF=1
    echo "  site créé : n° $site (son certificat peut mettre quelques minutes à être émis)"
  fi
  [ -n "$SITE" ] || SITE="$site"
}

# hebergeur_site : retrouve le numéro du site par son adresse, sans rien créer (pour revenir.sh).
hebergeur_site() {
  SITE="${ALWAYSDATA_SITE:-}"; SITE_NEUF=0
  [ -z "$SITE" ] && [ -z "${KIT_REDEMARRAGE:-}" ] && api jeton || return 0
  SITE="$(api etat "$COMPTE" "$INSTANCE" "${KIT_BASE_MOTEUR:-POSTGRESQL}" "$ADRESSE" | sed -n 's/^site=//p')"
  case "$SITE" in ''|*[!0-9]*) echo "échec : aucun site ne sert $ADRESSE chez l'hébergeur"; exit 1 ;; esac
}

# hebergeur_redemarrer : redémarre le site. Code 0 si c'est fait, 1 si le script n'en a pas le moyen.
#   KIT_REDEMARRAGE (commande locale : répétition, autre hébergeur) passe avant l'API.
hebergeur_redemarrer() {
  if [ -n "${KIT_REDEMARRAGE:-}" ]; then
    # Appelée dans un `if`, cette fonction ne profite pas de `set -e` : l'échec se teste ici.
    eval "$KIT_REDEMARRAGE" || { echo "échec de la commande de redémarrage (KIT_REDEMARRAGE)"; exit 1; }
    return 0
  fi
  local site="${SITE:-${ALWAYSDATA_SITE:-}}"
  if [ -n "$site" ] && api jeton; then
    # Par l'API de l'hébergeur, jamais par un processus lancé en SSH.
    api redemarrer "$COMPTE" "$site" || { echo "échec du redémarrage par l'API"; exit 1; }
    return 0
  fi
  return 1
}

# hebergeur_attendre <adresse à sonder> [motif attendu dans la réponse] : attend que le site réponde.
#   Peu d'essais, espacés : le frontal de l'hébergeur bloque une adresse qui le sonde en rafale.
#   Un site qui vient d'être créé reçoit d'abord son certificat (quelques minutes) : on patiente
#   sans sonder, puis on sonde plus lentement.
hebergeur_attendre() {
  local url="$1" motif="${2:-}" essais="${KIT_ATTENTE_ESSAIS:-30}" pas=3 corps
  if [ "${SITE_NEUF:-0}" = 1 ]; then
    essais=20; pas=15
    echo "  site neuf : ${KIT_ATTENTE_CERTIFICAT:-180} s laissées à l'émission du certificat"
    sleep "${KIT_ATTENTE_CERTIFICAT:-180}"
  fi
  for _ in $(seq 1 "$essais"); do
    if corps="$(curl -sf --max-time 10 "$url" 2>/dev/null)"; then
      [ -z "$motif" ] && return 0
      case "$corps" in *"$motif"*) return 0 ;; esac
    fi
    sleep "${KIT_ATTENTE_PAS:-$pas}"
  done
  return 1
}
