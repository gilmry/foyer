# ADR-001 — Authentification et cloisonnement par propriétaire

- **Statut** : **proposé, à valider par le superviseur**
- **Déjà tranché par le superviseur** (2026-11-17 et 2026-11-18, issues #31, #34, #35) — le cadre
  seulement : API Platform / Symfony est l'adaptateur HTTP de référence et l'adaptateur vanilla
  reste prouvé ; les deux mécanismes, session par cookie ET jeton porteur.
- **Décisions de l'auteur de cet ADR, à valider** :
  1. jetons porteurs **opaques**, stockés en empreinte SHA-256, 30 jours, plutôt qu'un JWT ;
  2. **contrat 2.0.0 aligné sur les conventions d'API Platform** (liste en tableau, `DELETE` → 204,
     erreurs au format problème, 422) — une rupture pour l'ancien contrat de l'adaptateur vanilla ;
  3. adaptateur **vanilla en jeton porteur seul** (ni session, ni connexion, ni inscription) ;
  4. **défaut `TODO_HTTP=apiplatform`** (il était `vanilla`) ;
  5. hachage par le hacheur `auto` de Symfony, **bcrypt** à ce jour ;
  6. **limitation des essais** : limiteur du kit branché sur `login_throttling`, 5 essais par minute
     et par compte quelle que soit l'adresse, 50 par adresse ; inscription sans oracle, 10 par
     adresse et par 10 minutes ;
  7. sessions : 2 heures d'inactivité, 12 heures au plus, contrôlées par l'application ;
  8. courriel comparé octet pour octet (collation binaire).
- **Date** : 2026-11-18
- **Périmètre** : `kit-php`, les deux adaptateurs HTTP et les deux adaptateurs de persistance

## Contexte

Le kit ne montrait pas comment protéger une ressource : aucun compte, aucun propriétaire sur
`Todo`, toute tâche visible de tout appelant. Quiconque partait du kit devait écrire en premier les
deux stories les plus sensibles, sans modèle ni gate.

Contraintes reçues :

- le domaine et l'application restent purs (gate H1) ; le propriétaire entre par un **port** ;
- le cloisonnement ne vit pas que dans la couche HTTP : **toute** lecture et écriture du port
  `TodoRepository` prend le propriétaire, sur CQRS **et** sur Doctrine ;
- **API Platform / Symfony est l'adaptateur HTTP de référence** ; l'adaptateur vanilla reste prouvé ;
- **les deux mécanismes** d'authentification : session par cookie pour le front îlots, jeton
  porteur pour les clients d'API ;
