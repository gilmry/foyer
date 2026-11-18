# Déployer `kit-php` sur un hébergement PHP infogéré (alwaysdata)

Ce guide amène le kit sur un hébergement que l'on n'administre pas : l'hébergeur tient le système,
Apache, PHP et la base ; vous ne déposez que votre application. Il n'y a **pas de conteneur** sur
la cible, et **pas de `lancer.sh`** : contrairement aux kits qui lancent leur propre programme,
c'est l'Apache de l'hébergeur qui lance PHP. Votre point d'entrée est `public/index.php`, atteint
par `public/.htaccess`.

Le pourquoi est dans `skills/deploiement-heberge-infogere.md`, la séquence dans
`pilote/roles/deployeur-heberge.md`. Ce guide ne nomme aucun compte, aucune adresse, aucun
identifiant : remplacez `<hôte>`, `<compte>`, `<instance>` et `<adresse>` par les vôtres.

## Ce qui est monté

```
/home/<compte>/<instance>/            dossier de l'instance (hors de la racine du site)
├── config.php        configuration de l'instance, droits 600 — écrite UNE fois, sur le serveur
├── .dbpass           mot de passe de la base, droits 600 — créé par vous, une fois
├── var/              état de l'instance : journaux (var/log/kit.log), sessions, compteurs
├── versions/<date>/  une version par déploiement : public/ src/ bin/ database/ vendor/ var/cache/
├── courant    →      versions/<date>     (la version servie ; bascule par renommage du lien)
└── precedent  →      versions/<date>     (la version d'avant : le retour arrière)
```

- **Site** : type « PHP » de l'hébergeur, racine sur `/home/<compte>/<instance>/courant/public`.
  Rien hors de `public/` n'est servi : ni `src/`, ni `vendor/`, ni la configuration.
- **Base** : MariaDB gérée par l'hébergeur ; un utilisateur qui n'a de droits que sur sa base.
- **Adaptateur HTTP de référence** : API Platform / Symfony (`'http' => 'apiplatform'`).
  L'adaptateur vanilla se choisit par la même clé (`'vanilla'`) ; la persistance par
  `'persistence'` (`'cqrs'` ou `'doctrine'`).

### Où se choisit l'adaptateur (question ouverte 1 de l'issue #34)

Dans le **fichier de configuration de l'instance**, pas dans une variable d'environnement : sur un
hébergeur infogéré, on ne maîtrise pas l'environnement du PHP que sert Apache. La variable
(`TODO_HTTP`, `TODO_PERSISTENCE`) reste prioritaire quand elle existe : c'est ainsi que le harnais
local choisit, sans écrire de fichier. Changer d'adaptateur sur le serveur, c'est modifier une
ligne de `config.php` ; la sonde `/api/health` dit ensuite quelle combinaison répond.

## Ce qui a été relevé chez l'hébergeur (lecture seule, 2026-11-18)

Ces faits ne valent que pour cet hébergeur, cette offre et ce jour : ils se relèvent à nouveau.

| Sujet | Relevé |
|---|---|
| Système, PHP | Debian 12 ; PHP 8.3 et 8.4 fournis ; Composer présent, mais rien ne s'installe par SSH |
| Serveur web | Apache 2.4, `mpm_event`, `AllowOverride All` |
| Modules chargés | `rewrite`, `headers`, `setenvif`, `env`, `remoteip`, `expires`, `deflate`, `brotli`, `proxy` |
| Gestionnaire PHP | `mod_fcgid` 2.3.9 est fourni, aucun PHP-FPM visible. **Le gestionnaire exact n'a pas pu être lu** : aucun site PHP n'existait encore sur le compte |
| Dossier du compte | sur **NFS v4** (les sessions de PHP aussi) |
| `php.ini` du compte | `session.gc_probability=1`, `realpath_cache_ttl=120` |
| Base | MariaDB gérée, noms préfixés par le compte, login sans privilège d'administration |

Ce que le kit en tire : le `.htaccess` n'a besoin que de `rewrite` et `headers`, tous deux chargés ;
la répétition locale joue par défaut sur **Apache + mod_fcgid + php-cgi** ; les compteurs d'essais
de connexion sont **en base**, pas en fichiers verrouillés sur NFS ; `public/index.php` relit le
lien `courant` à chaque requête, parce que PHP garde la résolution des chemins 120 secondes.

