# AGENTS.md — kit-actix (Rust hexagonal, full-stack)

Contrat agent du **kit de référence Foyer** en Rust. Archétype **stateful full-stack** ; domaine &
application en **Rust pur**, adaptateur HTTP **Actix**, persistance **sqlx CQRS** sur PostgreSQL ;
front îlots Astro/Svelte. Gates via Docker sur **images publiques**. Domaine d'exemple **Todo**.

**Marche direct après clone** : `bash docker/build.sh` puis `bash harness/ci.sh`.
Fait partie de la famille de kits Foyer — voir `../KITS.md`.

## Architecture et sa loi

```
Domain (pur)  →  Application (use-cases + ports)  →  Adapter (HTTP Actix / persistance sqlx)  →  Frontend (îlot)
```

- `src/domain/` — entité `Todo` (invariants dans `Todo::new`), règles, **ports** (`TodoRepository`
  async, `Clock`, `IdGenerator`), erreurs. **Rust pur (std)** : aucun actix, sqlx, serde, chrono,
  uuid, tokio (vérifié par le gate H1). Dispatch statique → pas d'`async-trait`.
- `src/application/` — `CreateTodo`, `ListTodos`, `ToggleTodo`, `DeleteTodo`, génériques sur le port.
  Ne dépend **que** du domaine.
- `src/adapter/` — `CqrsTodoRepository` (sqlx, lecture/écriture séparées), `RealClock`, `UuidGenerator`.
- `src/http/` — **adaptateur HTTP Actix** : routes → use-cases, erreurs domaine → codes HTTP
  (400/404), désérialisation stricte (`deny_unknown_fields`). Seule couche qui connaît Actix.
- `src/main.rs` (serveur) · `src/bin/migrate.rs` (outil de migration) · `src/bin/integration.rs` (gate integration).
- `frontend-todos/` — îlot Svelte ; **n'écrit jamais d'URL en dur**, passe par le client **typé**
  `frontend-todos/src/generated/api.ts` (généré depuis `openapi/todos.openapi.json`).

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun Rust local requis : tout via Docker, images **publiques** (`bash docker/build.sh` →
`todo-kit-rust:local` = rust:1.97.0-slim-bookworm, `todo-kit-visual:local` = node:22-bookworm + Chromium).
Volumes de cache cargo → compilations rapides après la première.