- la cible est un hébergement PHP infogéré : pas de service annexe (ni Redis, ni fournisseur
  d'identité), une base MariaDB, un login sans privilège.

## Décision

### 1. Le propriétaire dans le domaine

- `Todo` porte `ownerId`. Le port `TodoRepository` prend le propriétaire dans **chacune** de ses
  méthodes : `find($ownerId, $id)`, `findAll($ownerId, $limit, $offset)`, `save($ownerId, $todo)`,
  `delete($ownerId, $id)`. Un adaptateur ne peut pas être appelé sans lui.
- Le port `CurrentUser` (domaine, `src/Domain/Account/`) donne l'identifiant du compte courant aux
  cas d'usage et lève `AuthenticationRequiredException` sans identité. Aucun cas d'usage ne reçoit
  de propriétaire depuis la requête.
- Un todo d'autrui et un identifiant inexistant sont **le même cas** : `find` renvoie `null`, le
  cas d'usage lève `TodoNotFoundException`, la réponse est le même 404, octet pour octet.

### 2. Comptes et mots de passe

- Table `accounts` (identifiant, courriel unique, hachage). Jamais de mot de passe en clair, ni en
  base ni dans un journal.
- Hachage par le hacheur **`auto`** de Symfony (`NativePasswordHasher`, bcrypt à ce jour). Les
  outils en ligne de commande et l'adaptateur vanilla n'ont pas Composer : `NativePasswordHasher`
  (adaptateur du kit) produit et vérifie **le même format** (`password_hash`, coût 13, même
  pré-hachage au-delà de 72 octets). Le gate `integration` prouve l'aller-retour dans les deux sens.
- Mot de passe : 12 caractères au moins, 4096 octets au plus (borne de Symfony).
- « Compte inconnu » et « mauvais mot de passe » donnent **la même réponse** (401, même corps) et
  coûtent **le même calcul** : pour un courriel inconnu, le mot de passe est vérifié contre un
  hachage leurre. Le délai de réponse ne dit donc pas si un compte existe.

### 3. Création de compte (question 3 de #31)

- **Aucun compte de démonstration n'est posé par migration** : un mot de passe connu de tous dans
  un dépôt public finit en production.
- `POST /api/register`, pilotée par la clé `registration` : `open` ou `closed`. La configuration
  de production écrite par `deployer.sh` la met à `closed` ; fermée, la route répond 403. Ouverte,
  elle répond 202 sans dire si le courriel avait déjà un compte (voir 5).
- `php bin/account.php create <courriel>` crée un compte : le mot de passe est lu sur l'entrée
  standard, ou tiré et affiché une seule fois. C'est par elle que l'on crée les comptes d'un
  déploiement, dont ceux du smoke. `php bin/account.php token <courriel>` émet un jeton porteur.

### 4. Les deux mécanismes (question 1 de #31)

| | Session par cookie | Jeton porteur |
|---|---|---|
| Pour qui | le front îlots, servi depuis le même domaine | les clients d'API, les scripts |
| Obtention | `POST /api/login` (`json_login`) | `POST /api/tokens` (courriel + mot de passe), ou `bin/account.php token` |
| Transport | cookie `HttpOnly`, `SameSite=Strict`, `Secure` quand l'adresse publique est en https | en-tête `Authorization: Bearer …` |
| Fin | `POST /api/logout` | `DELETE /api/tokens/current`, ou l'échéance |

- **Jetons opaques, pas de JWT.** 32 octets tirés au hasard, préfixe `kit_` ; seule leur empreinte
  **SHA-256** est en base (`access_tokens`), avec une échéance (30 jours). Un jeton volé se révoque
  en supprimant une ligne ; une base lue ne livre aucun jeton utilisable. Un JWT ne se révoque pas
  sans liste noire, donc sans état : il n'apporte rien ici (une seule application, une seule base)
  et ajoute une clé de signature à garder. SHA-256 sans sel suffit parce que le jeton a 256 bits
  d'entropie ; un hachage lent ne protégerait rien de plus et coûterait à chaque requête.
- **Trois pare-feu**, dans cet ordre : `token_issue` (`POST /api/tokens`, sans état, `json_login`
  qui émet un jeton) ; `bearer` (toute requête `/api` qui porte un en-tête `Authorization`, sans
  état, authentificateur `access_token`) ; `main` (le reste de `/api`, session). Un client à jeton
  ne reçoit donc **jamais** de cookie de session, et le contrôle d'origine ne le concerne pas.
- `access_control` ferme tout `/api`. Sont publics : `POST /api/login`, `POST /api/register`,
  `POST /api/tokens`, `GET /api/health`. Chaque opération API Platform déclare en plus
  `security: "is_granted('ROLE_USER')"` : deux verrous indépendants.

### 5. Limitation des essais, sessions et CSRF

- **Essais de connexion.** `login_throttling` est gardé (c'est lui qui appelle le limiteur au bon
  moment), mais avec un **limiteur du kit** (`Security/LoginLimiter`, compteurs **en base**,
  table `attempt_windows`, sous verrou nommé de la base — `GET_LOCK`). Le limiteur par défaut de Symfony a été écarté après
  essai, pour trois défauts constatés :
  - sa clé est l'identifiant tel que saisi : le même compte écrit avec une espace, une tabulation
    ou une autre casse avait autant de compteurs ; ici la clé est le **courriel normalisé**, celui
    qui sert à chercher le compte ;
  - il tient un compteur par pare-feu : `POST /api/login` et `POST /api/tokens` doublaient le
    plafond ; ici **un seul limiteur** pour les deux ;
  - il ne compte l'essai qu'après l'échec : douze essais simultanés en vérifiaient neuf ; ici
    l'essai est **réservé avant** la vérification du mot de passe (5 vérifiés, 7 refusés).
  Plafonds : **5 essais par minute et par compte, quelle que soit l'adresse IP** ; 50 par minute et
  par adresse (`login_ip_limit`, 0 pour l'ôter). Au-delà : 429. Contrepartie assumée : n'importe qui
  peut suspendre pour une minute la connexion par mot de passe d'un compte dont il connaît le
  courriel ; les sessions ouvertes et les jetons porteurs ne sont pas touchés.
  Les compteurs sont en base et non en fichiers : le dossier du compte chez l'hébergeur est un
  partage NFS, où le verrou de fichier n'est pas prouvé ; le verrou de la base se comporte de la
  même façon sur le poste et chez l'hébergeur.
- **Courriel.** La colonne `accounts.email` est en collation binaire, et l'adaptateur recompare en
  PHP : avec la collation par défaut (`utf8mb4_unicode_ci`), « é » valait « e » et un courriel
  accentué désignait le compte d'un autre, avec son propre compteur d'essais (constaté sur MySQL 8
  et MariaDB, corrigé dans la migration 0002, qui n'avait été jouée nulle part hors du harnais).
- **Inscription** (quand elle est ouverte). Même réponse — 202, même corps, même calcul de
  hachage — que le courriel ait déjà un compte ou non : la route ne permet pas de sonder les
  comptes. 10 demandes par adresse IP et par 10 minutes.
- **Sessions.** Expiration tenue par l'application à chaque requête (`SessionLifetimeGuard`) :
  2 heures d'inactivité (`session_idle`), 12 heures au plus (`session_max`). La purge des fichiers
  par PHP (`gc_probability` 1/100, posé par le kit) ne fait que le ménage.
- **CSRF** : l'API est en JSON et la session est dans un cookie. Deux protections : `SameSite=Strict`,
  et un **contrôle de l'en-tête `Origin`** sur toute requête non sûre (`POST`, `PATCH`, `DELETE`)
  qui n'est pas authentifiée par jeton. L'origine doit être celle de l'adresse publique de la
  configuration (`public_url`) ; sans adresse configurée (harnais local), elle doit désigner le
  même hôte que la requête. Absente ou différente : 403. Un jeton CSRF à double soumission a été
  écarté : il demande un état de plus côté front sans rien ajouter au contrôle d'origine pour une
  API qui ne lit que du JSON.
- `Secure` et la liste des origines viennent de la **configuration**, pas de ce que PHP croit voir
  de la requête : derrière le frontal TLS d'un hébergeur, le schéma vu par PHP n'est pas garanti.

### 6. L'adaptateur vanilla (question 2 de #31)

Il **ne reste pas ouvert**. Il vérifie le **jeton porteur** contre la même table, avec la même
empreinte et la même échéance, puis passe par les mêmes cas d'usage : même cloisonnement, mêmes
401 et 404. Il sait aussi révoquer le jeton courant.

Ce qu'il **ne fait pas**, et pourquoi : il n'ouvre pas de session, ne connecte pas par mot de
passe, n'inscrit pas et n'émet pas de jeton. Tout point d'entrée qui accepte un mot de passe doit
limiter les essais ; refaire ce mécanisme à la main est précisément ce que cet ADR évite en
prenant le composant de sécurité de Symfony. Un jeton pour l'adaptateur vanilla s'obtient par
`bin/account.php token` ou par l'adaptateur de référence. Le front y fonctionne en collant un
jeton, gardé en mémoire le temps de la page (le gate `visuel` le rejoue dans un navigateur).

### 7. Un seul contrat pour les deux adaptateurs

`openapi/todos.openapi.json` reste la seule source du client `api.ts`. Les deux adaptateurs sont
**alignés sur les conventions de l'adaptateur de référence** plutôt que de rendre le client
tolérant (un client tolérant cacherait une dérive au gate `contrat`) :

- la liste est un **tableau JSON**, bornée (`limit` de 1 à 100, 50 par défaut ; `offset`) ;
- `DELETE` répond **204** sans corps ;
- les erreurs sont au **format problème** (RFC 9457, `application/problem+json`) : `type`, `title`,
  `status`, `detail`, et `violations` pour une validation ; jamais de trace ni de message interne ;
- un corps invalide (JSON mal formé, champ inconnu, dont un champ propriétaire) → **400** ; une
  règle de validation violée → **422** ; sans identité → **401** ; base injoignable → **503**
  générique.

Le contrat décrit les deux schémas de sécurité (`sessionCookie`, `bearerToken`) et le client
généré les porte. La documentation produite par API Platform (`/api/docs.jsonopenapi`) les déclare
aussi ; le gate e2e vérifie qu'elle déclare les deux schémas et couvre chaque chemin du contrat.

## Ce qui est écarté

- **JWT** : non révocable sans état, clé de signature à gérer (voir 4).
- **Comptes de démonstration par migration** : mot de passe public (voir 3).
- **Un pare-feu unique à état pour les deux mécanismes** : un client à jeton recevrait un cookie
  de session et tomberait sous le contrôle d'origine.
- **Authentification complète dans l'adaptateur vanilla** : réécriture à la main de la limitation
  des essais et de la gestion de session (voir 6).
- **Comptes et jetons en double implémentation CQRS / Doctrine** : ils sont en PDO seul. Le choix
  enfichable porte sur le port métier `TodoRepository`, et c'est là que le cloisonnement est prouvé
  deux fois. Les outils `bin/` doivent en outre tourner sans Composer.
- **Rôles, réinitialisation de mot de passe, vérification du courriel, second facteur** : hors
  périmètre de l'exemple. Un projet qui en a besoin les ajoute sur ce socle.

## Conséquences

- Paquets ajoutés (tous sous licence MIT) : `symfony/security-bundle`, `symfony/validator`,
  `symfony/rate-limiter` (exigé par `login_throttling`, même avec un limiteur du kit),
  `symfony/expression-language` (expressions `security` d'API Platform).
- Migrations `0002_accounts_and_owner` (tables `accounts` et `access_tokens`, colonne
  `todos.owner_id`) et `0003_attempt_windows` (compteurs d'essais), réversibles. Les tâches créées **avant** cette migration n'ont pas de propriétaire
  (`owner_id` vide) : plus personne ne les voit. Un projet qui a des données les rattache à un
  compte dans sa propre migration.
- Les signatures du port et des cas d'usage changent : c'est voulu, un adaptateur écrit pour
  l'ancien port ne compile plus au lieu de fuir en silence.
- **Non prouvé chez l'hébergeur — adresse IP vue par PHP.** Le plafond par adresse lit l'adresse
  du client telle que PHP la voit (`REMOTE_ADDR`, aucun en-tête de mandataire n'est cru). Derrière
  le frontal de l'hébergeur, PHP peut ne voir qu'une seule adresse : le plafond de 50 par minute
  vaudrait alors pour tous les clients ensemble (régler `login_ip_limit`, ou 0), et la limite
  d'inscription aussi. Le plafond par compte, lui, ne dépend pas de l'adresse.
- **Non prouvé chez l'hébergeur — sessions en fichiers sur NFS.** Les sessions restent des
  fichiers (`var/sessions`), sur le partage NFS du compte : le verrou que PHP pose sur le fichier
  d'une session pendant une requête n'y est pas prouvé. Sans lui, deux requêtes simultanées de la
  même session peuvent s'écraser l'une l'autre ; l'authentification n'en dépend pas.
- **Non prouvé chez l'hébergeur — purge des sessions.** Que PHP y purge bien les fichiers de
  `var/sessions` n'a pas été observé. La sécurité n'en dépend pas (l'expiration est contrôlée par
  l'application) ; seul l'encombrement du dossier en dépend.
- Les sessions sont des fichiers dans `var/sessions` de l'instance : une seule instance par site,
  ce qui est le cas de la cible.
