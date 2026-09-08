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
| **tous** | `bash harness/ci.sh` | PostgreSQL (auto) |

Un seul test : `bash harness/run-tests.sh` puis `cargo test toggle` en local.

## Persistance — CQRS sqlx (ORM sea-orm en second choix, backlog)

`CqrsTodoRepository` implémente le port `TodoRepository` en SQL pur (sqlx), lecture (`query_*`) et
écriture (`cmd_*`) séparées ; schéma par migrations up/down. Un second adaptateur ORM (`sea-orm`)
est au backlog de `../KITS.md` pour démontrer la permutabilité comme dans kit-php/kit-fastapi.

## Règles de l'agent
- Respecter l'ordre des couches ; jamais d'infra dans domaine/application (gate H1).
- Migrations `*.up.sql` + `*.down.sql` réversibles, SQL portable (pas de `SERIAL`).
- Regénérer `api.ts` après toute modif du contrat (`npm run gen:api`) ; ne pas l'éditer à la main.
- Un commit par étape ; mettre à jour le registre d'état du projet consommateur.
