# AGENTS.md — kit-php (PHP hexagonal vanilla, full-stack)

Contrat agent du **kit de référence Foyer**. Archétype **stateful full-stack** ; PHP hexagonal
« vanilla » (sans framework), front îlots Astro/Svelte, gates exécutés via Docker sur **images
publiques**. Le domaine d'exemple est **Todo** — pour un nouveau projet, l'agent remplace le
périmètre `Todo` par le sien (cf. `pilote/journeys/nouveau-projet.md`, étape B0).

**Marche direct après clone** : `bash docker/build.sh` (une fois) puis `bash harness/ci.sh`.
Ce kit fait partie de la famille de kits Foyer — voir `../KITS.md` (autres stacks à venir).

## Architecture et sa loi

Ordre des couches (dépendances vers l'intérieur — **le violer casse un invariant**) :

```
Domain (pur) → Application (use-cases, ports) → Adapter (PDO, horloge, uuid) → Http (routeur) → Frontend (îlot Svelte, client généré)
```

- `src/Domain/Todo/` — entité `Todo` (invariants dans le constructeur : libellé non vide),
  `TodoRules`, ports (`TodoRepository`, `Clock`, `IdGenerator`), exceptions. **Aucun `PDO`, SQL,
  framework ici** (vérifié par le gate H1).
- `src/Application/Todo/` — `CreateTodo`, `ListTodos`, `ToggleTodo`, `DeleteTodo`.
- `src/Adapter/Todo/` — adaptateurs enfichables (voir ci-dessous), `RealClock`, `UuidGenerator`.

### Persistance — choix enfichable (`TODO_PERSISTENCE`)

Même port `TodoRepository`, deux implémentations permutables (`src/Adapter/Todo/RepositoryFactory.php`) :

- `cqrs` (défaut) : `CqrsTodoRepository` — SQL pur (PDO), lecture/écriture séparées
  (`TodoQueries`/`TodoCommands`), schéma par migrations up/down SQL. **Aucun Composer requis.**
- `doctrine` : `DoctrineTodoRepository` — ORM Doctrine (entité de persistance `Doctrine/TodoRecord`
  mappée au domaine pur). Nécessite `composer install` (fait à froid par `ensure_vendor`).

Le gate `integration` rejoue le parcours sur **les deux** (12 assertions). Choix = point d'ADR
(`bmad/archetypes.md`), pas une question au PO (défaut annoncé, `pilote/defaults.md`).
Tester l'e2e sur Doctrine : `TODO_PERSISTENCE=doctrine bash harness/e2e-smoke.sh`.

> Adaptateur HTTP : `vanilla` (routeur maison) aujourd'hui ; **API Platform** à venir comme second
> choix (`TODO_HTTP=vanilla|apiplatform`), cf. `../KITS.md`.
- `src/Http/` + `src/Application.php` — `Request`/`Response`, routeur REST. **Seule couche qui
  traduit les exceptions du domaine en codes HTTP** (400 validation, 404 introuvable).
- `frontend-todos/` — îlot Svelte 5. **N'écrit jamais d'URL d'endpoint en dur** : passe par le
  client généré `public/generated/todos.client.js`.

## Contrat API — matérialisé, pas décrit

Source de vérité : `openapi/todos.openapi.json`. Le client JS est **généré** par
`harness/codegen-todos-client.php` → `public/generated/todos.client.js`. **Ne jamais éditer le
client à la main** : le gate `contrat` (C1 dans `verify.php`) échoue si le fichier diverge de la spec.

## Commandes (gates — noms stables, exit 0 = 🟢)

Aucun PHP local requis : tout passe par Docker, images **publiques** construites par
`bash docker/build.sh` → `todo-kit-php:local` (php:8.3-cli + pdo_mysql) et `todo-kit-visual:local`
(node:22-bookworm + Chromium). Les gates les construisent aussi à la volée si absentes.

| Gate | Commande | DB requise |
|---|---|---|
| `verify` / `plancher` (G1/G2/H1/C1) | `bash harness/run-verify.sh` | non |
| `unit` + `bdd` (domaine + application) | `bash harness/run-phpunit.sh` | non |
| `contrat` (codegen client) | `docker run --rm -v "$PWD":/app -w /app php:8.3-cli php harness/codegen-todos-client.php` | non |
| `integration` (PDO réel) | `bash harness/run-integration.sh` | **oui** |
| `e2e` (smoke HTTP) | `bash harness/e2e-smoke.sh` | **oui** |
| `visuel` (goldens Chromium) | `bash harness/run-visual.sh` (`VISUAL_MODE=capture` pour régénérer) | **oui** |
| `doc-vivante` (preuve de valeur, **non bloquant**) | `bash harness/run-demo.sh` → `harness/demo/vitrine/` | **oui** |
| **tous** | `bash harness/ci.sh` | **oui** |

Un seul test : `bash harness/run-phpunit.sh --filter TodoTest`.

### MySQL pour integration/e2e

```bash
docker run -d --name todo-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=todo \
  -p 13306:3306 mysql:8.0 --default-authentication-plugin=mysql_native_password
```

### Front (îlot)

```bash
cd frontend-todos && npm install && npm run build   # → public/todos-island/index.js
```

### Servir l'app en local

```bash
docker run --rm --network host -v "$PWD":/app -w /app \
  -e DB_HOST=127.0.0.1 -e DB_PORT=13306 -e DB_NAME=todo -e DB_USER=root -e DB_PASSWORD=root \
  todo-kit-php:local php -S 127.0.0.1:8080 -t public harness/dev-router.php
# → http://127.0.0.1:8080
```

## Règles de l'agent

- **Respecter l'ordre des couches** ; ne pas mettre de logique métier dans le routeur ni d'infra
  dans le domaine.
- **Ne jamais committer `src/config.php`** (secrets) — cf. `.gitignore`, gate G1.
- **Toute migration** `NNNN_*.up.sql` a son `*.down.sql` réversible, SQL portable (pas de
  `NOW()`/`AUTO_INCREMENT`) — gate G2.
- **Régénérer le client** après toute modif du contrat OpenAPI ; ne pas l'éditer à la main.
- Un **commit par étape conclusive** ; mettre à jour le registre d'état du projet consommateur
  (`PROJET.md`/`RETROFIT.md`/`RELEASE.md` à sa racine, cf. `pilote/state.template.md`).

## Gate `visuel` — outillé

- Harnais dans `harness/visual/` : Chromium Playwright (image `todo-visual`, Dockerfile inclus),
  parcours de référence rejoué, capture de `#todoSection` + page entière, comparaison au golden
  par `pixelmatch` (tolérance 0,5 %). Goldens versionnés dans `harness/visual/goldens/`.
- Rendu stabilisé (focus retiré, animations désactivées) pour éviter le bruit inter-runs.
- `VISUAL_MODE=capture bash harness/run-visual.sh` régénère les goldens après un **changement de
  rendu intentionnel** (à faire consciemment : c'est le point de bascule D2).