## Avant le premier passage (une fois, à la main)

Dans l'administration de l'hébergeur :

1. **La base.** Créez une base MariaDB nommée `<compte>_<instance>` et un utilisateur
   `<compte>_<instance>` qui a **tous les droits sur cette base et sur elle seule**. Ne réutilisez
   pas l'utilisateur principal du compte.
2. **Le mot de passe de la base, sur le serveur.** Il ne passe ni par votre poste, ni par un
   argument de commande :

   ```bash
   ssh <hôte>
   umask 077 && mkdir -p ~/<instance> && cat > ~/<instance>/.dbpass   # collez le mot de passe, Entrée, Ctrl-D
   ```

3. **Le site.** Créez un site de type « PHP » :
   - adresse : `<adresse>` ;
   - racine : `/home/<compte>/<instance>/courant/public` ;
   - version de PHP : **8.3** (celle avec laquelle le kit construit `vendor/` par défaut). Pour
     PHP 8.4, réglez le site sur 8.4 **et** déployez avec `KIT_PHP_VERSION=8.4`.
   - HTTPS forcé (redirection de http vers https), si l'hébergeur le propose.

Extensions PHP requises, toutes fournies par l'hébergeur d'après la sonde du 2026-11-18 :
`pdo_mysql`, `mbstring`, `ctype`, `iconv`, `xml`, `dom`, `session`, `tokenizer`, `openssl`
(`intl` et `OPcache` sont utilisées si elles sont là).

## Déployer

Sur votre poste, à la racine du kit, avec Docker (il sert à construire `vendor/`) :

```bash
bash deploiement/alwaysdata/deployer.sh <hôte> <compte> <instance> https://<adresse>
```

Le script **refuse une adresse en `http://`** (le cookie de session n'aurait pas le drapeau
`Secure`, HSTS ne serait pas émis), un hôte ou une version de PHP mal formés.

Le script est **rejouable** : chaque passage pose une nouvelle version. Ce qu'il fait :

1. **Construit sur le poste**, dans l'image PHP du kit : `composer install --no-dev
   --optimize-autoloader` d'après `composer.lock`, puis le **préchauffage du cache du noyau**
   Symfony. Le serveur n'installe et ne compile rien : ses règles réservent SSH aux commandes
   courtes.
2. **Envoie** la version en une archive, dans un dossier neuf `versions/<date>/`.
3. **Crée `config.php` au premier passage, sur le serveur** : le secret du noyau y est tiré
   (`openssl rand`), l'inscription y est fermée. Il est écrit à côté, vérifié (`php -l`), puis
   renommé. Le fichier n'est **jamais réécrit** ensuite.
   Aucun secret ne passe en argument ni ne sort dans le terminal.
4. **Joue les migrations manquantes** par une commande courte : `php bin/migrate.php up`. Les
   migrations déjà passées ne sont pas rejouées ; une migration modifiée après coup est refusée.
   Elles passent **avant** la bascule : tant que le lien n'est pas renommé, le site ne sert que
   l'ancienne version ; si une migration échoue, rien ne bascule.
5. **Bascule** le lien `courant` d'un seul renommage (atomique), garde l'ancienne version sous
   `precedent`, puis attend que `https://<adresse>/api/health` réponde **avec le nom de la
   nouvelle version**.

