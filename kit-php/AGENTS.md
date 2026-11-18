# AGENTS.md — kit-php (PHP hexagonal, full-stack, déployable sur hébergement infogéré)

Contrat agent du **kit de référence Foyer**. Archétype **stateful full-stack** ; PHP hexagonal,
adaptateur HTTP de référence **API Platform / Symfony** (un adaptateur vanilla sans framework
reste prouvé), front îlot Svelte, gates exécutés via Docker sur **images publiques**. Le domaine
d'exemple est **Todo**, avec **comptes et cloisonnement par propriétaire** — pour un nouveau
projet, l'agent remplace le périmètre `Todo` par le sien (cf. `pilote/journeys/nouveau-projet.md`,
étape B0) et garde le socle d'authentification.

**Marche direct après clone** : `bash docker/build.sh` (une fois) puis `bash harness/ci.sh`.
Ce kit fait partie de la famille de kits Foyer — voir `../KITS.md`.

## Architecture et sa loi

Ordre des couches (dépendances vers l'intérieur — **le violer casse un invariant**) :

```
Domain (pur) → Application (use-cases, ports) → Adapter (PDO, Doctrine, horloge, hachage) → Http (API Platform | vanilla) → Frontend (îlot Svelte, client généré)
```

- `src/Domain/Todo/` — entité `Todo` (invariants dans le constructeur : libellé non vide,
  **propriétaire obligatoire**), `TodoRules`, ports (`TodoRepository`, `Clock`, `IdGenerator`).
- `src/Domain/Account/` — `Account`, ports `CurrentUser` (l'identité), `AccountRepository`,
  `AccessTokenRepository`, `PasswordHasher`, `TokenGenerator`. **Aucun `PDO`, SQL, Symfony ni
  API Platform dans `Domain/` et `Application/`** (gate H1).
- `src/Application/Todo/` — `CreateTodo`, `ListTodos` (liste bornée), `GetTodo`, `ToggleTodo`,
  `DeleteTodo`. `src/Application/Account/` — `RegisterAccount`, `IssueAccessToken`,
  `ResolveAccessToken`, `RevokeAccessToken`.
- `src/Adapter/` — persistance enfichable (ci-dessous), comptes et jetons (PDO), hacheur,
  `Migration/Migrator`, et `Services` : la **racine de composition**, la même pour les deux
  adaptateurs HTTP et pour les outils `bin/`.
- `src/Http/` — `Front` (contrôleur frontal), `Problem` (erreurs RFC 9457), `SecurityHeaders` ;
  `src/Http/ApiPlatform/` (noyau Symfony, sécurité, ressource) ; `src/Application.php` (vanilla).

### Cloisonnement par propriétaire (ADR-001)

**Toute** méthode du port `TodoRepository` prend le propriétaire (`find($ownerId, $id)`,
`findAll($ownerId, $limit, $offset)`, `save($ownerId, $todo)`, `delete($ownerId, $id)`) : le
cloisonnement est dans les adaptateurs de persistance, pas seulement dans la couche HTTP. Les cas
d'usage lisent l'identité par le port `CurrentUser`, **jamais dans la requête**. Un todo d'autrui
et un identifiant inexistant donnent le même 404. Décisions et ce qui est écarté :
[`docs/adr/ADR-001-authentification.md`](docs/adr/ADR-001-authentification.md).

### HTTP — choix enfichable (clé `http`, variable `TODO_HTTP`)

Un seul contrat (`openapi/todos.openapi.json`), deux adaptateurs alignés dessus : liste = tableau
JSON borné, `DELETE` → 204, erreurs au format problème, champ inconnu → 400, validation → 422.

- `apiplatform` (**référence, défaut**) : API Platform + `symfony/security-bundle`. Ressource DTO
  (`Resource/TodoResource`, entrée `Resource/TodoInput` validée par `symfony/validator`,
  désérialisation stricte), **State Provider/Processor** délégant aux cas d'usage. Authentification
  par **session** (`POST /api/login`, cookie `HttpOnly`, `SameSite=Strict`, `Secure` en https) **et**
  par **jeton porteur** (`POST /api/tokens`, `Authorization: Bearer`). `access_control` ferme tout
  `/api` sauf connexion, inscription, émission de jeton et sonde ; chaque opération déclare en plus
  sa sécurité. Limitation des essais par un limiteur du kit branché sur `login_throttling` (clé =
  courriel normalisé, un seul compteur pour les deux points d'entrée, essai réservé en base avant
  la vérification), inscription sans oracle (202), sessions expirées par l'application, contrôle de
  l'en-tête `Origin` (CSRF).
  Documentation OpenAPI : `GET /api/docs.jsonopenapi`. Gate : `bash harness/e2e-apiplatform.sh`.
- `vanilla` : routeur maison (`src/Application.php`), sans Composer. **Jeton porteur seulement**,
  vérifié contre la même table ; ni session, ni connexion par mot de passe, ni inscription, ni
  émission de jeton (ADR-001 dit pourquoi). Gate : `bash harness/e2e-smoke.sh`.

### Persistance — choix enfichable (clé `persistence`, variable `TODO_PERSISTENCE`)

Même port `TodoRepository`, deux implémentations (`src/Adapter/Todo/RepositoryFactory.php`) :
`cqrs` (défaut, SQL pur, `TodoQueries`/`TodoCommands`) et `doctrine` (ORM, `Doctrine/TodoRecord`
mappé au domaine pur). Le gate `integration` rejoue le parcours **et le cloisonnement** sur les
deux. Comptes et jetons sont en PDO seul (ADR-001). Choix = point d'ADR, pas une question au PO.

## Configuration

`src/Config.php` assemble trois couches : défauts sûrs (inscription fermée) ← **fichier**
`src/config.php` (droits 600, jamais versionné ; gabarit : `src/config.example.php`) ← **variables
d'environnement** (`TODO_HTTP`, `TODO_PERSISTENCE`, `DB_*`, `KIT_SECRET`, `KIT_PUBLIC_URL`,
`KIT_REGISTRATION`, `KIT_VAR_DIR`, `KIT_LOG_LEVEL`, `KIT_LOGIN_IP_LIMIT`, `KIT_SESSION_IDLE`,
`KIT_SESSION_MAX`), prioritaires. Sur un hébergeur, le fichier
fait foi ; le harnais passe par les variables.

- `secret` : secret du noyau Symfony, 32 caractères au moins. **Aucun défaut, aucun littéral** (gate G1) ; tiré au hasard
  par le harnais (`var/harness/kit.env`) et par `deployer.sh` sur le serveur.
- `public_url` : fixe l'origine admise (CSRF), le drapeau `Secure` et HSTS, sans regarder la requête.
- `registration` : `open` | `closed` (défaut `closed`).
- `var_dir` : journaux (`log/kit.log`), sessions. Jamais le répertoire temporaire du système.
  Les compteurs d'essais sont en base (table `attempt_windows`).
- `login_ip_limit` (50 par minute, 0 = aucun), `session_idle` (7200 s), `session_max` (43200 s).

## Contrat API — matérialisé, pas décrit

Source de vérité : `openapi/todos.openapi.json` (opérations, schémas, **schémas de sécurité**).
Le client **TypeScript typé** est **généré** par `frontend-todos/scripts/gen-api.mjs` →
`frontend-todos/src/generated/api.ts` (au `npm run prebuild`), bundlé dans l'îlot ; il porte
`securitySchemes` et `operationSecurity`. **Ne jamais éditer `api.ts` à la main** : le gate
`contrat` le régénère et échoue s'il diverge. Le gate e2e vérifie que la documentation produite
par API Platform couvre chaque chemin du contrat et déclare les deux schémas de sécurité.

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun PHP local requis : tout passe par Docker, images **publiques** construites par
`bash docker/build.sh` → `todo-kit-php:local` (php:8.3-cli + pdo_mysql + Composer ;
`KIT_PHP_VERSION=8.4` pour changer), `todo-kit-visual:local` (node:22-bookworm + Chromium),
`todo-kit-php-cible:8.3-fcgid` (cible de la répétition : Apache + mod_fcgid + php-cgi ;
`KIT_CIBLE=fpm` pour la variante Apache + PHP-FPM). Les gates les construisent à la volée si absentes.

| Gate | Commande | DB requise |
|---|---|---|
| `verify` / `plancher` (G1/G2/H1/C1/D1) | `bash harness/run-verify.sh` | non |
| `unit` + `bdd` (domaine + application) | `bash harness/run-phpunit.sh` | non |
| `contrat` (client typé api.ts à jour) | `bash harness/run-contract.sh` | non |
| `integration` (login sans privilège, migrations, cloisonnement CQRS + Doctrine) | `bash harness/run-integration.sh` | **oui** |
| `e2e` vanilla (jeton porteur) | `bash harness/e2e-smoke.sh` | **oui** |
| `e2e` API Platform (session + jeton, scénarios #31) | `bash harness/e2e-apiplatform.sh` | **oui** |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | **oui** |
| `deploiement` (répétition locale, 4 combinaisons) | `bash harness/repeter-deploiement.sh` | MariaDB jetable |
| `doc-vivante` (preuve de valeur, **non bloquant**) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | **oui** |
| **tous** | `bash harness/ci.sh` | **oui** |

Un seul test : `bash harness/run-phpunit.sh --filter TodoTest`.
E2E sur Doctrine : `TODO_PERSISTENCE=doctrine bash harness/e2e-apiplatform.sh`.
E2E contre une adresse existante (ni Docker ni remise à zéro, nettoie ce qu'il crée) :
`E2E_BASE_URL=https://… E2E_A_EMAIL=… E2E_A_PASSWORD=… E2E_B_EMAIL=… E2E_B_PASSWORD=… bash harness/e2e-apiplatform.sh`
et `E2E_BASE_URL=https://… E2E_A_TOKEN=… E2E_B_TOKEN=… bash harness/e2e-smoke.sh`.
Contre un hébergeur réel, ajouter `E2E_PROFIL=public` (parcours allégé, une seconde entre deux
requêtes) et ne faire **qu'un passage** par combinaison : une rafale de refus fait bloquer l'adresse
du poste par le frontal (guide de déploiement, « Vérifier »).

### Base du harnais : un login sans privilège

Les gates montent `todo-mysql` (mysql:8.0, `127.0.0.1:13306`) et y créent, de façon idempotente,
l'utilisateur **`kit_php_app`** : droits sur la base `todo` seulement (ni `root`, ni `SUPER`, ni
`GRANT OPTION`), mot de passe tiré dans `var/harness/kit.env` (droits 600). **Tous** les gates s'y
connectent ; `integration` échoue si le login a un privilège global. MariaDB (la base de la cible)
est couverte par le gate `deploiement`, qui y rejoue aussi `integration`.

### Outils en ligne de commande (PDO seul, sans Composer)

```bash
php bin/migrate.php up|down|status     # applique les migrations manquantes / annule la dernière / liste
php bin/account.php create <courriel>  # mot de passe lu sur l'entrée standard, ou tiré et affiché une fois
php bin/account.php token <courriel>   # émet un jeton porteur, affiché une fois
php bin/warmup.php                     # préchauffe le cache du noyau (poste seulement ; exige vendor/)
```

`migrate.php` trace les migrations dans `schema_migrations` (version, somme de contrôle, date) et
**refuse** d'avancer si une migration déjà passée a changé. Les harnais n'exécutent jamais un
fichier SQL à la main : ils passent par cet outil (`harness/reset-db.php`).

### Front (îlot)

```bash
cd frontend-todos && npm install && npm run build   # → public/todos-island/index.js
```

L'îlot **n'écrit jamais d'URL d'endpoint en dur** : il passe par le client généré. Quand l'API
répond 401 il montre le formulaire de connexion (et d'inscription si elle est ouverte) ; avec
l'adaptateur vanilla, un champ de jeton. Le jeton n'est gardé qu'en mémoire.

### Servir l'app en local

```bash
source harness/ensure-images.sh && ensure_php_image && ensure_vendor && ensure_mysql && kit_reset_db
kit_serve apiplatform cqrs      # → http://127.0.0.1:8080 (inscription ouverte) ; kit_stop pour arrêter
```

## Déploiement sur hébergement infogéré

Point d'entrée de production : `public/index.php` + `public/.htaccess` (réécriture vers le
contrôleur frontal, en-tête `Authorization` transmis à PHP, fichiers cachés refusés). Les en-têtes
de sécurité sont posés par l'application. Une erreur de base → 503 générique.

```bash
bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> <adresse publique>
bash deploiement/alwaysdata/revenir.sh  <hôte ssh> <compte> <instance> <adresse publique>   # retour arrière
```

`vendor/` et le cache du noyau sont construits **sur le poste** ; versions datées, bascule
atomique du lien `courant`, version précédente gardée, configuration créée une fois sur le serveur.

Avec le jeton d'API `ALWAYSDATA_TOKEN` (dans l'environnement, ou dans le `.env` du kit, ignoré
par git), `deployer.sh` crée d'abord ce qui manque chez l'hébergeur, après
l'avoir annoncé : l'utilisateur de base `<compte>_<instance>`, la base du même nom, le site PHP
(retrouvé par son adresse, racine `<instance>/courant/public`). Il ne modifie ni ne supprime rien
d'existant ; si `KIT_DB_NAME` ou `KIT_DB_USER` sortent de la convention, il ne crée rien. Sans
jeton, il s'arrête avant tout envoi si l'instance n'a jamais été préparée. `revenir.sh` rebascule
le lien `courant` sur la version précédente (un site PHP ne se redémarre pas) ; rejoué, il annule
le retour ; il ne joue ni ne défait aucune migration. Ces créations et `revenir.sh` ne sont
prouvés qu'en répétition locale, contre le faux serveur d'API : non prouvé chez l'hébergeur.

Fichiers communs aux trois kits : `deploiement/alwaysdata/hebergeur.sh`, `hebergeur.py` (les
gestes auprès de l'API de l'hébergeur : lire l'état, créer ce qui manque, redémarrer) et
`harness/faux-hebergeur.py` (le faux serveur d'API de la répétition). **Ces trois fichiers sont
identiques dans `kit-actix`, `kit-fastapi` et `kit-php` : toute modification se reporte dans les
trois** (le gate `deploiement` le vérifie).
Guide, retour arrière et tableau de ce qui est prouvé : [`deploiement/alwaysdata/README.md`](deploiement/alwaysdata/README.md).
Séquence du rôle : `pilote/roles/deployeur-heberge.md`.

## Règles de l'agent

- **Respecter l'ordre des couches** ; ne pas mettre de logique métier dans un adaptateur HTTP ni
  d'infra dans le domaine.
- **Le propriétaire ne vient jamais de la requête.** Tout nouveau port de repository prend le
  propriétaire dans chaque méthode ; toute nouvelle ressource API Platform déclare sa sécurité,
  a un DTO d'entrée validé et une désérialisation stricte.
- **Ne jamais committer `src/config.php` ni `var/`** — cf. `.gitignore`, gate G1. Aucun secret en
  argument de commande ni dans une sortie. Aucun compte à mot de passe connu posé par migration.
- **`composer.lock` est versionné** : `composer update` se fait dans l'image du kit, puis les gates.
- **Toute migration** `NNNN_*.up.sql` a son `*.down.sql` réversible, SQL portable MySQL/MariaDB (pas
  de `NOW()`/`AUTO_INCREMENT`) — gate G2. **Ne jamais modifier une migration déjà passée** : en
  écrire une nouvelle.
- **Régénérer le client** après toute modif du contrat OpenAPI ; ne pas l'éditer à la main.
- Un **commit par étape conclusive** ; mettre à jour le registre d'état du projet consommateur
  (`PROJET.md`/`RETROFIT.md`/`RELEASE.md` à sa racine, cf. `pilote/state.template.md`).

## Gate `visuel` — outillé

- Harnais dans `harness/visual/` : Chromium Playwright, parcours rejoué **sur l'adaptateur de
  référence** : formulaire de connexion (golden `todo-login`), connexion par l'UI, liste (goldens
  `todo-page`, `todo-island`), déconnexion. Comparaison par `pixelmatch` (tolérance 0,5 %).
- Puis le même îlot **sur l'adaptateur vanilla** : champ de jeton, jeton collé, liste, bascule,
  oubli du jeton. Parcours fonctionnel, sans golden : il prouve que le front marche sur les deux.
- Rendu stabilisé (focus retiré, animations désactivées, tâches seedées à des secondes distinctes).
- `VISUAL_MODE=capture bash harness/run-visual.sh` régénère les goldens après un **changement de
  rendu intentionnel** (à faire consciemment : c'est le point de bascule D2).
