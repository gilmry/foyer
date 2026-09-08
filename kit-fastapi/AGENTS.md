# AGENTS.md — kit-fastapi (FastAPI hexagonal, full-stack)

Contrat agent du **kit de référence Foyer** en Python. Archétype **stateful full-stack** ;
front îlots Astro/Svelte ; gates via Docker sur **images publiques**. Domaine d'exemple **Todo**
— pour un nouveau projet, l'agent remplace le périmètre `Todo` par le sien.

**Marche direct après clone** : `bash docker/build.sh` puis `bash harness/ci.sh`.
Fait partie de la famille de kits Foyer — voir `../KITS.md`.

## Architecture et sa loi

```
Domain (pur)  →  Application (use-cases + ports)  →  Adapter (HTTP / persistance)  →  Frontend (îlot)
```

- `app/domain/todo/` — entité `Todo` (invariants dans le constructeur), `rules`, **ports**
  (`TodoRepository`, `Clock`, `IdGenerator`), exceptions. **Python pur** : aucun FastAPI, Pydantic,
  psycopg ni SQLAlchemy (vérifié par le gate H1).
- `app/application/todo/` — `CreateTodo`, `ListTodos`, `ToggleTodo`, `DeleteTodo`. Ne dépend **que**
  du domaine.
- `app/adapter/todo/` — implémentations concrètes (voir « adaptateurs enfichables » ci-dessous).
- `app/http/api.py` — **adaptateur HTTP FastAPI** : routes → use-cases, exceptions domaine → codes
  HTTP (400/404), désérialisation stricte (Pydantic `extra='forbid'`). C'est le SEUL fichier qui
  connaît FastAPI.
- `frontend-todos/` — îlot Svelte ; **n'écrit jamais d'URL en dur**, passe par le client généré
  `public/generated/todos.client.js` (issu de `openapi/todos.openapi.json`, lui-même dumpé de FastAPI).

## Adaptateurs enfichables (le cœur ne change jamais)

- **Persistance** — choix via `TODO_PERSISTENCE` :
  - `cqrs` (défaut) : `cqrs_todo_repository.py` — SQL pur (psycopg), séparation commandes/requêtes,
    schéma par **migrations up/down SQL** (`database/migrations/`).
  - `orm` : `orm_todo_repository.py` — **SQLAlchemy**, schéma par métadonnées ORM ou par les mêmes
    migrations.
  - Les deux implémentent le **même port** `TodoRepository` (`app/adapter/todo/factory.py`). Choix
    = point d'ADR (cf. `bmad/archetypes.md`), pas une question au PO (défaut annoncé, `pilote/defaults.md`).
- **HTTP** — FastAPI ici ; le port étant les use-cases, un autre adaptateur (Flask, ASGI nu…)
  se brancherait sans toucher domaine/application. Voir `../KITS.md` (principe d'agnosticité).

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun Python local requis : tout via Docker, images **publiques** (`bash docker/build.sh`).

| Gate | Commande | Dépendance |
|---|---|---|
| `verify`/`plancher` (G1/G2/H1/C1) | `bash harness/run-verify.sh` | — |
| `unit`+`bdd` (domaine+application) | `bash harness/run-pytest.sh` | — |
| `integration` (CQRS **et** ORM) | `bash harness/run-integration.sh` | PostgreSQL (auto) |
| `e2e` (uvicorn réel) | `bash harness/e2e-smoke.sh` | PostgreSQL (auto) |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | PostgreSQL (auto) |
| `doc-vivante` (preuve de valeur) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | PostgreSQL (auto) |
| **tous** | `bash harness/ci.sh` | PostgreSQL (auto) |

Un seul test : `bash harness/run-pytest.sh -k test_toggle`.
Tester l'e2e sur l'ORM : `TODO_PERSISTENCE=orm bash harness/e2e-smoke.sh`.

## Contrat — matérialisé, pas décrit

FastAPI **est** la source du contrat. `harness/dump_openapi.py` écrit `openapi/todos.openapi.json` ;
`harness/codegen_client.py` en génère le client JS. Le gate `verify` (C1) échoue si le client
diverge du contrat. **Ne jamais éditer le client à la main.**

## Règles de l'agent
- Respecter l'ordre des couches ; jamais d'infra dans domaine/application (gate H1).
- Migrations `*.up.sql` + `*.down.sql` réversibles, SQL portable (pas de `NOW()`/`SERIAL`).
- Regénérer contrat + client après toute modif des routes/schémas.
- Un commit par étape ; mettre à jour le registre d'état du projet consommateur.