Variables utiles : `KIT_PHP_VERSION` (8.3 par défaut), `KIT_DB_HOST`, `KIT_DB_NAME`, `KIT_DB_USER`,
`KIT_DB_PORT` si votre base ne suit pas les noms par défaut, `KIT_DOSSIER`. `KIT_SSH` et `KIT_SCP`
remplacent `ssh` et `scp` (c'est ainsi que la répétition locale vise sa cible jetable).

### Pourquoi le cache du noyau est préchauffé sur le poste

Deux façons de faire : le compiler au premier accès, sur le serveur, ou avant l'envoi. Il est
préchauffé **sur le poste** parce que :

- le compiler au premier accès fait porter le travail au serveur mutualisé, juste après la
  bascule, pendant que les premières requêtes attendent ;
- le conteneur compilé contient des chemins absolus : le script monte donc le dossier de la
  version **au chemin exact qu'il aura sur le serveur** pour le construire ;
- aucune valeur de l'instance n'y est figée : le secret, le dossier d'état et le niveau de journal
  sont lus à l'exécution. Le cache d'une version ne contient donc aucun secret et peut voyager.

Le cache compilé vit dans `versions/<date>/var/cache` (il dérive du code de cette version) ;
l'état — journaux, sessions, compteurs de tentatives de connexion — vit dans `var/` de l'instance
et survit aux bascules. Si le cache manque, le noyau le reconstruit au premier accès.

## Créer les comptes

L'inscription par l'API est **fermée** en production (`'registration' => 'closed'`). Les comptes se
créent par une commande courte ; le mot de passe est lu sur l'entrée standard, ou tiré et affiché
une seule fois quand vous êtes au terminal :

```bash
ssh -t <hôte> 'cd ~/<instance>/courant && php bin/account.php create <courriel>'
```

Un jeton porteur pour un client d'API (il n'est affiché qu'une fois, valable 30 jours) :

```bash
ssh <hôte> 'cd ~/<instance>/courant && php bin/account.php token <courriel>'
```

## Vérifier : le smoke contre l'adresse publique

Le smoke e2e vise une adresse existante : ni Docker, ni remise à zéro de la base. Il ne touche
qu'à ce qu'il crée, et le supprime. Créez-lui deux comptes (commande ci-dessus), puis :

```bash
# adaptateur de référence (API Platform) : session par cookie et jeton porteur
E2E_PROFIL=public E2E_BASE_URL=https://<adresse> \
E2E_A_EMAIL=<courriel A> E2E_A_PASSWORD=… E2E_B_EMAIL=<courriel B> E2E_B_PASSWORD=… \
  bash harness/e2e-apiplatform.sh

# adaptateur vanilla ('http' => 'vanilla' dans config.php) : jeton porteur
E2E_PROFIL=public E2E_BASE_URL=https://<adresse> E2E_A_TOKEN=… E2E_B_TOKEN=… bash harness/e2e-smoke.sh
```

Il vérifie le parcours de référence (créer, lister, basculer, supprimer), le cloisonnement entre
les deux comptes, les 401 sans identité, les en-têtes de sécurité (HSTS, `X-Content-Type-Options`,
interdiction d'inclusion en cadre, `Referrer-Policy`), et que rien hors de `public/` n'est servi
(`/src/config.php`, `/vendor/`, `/database/`, `/composer.json`, `/.git/`, `/.env` → 403 ou 404).
`E2E_EXPECT_PERSISTENCE=cqrs|doctrine` fait échouer le smoke si une autre persistance répond.

**Contre l'hébergeur, toujours `E2E_PROFIL=public`, et un seul passage.** Ce profil est allégé et
espacé (une seconde entre deux requêtes, `E2E_PAUSE` pour changer). Le parcours complet envoie en
quelques secondes des dizaines de refus (401, 404, chemins comme `/.env`, essais de connexion
ratés) : le frontal d'un hébergement mutualisé peut y voir une attaque et bloquer l'adresse du
poste, pour tous les sites du compte — c'est arrivé le 2026-11-18 avec un autre kit, après neuf
parcours complets enchaînés. Le parcours complet reste prouvé par la répétition locale, qui joue
les deux profils.

Sans `E2E_PROFIL=public`, le smoke consomme une trentaine d'essais de connexion ratés, presque
tous sur des identifiants jetables ; il ne verrouille pas vos comptes, mais deux smokes lancés
dans la même minute depuis la même adresse peuvent atteindre le plafond par adresse. Le profil
public n'en fait qu'un.

## Retour arrière

La version précédente est restée sur le serveur. Revenir, c'est rebasculer le lien :

```bash
ssh <hôte> 'cd ~/<instance> && ln -sfn "$(readlink precedent)" courant.nouveau && mv -T courant.nouveau courant'
```

puis relire `https://<adresse>/api/health` : le champ `version` doit nommer l'ancienne version. **Le schéma, lui, ne revient pas tout seul.** Si
la version abandonnée avait apporté une migration, annulez-la **avant** de rebasculer, depuis le
dossier de cette version, une migration à la fois :

```bash
ssh <hôte> 'cd ~/<instance>/courant && php bin/migrate.php status && php bin/migrate.php down'
```

Un `down` détruit ce que la migration avait créé (colonnes, tables, et leurs données). Quand une
migration a déjà reçu des données réelles, le retour arrière est la **restauration d'une
sauvegarde**, pas un `down`.

## Ce qui reste à votre charge

- **La preuve qu'une sauvegarde se restaure.** L'hébergeur sauvegarde, pour une durée limitée.
  Une copie hors de l'hébergeur et **une restauration essayée** restent au projet.
- **La conformité** : lire les conditions générales de l'hébergeur avant toute donnée réelle
  (`skills/conformite.md`), mettre à jour les mentions légales et le registre des traitements.
- **La bascule du nom de domaine** : le DNS est basculé par vous, jamais par un script.
- **Les journaux** : `var/log/kit.log` n'est pas tourné. Videz-le ou faites-le tourner par une
  tâche planifiée de l'hébergeur.
- **Les montées de version** de PHP et des dépendances : `composer update` sur le poste, les gates,
  puis un déploiement.
- **Les migrations compatibles** : elles se jouent juste avant la bascule ; pendant ce court
  instant, l'ancien code tourne sur le nouveau schéma. Une migration ne retire donc rien dont
  l'ancienne version a besoin.

## Ce qui est prouvé, et ce qui ne l'est pas

`bash harness/repeter-deploiement.sh` (gate `deploiement`) **répète tout ce qui précède en local** :
une cible jetable Debian 12 — **Apache + mod_fcgid + php-cgi**, le montage relevé chez l'hébergeur,
PHP sous l'identité d'un compte sans privilège, `.htaccess` limité à `AllowOverride FileInfo`,
OPcache, sshd, TLS — et une MariaDB LTS à login sans privilège. Il y joue `deployer.sh` **deux
fois** (au second passage : aucune migration rejouée, données intactes, version précédente
présente, configuration inchangée), essaie le retour arrière, retire `mod_rewrite` pour voir que
le site ne sert alors plus rien (503), puis joue les smokes contre l'adresse de la cible pour
chaque combinaison. `KIT_CIBLE=fpm` rejoue le tout sur Apache + PHP-FPM.

Combinaisons prouvées le **2026-11-18** en répétition locale, puis **chez l'hébergeur le même
jour** (voir plus bas).
Cible : Debian 12, Apache + mod_fcgid + php-cgi, PHP 8.3.36, MariaDB 12.3.3 (image `mariadb:lts`), TLS.

| Adaptateur HTTP | Persistance | Smoke e2e contre l'adresse de la cible (`E2E_BASE_URL`) |
|---|---|---|
| `apiplatform` (référence) | `cqrs` | 🟢 154 vérifications (`harness/e2e-apiplatform.sh`) |
| `apiplatform` (référence) | `doctrine` | 🟢 154 vérifications (`harness/e2e-apiplatform.sh`) |
| `vanilla` | `cqrs` | 🟢 80 vérifications (`harness/e2e-smoke.sh`) |
| `vanilla` | `doctrine` | 🟢 80 vérifications (`harness/e2e-smoke.sh`) |

Rejouée le même jour, mêmes quatre combinaisons vertes, sur deux autres cibles :
- Apache + **PHP-FPM**, PHP 8.3.36 (`KIT_CIBLE=fpm`) ;
- Apache + mod_fcgid, **PHP 8.4.27** (`KIT_PHP_VERSION=8.4` : cible et construction de `vendor/` en
  8.4, même `composer.lock`).
Seule la première est dans `harness/ci.sh`.

Dans la même répétition : le gate `integration` rejoué sur cette MariaDB avec un login sans
privilège (🟢, 64 assertions, CQRS et Doctrine) ; une base arrêtée donne un 503 générique ; ni mot
de passe, ni jeton, ni secret dans les journaux du noyau, d'Apache et de PHP, ni dans les tables.

MariaDB dans les gates locaux (question ouverte 3 de l'issue #34) : les gates `integration` et
`e2e` du poste restent sur MySQL 8.0 ; la MariaDB LTS est couverte par ce gate `deploiement`, qui
y rejoue `integration` et les smokes e2e des quatre combinaisons. Les deux moteurs sont donc dans
`harness/ci.sh`.

### Chez l'hébergeur (déploiement réel du 2026-11-18)

Un site « PHP » (version 8.3) et une base MariaDB d'essai ; le script du kit joué deux fois ; le
**smoke public** (`E2E_PROFIL=public`, un passage par combinaison) contre l'adresse publique, en
HTTPS. Le site d'essai a été supprimé ensuite.

| Adaptateur HTTP | Persistance | Smoke public chez l'hébergeur |
|---|---|---|
| `apiplatform` (référence) | `cqrs` | 🟢 111 vérifications |
| `apiplatform` (référence) | `doctrine` | 🟢 111 vérifications |
| `vanilla` | `cqrs` | 🟢 51 vérifications |
| `vanilla` | `doctrine` | 🟢 51 vérifications |

Ce que ce déploiement a montré, et que la répétition ne pouvait pas montrer :

- l'en-tête `Authorization` **arrive à PHP** sous le gestionnaire de l'hébergeur : le parcours par
  jeton porteur passe, dans les deux adaptateurs ;
- la session par cookie (`Secure`, `HttpOnly`, `SameSite=Strict`) et le contrôle d'origine passent
  derrière le frontal ;
- rien hors de `public/` n'est servi par l'Apache de l'hébergeur (`/src/config.php`,
  `/vendor/autoload.php`, `/database/schema.sql`, `/composer.json`, `/.env`) ;
- les noms par défaut du script sont les bons : hôte `mysql-<compte>.<domaine de l'hébergeur>`,
  base et utilisateur `<compte>_<instance>` ;
- **PHP 8.4 en ligne de commande avec un site en 8.3** : les migrations, la création de compte et
  l'émission de jeton tournent sous 8.4 pendant que le site sert en 8.3 ;
- au second passage : aucune migration rejouée, `config.php` inchangé, version précédente gardée,
  et la sonde de santé nomme la nouvelle version (la bascule du lien `courant` est vue).

**Le certificat d'une adresse neuve n'est pas immédiat.** Relevé le 2026-11-18 : pendant les trois
minutes environ qui suivent la création du site, l'hébergeur présente son certificat générique, que le
client refuse ; l'application, elle, répond déjà. Un premier passage du script lancé aussitôt
peut donc échouer à son contrôle final sans que rien soit cassé : attendez, puis rejouez le script.

**Non prouvé chez l'hébergeur** :

- **le parcours complet** du smoke (corps invalides, limite d'essais, mesure des délais, liste
  longue des chemins) : il reste à la répétition locale, voir « Vérifier » ;
- **le gestionnaire PHP exact** du site (toujours non lu). La répétition couvre mod_fcgid (défaut)
  et PHP-FPM ;
- **le délai** après lequel la bascule est vue : la sonde a nommé la nouvelle version, le temps
  qu'elle a mis n'a pas été mesuré (PHP peut garder l'ancien chemin jusqu'à 120 secondes,
  `realpath_cache_ttl` relevé ; le script attend jusqu'à 3 minutes) ;
- **les sessions en fichiers sur NFS** : le verrou que PHP pose sur le fichier d'une session n'y
  est pas prouvé (deux requêtes simultanées d'une même session pourraient s'écraser), ni la purge
  des fichiers (`gc_probability=1` relevé, effet non observé). L'expiration des sessions est tenue
  par l'application et n'en dépend pas. Les compteurs d'essais, eux, sont en base ;
- **l'adresse IP vue par PHP** derrière le frontal de l'hébergeur (`mod_remoteip` est chargé, son
  réglage n'a pas été lu). Le plafond d'essais de connexion par adresse (50 par minute) et celui de
  l'inscription lisent `REMOTE_ADDR` ; si PHP ne voit que l'adresse du frontal, ce plafond vaut
  pour tous vos utilisateurs ensemble. Vérifiez-le au premier déploiement, et réglez
  `'login_ip_limit'` dans `config.php` (0 l'ôte). Le plafond par compte (5 par minute) n'en dépend pas ;
- la version de MariaDB de l'hébergeur (non lue ; la répétition prend la LTS courante de l'image
  publique) ;
- la preuve qu'une sauvegarde de l'hébergeur se restaure.
