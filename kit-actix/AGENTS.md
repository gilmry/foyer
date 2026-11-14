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
- `src/main.rs` (serveur) · `src/bin/integration.rs` (gate integration).
- `frontend-todos/` — îlot Svelte ; **n'écrit jamais d'URL en dur**, passe par le client **typé**
  `frontend-todos/src/generated/api.ts` (généré depuis `openapi/todos.openapi.json`).

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun Rust local requis : tout via Docker, images **publiques** (`bash docker/build.sh` →
`todo-kit-rust:local` = rust:1-slim-bookworm, `todo-kit-visual:local` = node:22-bookworm + Chromium).
Volumes de cache cargo → compilations rapides après la première.

| Gate | Commande | Dépendance |
|---|---|---|
| `verify`/`plancher` (G1/G2/H1/C1) | `bash harness/verify.sh` | — |
| `contrat` (api.ts à jour) | `bash harness/run-contract.sh` | — |
| `unit`+`bdd` (domaine+application) | `bash harness/run-tests.sh` | — |
| `integration` (sqlx CQRS) | `bash harness/run-integration.sh` | PostgreSQL (auto) |
| `e2e` (serveur Actix réel) | `bash harness/e2e-smoke.sh` | PostgreSQL (auto) |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | PostgreSQL (auto) |
| `doc-vivante` (preuve de valeur) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | PostgreSQL (auto) |
| `chiffrement` (port `Chiffreur`, foyer#28) | `bash harness/e2e-chiffrement.sh` | PostgreSQL + OpenBao dev (auto) |
| **tous** | `bash harness/ci.sh` | PostgreSQL + OpenBao dev (auto) |

Un seul test : `bash harness/run-tests.sh` puis `cargo test toggle` en local.

## Persistance — choix enfichable : CQRS sqlx ↔ ORM sea-orm

Deux adaptateurs du **même port** `TodoRepository`, prouvés interchangeables par le gate
`integration` (rejoué sur les deux) :

- `CqrsTodoRepository` (`src/adapter/mod.rs`) — SQL pur (sqlx), lecture (`query_*`) et écriture
  (`cmd_*`) séparées ; schéma par migrations up/down.
- `OrmTodoRepository` (`src/adapter/orm.rs`) — **sea-orm** : entité de persistance `todo_entity::Model`
  mappée au domaine pur (sea-orm ne fuit pas hors de l'adaptateur).

> Le serveur HTTP utilise CQRS par défaut ; la permutabilité est démontrée par `integration`
> (dispatch statique en Rust → pas d'`async-trait` ni de `dyn` dans le domaine).

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
- Migrations `*.up.sql` + `*.down.sql` réversibles, SQL portable (pas de `SERIAL`).
- Regénérer `api.ts` après toute modif du contrat (`npm run gen:api`) ; ne pas l'éditer à la main.
- Un commit par étape ; mettre à jour le registre d'état du projet consommateur.