| Gate | Commande | Dépendance |
|---|---|---|
| `verify`/`plancher` (G1/G2/H1/C1) | `bash harness/verify.sh` | — |
| `contrat` (api.ts à jour) | `bash harness/run-contract.sh` | — |
| `unit`+`bdd` (domaine+application) | `bash harness/run-tests.sh` | — |
| `integration` (sqlx CQRS **et** sea-orm, **login sans privilège**) | `bash harness/run-integration.sh` | PostgreSQL (auto) |
| `e2e` (serveur Actix réel) | `bash harness/e2e-smoke.sh` (`TODO_PERSISTENCE=orm` pour sea-orm ; `E2E_BASE_URL=https://…` pour viser une adresse en service, sans Docker) | PostgreSQL (auto) |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | PostgreSQL (auto) |
| `doc-vivante` (preuve de valeur) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | PostgreSQL (auto) |
| `chiffrement` (port `Chiffreur`, foyer#28) | `bash harness/e2e-chiffrement.sh` | PostgreSQL + OpenBao dev (auto) |
| `deploiement` (répétition locale sur une cible jetable) | `bash harness/repeter-deploiement.sh` | PostgreSQL (auto) |
| **tous** | `bash harness/ci.sh` | PostgreSQL + OpenBao dev (auto) |

Un seul test : `bash harness/run-tests.sh` puis `cargo test toggle` en local.

## Persistance — choix enfichable : CQRS sqlx ↔ ORM sea-orm

Deux adaptateurs du **même port** `TodoRepository`, prouvés interchangeables par le gate
`integration` (rejoué sur les deux) :

- `CqrsTodoRepository` (`src/adapter/mod.rs`) — SQL pur (sqlx), lecture (`query_*`) et écriture
  (`cmd_*`) séparées ; schéma par migrations up/down.
- `OrmTodoRepository` (`src/adapter/orm.rs`) — **sea-orm** : entité de persistance `todo_entity::Model`
  mappée au domaine pur (sea-orm ne fuit pas hors de l'adaptateur).

> Le serveur choisit l'adaptateur par `TODO_PERSISTENCE` (`cqrs` par défaut, ou `orm`) : un `enum`
> `RepoChoisi` derrière le même port, donc toujours du dispatch statique (pas d'`async-trait` ni de
> `dyn` dans le domaine). La permutabilité est prouvée par `integration`, par `e2e` rejoué sur les
> deux, et par `deploiement`.

## Migrations — embarquées, tracées, jamais rejouées

Les fichiers restent `database/migrations/pending/NNNN_nom.up.sql` et `.down.sql`. Ils sont
**embarqués dans les binaires** à la compilation (`sqlx::migrate!`) et tracés dans la table
`_sqlx_migrations` (version, somme de contrôle, date) : une migration passée n'est pas rejouée, et
un fichier modifié après coup fait refuser la suite.

- `migrate up` · `migrate down` (annule la dernière) · `migrate status` — binaire `src/bin/migrate.rs`.
- Le serveur les applique à son démarrage **si** `TODO_MIGRER=1`. Les harnais partent d'une base
  vide et passent par là : plus aucun script n'exécute un fichier SQL à la main.
- **Une migration appliquée ne se modifie plus** : on en ajoute une nouvelle.

## Login sans privilège

Tous les gates se connectent avec `kit_actix_app`, propriétaire de sa base, **ni superutilisateur,
ni `BYPASSRLS`, ni créateur de rôles** : c'est ce que donne un PostgreSQL géré par un hébergeur. Le
gate `integration` échoue si le login est privilégié. Le superutilisateur de l'image ne sert qu'à
créer ce login (`harness/ensure-images.sh`).

## Configuration du serveur (tout par l'environnement)

| Variable | Rôle | Défaut |
|---|---|---|
| `DATABASE_URL` (ou `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) | base PostgreSQL | **aucun** : sans elle, le serveur refuse de démarrer et nomme la variable |
| `HTTP_HOST`, `HTTP_PORT` | adresse d'écoute, IPv4 ou IPv6 | `127.0.0.1`, `8080` |
| `TODO_PERSISTENCE` | `cqrs` ou `orm` | `cqrs` |
| `PUBLIC_DIR` | dossier du front statique, le seul servi | `./public` |
| `TODO_MIGRER` | `1` : appliquer les migrations manquantes avant d'écouter | absent |

Le serveur pose lui-même les en-têtes de sécurité sur toutes ses réponses (HSTS,
`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`).

## Déploiement sur hébergement infogéré

Guide et scripts : [`deploiement/alwaysdata/`](deploiement/alwaysdata/README.md) (`construire.sh`,
`deployer.sh`, `lancer.sh`). Le serveur de l'hébergeur ne compile rien : le binaire sort de l'image
du kit (Debian 12). Le gate `deploiement` répète tout le déploiement en local avant d'y aller.
Le pourquoi : `../skills/deploiement-heberge-infogere.md`.

## Chiffrement par personne — port `Chiffreur` et module de mesure (foyer#28)

- **Port `Chiffreur`** (`src/domain/chiffrement.rs`), chiffrement par enveloppe : une clé de
  données par enregistrement, conservée seulement **enveloppée** ; les champs sont chiffrés en
  AES-256-GCM avec, comme données associées, l'identifiant et le nom du champ. Il **reste dans le
  kit** (mesure conservatoire d'ADR-044 de Sluis, point 4.5).
- **Adaptateurs** (`src/adapter/chiffrement.rs`) : `SansEffet` (`clair`), `Local` (clé maîtresse
  en mémoire, perdue au redémarrage), `OpenBao` (moteur `transit` : `datakey` pour engendrer,
  `decrypt` pour désenvelopper ; cache des clés désenveloppées, TTL réglable). Service de clés
  injoignable → `503`, **jamais** de champ servi en clair.
- **Module de mesure, désactivé par défaut** : fiche de personne (`/api/personnes`,
  `/api/mesure/compteurs`), montée seulement si `CHIFFREMENT=clair|local|openbao|openbao-cache`
  est posé. Table dans `database/mesure/`, hors du gabarit `migrations/pending/`. Hors du contrat
  OpenAPI. Variables : `OPENBAO_ADDR`, `OPENBAO_JETON`, `OPENBAO_CLE`, `CHIFFREMENT_CACHE_TTL_S`.
- **Limite du spike** : le harnais démarre OpenBao en **mode dev avec le jeton racine**. C'est
  réservé à la mesure ; la cible est un jeton court délivré à l'application (ADR-042 de Sluis,
  point 6). Hors périmètre : index aveugles, rotation, effacement par destruction de clé.

## Règles de l'agent
- Respecter l'ordre des couches ; jamais d'infra dans domaine/application (gate H1).
- Migrations `*.up.sql` + `*.down.sql` réversibles, SQL portable (pas de `SERIAL`) ; ne jamais modifier une migration déjà appliquée.
- Regénérer `api.ts` après toute modif du contrat (`npm run gen:api`) ; ne pas l'éditer à la main.
- Un commit par étape ; mettre à jour le registre d'état du projet consommateur.
