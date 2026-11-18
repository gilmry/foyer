# AGENTS.md — kit-fastapi (FastAPI hexagonal, full-stack)

Contrat agent du **kit de référence Foyer** en Python. Archétype **stateful full-stack** ;
front îlots Astro/Svelte ; gates via Docker sur **images publiques**. Domaine d'exemple **Todo**,
avec **comptes, identité et cloisonnement par propriétaire** — pour un nouveau projet, l'agent
remplace le périmètre `Todo` par le sien et garde l'identité.

**Marche direct après clone** : `bash docker/build.sh` puis `bash harness/ci.sh`.
Fait partie de la famille de kits Foyer — voir `../KITS.md`.
**Déployable sans conteneur** sur un hébergement infogéré : `deploiement/alwaysdata/README.md`.

## Architecture et sa loi

```
Domain (pur)  →  Application (use-cases + ports)  →  Adapter (HTTP / persistance)  →  Frontend (îlot)
```

- `app/domain/todo/` — entité `Todo` (invariants dans le constructeur, **porte son propriétaire
  `owner_id`**), `rules`, **ports** (`TodoRepository`, `Clock`, `IdGenerator`), exceptions.
- `app/domain/identity/` — `CurrentUser` (**le port d'identité**, même nom que dans les autres kits : objet-valeur résolu par la couche
  HTTP puis passé aux cas d'usage), `Account`, `AccessToken`, règles, exceptions, **ports**
  (`AccountRepository`, `PasswordHasher`, `TokenGenerator`, `TokenRepository`, `LoginAttempts`).
- **Python pur** dans le domaine et l'application : aucun FastAPI, Pydantic, psycopg, SQLAlchemy,
  argon2 ni accès à l'environnement (vérifié par le gate H1).
- `app/application/todo/` — `CreateTodo`, `ListTodos`, `GetTodo`, `ToggleTodo`, `DeleteTodo` :
  `execute(current_user, …)`. `app/application/identity/` — `RegisterAccount`, `LogIn`,
  `ResolveIdentity`, `LogOut`, `GetAccount`. Ne dépendent **que** du domaine.
- `app/adapter/` — implémentations concrètes (voir « adaptateurs enfichables » ci-dessous) ;
  `app/adapter/factory.py` choisit la persistance.
- `app/http/` — `api.py` (**adaptateur FastAPI**, SEUL fichier qui connaît FastAPI, source du
  contrat), `starlette_app.py` (adaptateur Starlette), `common.py` (ce qu'ils partagent :
  résolution de l'identité, contrôle d'origine, cookie, exceptions → codes HTTP), `hardening.py`
  (en-têtes de sécurité et erreur 500 générique, autour des deux), `app.py` (point d'entrée ASGI).
- `app/migrate.py`, `app/accounts.py` — outils en ligne de commande (voir plus bas).
- `wsgi.py` — point d'entrée WSGI (uWSGI, par le pont `a2wsgi`) : montage B du déploiement.
- `frontend-todos/` — îlot Svelte ; **n'écrit jamais d'URL en dur**, passe par le client **typé**
  `frontend-todos/src/generated/api.ts` (issu de `openapi/todos.openapi.json`, lui-même dumpé de FastAPI).

## Identité et cloisonnement (ADR-001)

Décision et raisons : `docs/adr/ADR-001-authentification.md`. À retenir pour coder :

- **Deux mécanismes** : session par **cookie** pour le front (`POST /api/auth/login` ; cookie
  `__Host-todo_session`, `HttpOnly`, `Secure`, `SameSite=Strict` ; contrôle de l'en-tête `Origin`
  sur toute méthode non sûre) et **jeton porteur** pour les clients d'API
  (`POST /api/auth/token`, puis `Authorization: Bearer …`). Jetons **opaques**, conservés **hachés**
  (HMAC-SHA-256 avec la clé de l'instance), avec échéance, révoqués par `POST /api/auth/logout`.
- **Mots de passe** : Argon2id (`argon2-cffi`). Jamais en clair en base, dans un journal ou dans
  une réponse. Compte inconnu et mauvais mot de passe : même réponse. 5 échecs en 15 minutes
  pour un courriel → 429, y compris sous des requêtes simultanées (essai réservé avant
  vérification, atomique par sujet).
- **Entrées bornées** : corps de 16 Kio au plus (413), longueur annoncée exigée (411) — le corps
  refusé est lu avant la réponse (1 Mio et 5 s au plus), sinon un frontal perd la réponse —,
  `application/json` exigé (422), texte non stockable (octet NUL, demi-codet isolé) refusé à la
  validation (400, 401 ou 404 selon la route) — jamais de 500 déclenchable par l'appelant.
- **Toute route des todos exige une identité** (401 sinon). Le propriétaire est l'identité de
  l'appelant, **jamais un champ de la requête** (champ inconnu → 422).
- **Le cloisonnement est dans le port** : `TodoRepository.find(owner_id, id)`,
  `find_all(owner_id)`, `save(owner_id, todo)`, `delete(owner_id, id)`. Un todo d'autrui et un
  identifiant inexistant donnent le **même 404**. Toute nouvelle entité suit le même modèle.
- **L'identité est résolue dans `app/http/common.py`**, puis passée aux cas d'usage : pas de
  `Depends`/`Security` dans l'application.
- **Aucun compte posé par migration.** `python -m app.accounts create <courriel>` (mot de passe
  sur l'entrée standard, ou tiré et affiché une fois) ; `revoke <courriel>` révoque les sessions
  et jetons d'un compte ; `adopt <courriel>` rattache les todos antérieurs à la migration `0002`.

### Variables d'environnement

| Variable | Rôle | Défaut |
|---|---|---|
| `DATABASE_URL`, ou `DB_HOST` `DB_PORT` `DB_NAME` `DB_USER` `DB_PASSWORD` | connexion PostgreSQL (les deux persistances) | — |
| `TODO_PERSISTENCE` | `cqrs` \| `orm` | `cqrs` |
| `TODO_HTTP` | `fastapi` \| `starlette` | `fastapi` |
| `TODO_ENV` | `production` \| `development` (cookie sans `Secure`, clé facultative) | `production` |
| `TODO_SECRET_KEY` | clé de l'instance, 32 caractères au moins ; **exigée hors développement** | — |
| `TODO_REGISTRATION` | `open` \| `closed` : route d'inscription | `closed` |
| `TODO_PUBLIC_URL` | adresse publique (`https://hôte[:port]`) ; origine attendue des requêtes à cookie ; **exigée hors développement** | — |
| `TODO_SESSION_TTL`, `TODO_BEARER_TTL` | durées de vie, en secondes | 12 h, 30 jours |
| `TODO_SERVE_STATIC` | `0` : ne pas servir `public/` | `1` |

## Adaptateurs enfichables (le cœur ne change jamais)

- **Persistance** — choix via `TODO_PERSISTENCE` :
  - `cqrs` (défaut) : `todo/cqrs_todo_repository.py`, `identity/cqrs_identity_store.py` — SQL pur
    (psycopg), séparation commandes/requêtes.
  - `orm` : `todo/orm_todo_repository.py`, `identity/orm_identity_store.py`, `orm_models.py` —
    **SQLAlchemy**.
  - Les deux implémentent les **mêmes ports** et lisent le **même schéma**, posé par les mêmes
    **migrations up/down SQL** (`database/migrations/`). Choix = point d'ADR
    (cf. `bmad/archetypes.md`), pas une question au PO (défaut annoncé, `pilote/defaults.md`).
- **HTTP** — choix via `TODO_HTTP` : `fastapi` (défaut, `app/http/api.py`) ou `starlette`
  (ASGI nu, `app/http/starlette_app.py`). Les deux délèguent aux **mêmes use-cases**, émettent
  le **même contrat** et portent la **même protection**. Point d'entrée : `app.http.app:app`.
  Tester : `TODO_HTTP=starlette bash harness/e2e-smoke.sh`.

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun Python local requis : tout via Docker, images **publiques** (`bash docker/build.sh`).
Tous les gates se connectent à PostgreSQL par un **login sans privilège** (`kit_fastapi_app`,
ni superutilisateur ni `BYPASSRLS`, propriétaire de sa base), celui d'une base gérée.

| Gate | Commande | Dépendance |
|---|---|---|
| `verify`/`plancher` (G1/G2/H1/C1/D1) | `bash harness/run-verify.sh` | — |
| `contrat` (client `api.ts` à jour) | `bash harness/run-contract.sh` | — |
| `unit`+`bdd` (domaine, application, HTTP sur doubles) | `bash harness/run-pytest.sh` | — |
| `integration` (CQRS **et** ORM, migrations, cloisonnement) | `bash harness/run-integration.sh` | PostgreSQL (auto) |
| `e2e` (uvicorn réel ; parcours, identité, cloisonnement) | `bash harness/e2e-smoke.sh` | PostgreSQL (auto) |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | PostgreSQL (auto) |
| `deploiement` (répétition locale, 2 montages × 4 combinaisons) | `bash harness/repeter-deploiement.sh` | PostgreSQL (auto), ssh |
| `doc-vivante` (preuve de valeur) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | PostgreSQL (auto) |
| **tous** | `bash harness/ci.sh` | PostgreSQL (auto) |

Un seul test : `bash harness/run-pytest.sh -k test_toggle`.
Tester l'e2e sur l'ORM : `TODO_PERSISTENCE=orm bash harness/e2e-smoke.sh`.
**Smoke contre une adresse en service** (ni Docker, ni remise à zéro ; il nettoie ce qu'il crée) :

```sh
E2E_BASE_URL=https://… E2E_EMAIL_A=… E2E_PASSWORD_A=… E2E_EMAIL_B=… E2E_PASSWORD_B=… bash harness/e2e-smoke.sh
```

Contre un hébergeur réel, ajouter `E2E_PROFIL=public` (parcours allégé, une seconde entre deux
requêtes) et ne faire **qu'un passage** : une rafale de refus fait bloquer l'adresse du poste par
le frontal (guide de déploiement, « Prouver le déploiement »).

Port de PostgreSQL : `KIT_PG_PORT` (défaut 15432, sur 127.0.0.1). Le conteneur `todo-postgres`
est partagé avec les autres kits : chaque kit y a son rôle et sa base, à son nom.

## Migrations

`python -m app.migrate up|down|status` (psycopg seul, sans l'ORM) : applique dans l'ordre les
`database/migrations/pending/*.up.sql` manquantes, les trace dans `schema_migrations` (version,
somme de contrôle, date), **refuse si le fichier d'une migration déjà passée a changé** ; `down`
annule la dernière. Les harnais passent par cet outil, jamais par un `psql` à la main.
**On ne modifie pas une migration jouée : on en écrit une nouvelle.**

## Dépendances

- `requirements.txt` — exécution ; `requirements-dev.txt` — tests. Versions **épinglées**.
- `requirements.lock`, `requirements-dev.lock` — transitives **verrouillées avec empreintes**,
  générées par `bash docker/verrouiller.sh` (dans l'image de la cible : Debian 12, Python 3.12).
  **Ne jamais les éditer à la main.** Après un changement : `bash docker/verrouiller.sh` puis
  `bash docker/build.sh` (l'image est reconstruite quand le verrou change). Le gate `verify` (D1)
  échoue si un verrou est désynchronisé.

## Déploiement sur hébergement infogéré

Guide : `deploiement/alwaysdata/README.md` (quel montage choisir, étapes, retour arrière, ce qui
reste au porteur, ce qui n'est pas prouvé). En bref :

- `deploiement/alwaysdata/construire.sh` — prépare la livraison **sur le poste** (dépendances
  installées depuis le verrou, dans une image Debian 12 + Python 3.12). Le serveur n'installe rien.
- `deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> <adresse publique>` —
  rejouable : envoi sous un autre nom, bascule atomique d'un seul lien (`lancer.sh` et `wsgi.py`
  vivent dans la version et basculent avec elle), version précédente gardée, `.env` créé
  sur le serveur au premier passage (secrets tirés là-bas) et jamais réécrit, redémarrage par
  l'API si `ALWAYSDATA_SITE` et le jeton `ALWAYSDATA_TOKEN` (fichier `.env` du kit, ignoré par
  git) sont fournis. Variables : `KIT_SSH`, `KIT_SCP`, `KIT_DB_HOTE`, `KIT_DB_PORT`,
  `KIT_DOSSIER`, `KIT_PYTHON`, `KIT_REDEMARRAGE`.
- **Montage A** (recommandé) — `deploiement/alwaysdata/lancer.sh` : programme utilisateur, uvicorn.
  **Montage B** — `wsgi.py` : site Python de l'hébergeur, uWSGI et pont `a2wsgi` ; pas de
  `lifespan` ni de WebSocket (limites essayées par `harness/pont/essayer.sh`).
- `harness/repeter-deploiement.sh` — la répétition : **à passer au vert avant tout déploiement réel**.

## Contrat — matérialisé, pas décrit

FastAPI **est** la source du contrat. `harness/dump_openapi.py` écrit `openapi/todos.openapi.json` ;
`frontend-todos/scripts/gen-api.mjs` en génère le client **TypeScript typé** `api.ts`, qui porte
les **schémas de sécurité** (`securitySchemes`, `operationSecurity`). Le gate `verify` (C1)
vérifie que le contrat committé == l'app et qu'il exige une identité sur les todos ; le gate
`contrat` (`run-contract.sh`) vérifie qu'`api.ts` est à jour. **Ne jamais éditer `api.ts` à la main.**

Après une modification des routes ou des schémas :

```sh
docker run --rm -v "$PWD":/app -w /app -e PYTHONPATH=/app todo-kit-fastapi:local python harness/dump_openapi.py
docker run --rm -v "$PWD":/app -w /app/frontend-todos todo-kit-visual:local bash -lc 'npm ci && npm run build'
VISUAL_MODE=capture bash harness/run-visual.sh   # si le rendu a changé volontairement
```

## Règles de l'agent
- Respecter l'ordre des couches ; jamais d'infra dans domaine/application (gate H1).
- Toute lecture et écriture d'une donnée d'utilisateur passe par un port qui **prend le
  propriétaire** ; le cloisonnement ne repose jamais sur la seule couche HTTP.
- Migrations `*.up.sql` + `*.down.sql` réversibles, SQL portable (pas de `NOW()`/`SERIAL`) ;
  jamais de compte ni de secret dans une migration.
- Aucun secret en dur, en argument de commande ni dans une sortie (gate G1) ; les harnais tirent
  leurs mots de passe à chaque exécution.
- Regénérer contrat + client après toute modif des routes/schémas.
- Toute décision structurante en ADR (`docs/adr/`).
- Un commit par étape ; mettre à jour le registre d'état du projet consommateur.
