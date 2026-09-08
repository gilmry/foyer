# Kits Foyer — famille de squelettes prêts à piloter

> Un **kit** = un squelette exécutable, **architecture hexagonale**, avec harnais de gates et
> preuve de valeur, que le pilote instancie en Phase B (cf. `pilote/journeys/nouveau-projet.md`
> étape B0). Objectif : **cloner → ça marche direct**, puis remplacer le domaine d'exemple par le
> métier voulu. Tous les kits partagent la **même loi** (ordre des couches, contrat matérialisé,
> triple harnais E2E + visuel + doc vivante) ; seules la **pile** et les **adaptateurs** changent.

## Le principe : tout adaptateur est un CHOIX enfichable

Le cœur (Domaine + Application) est **pur** et **stable** ; il ne connaît ni le framework HTTP ni
la techno de stockage. Chaque **port** admet donc **plusieurs adaptateurs interchangeables**, que
l'on sélectionne par configuration **sans toucher une ligne de métier** :

- **Adaptateur HTTP** — choix du framework d'exposition : `FastAPI`, `vanilla` (routeur maison),
  `API Platform`, `Actix`, `Flask`… Le port, ce sont les **use-cases** ; le framework n'est qu'un
  traducteur requête↔use-case.
- **Adaptateur de persistance** — choix du paradigme de stockage : **CQRS SQL pur** (commandes/
  requêtes séparées, migrations `up`/`down`) **ou ORM** (SQLAlchemy, Doctrine…). Même port
  `TodoRepository`, implémentations permutables. Choix tracé en **ADR** (`bmad/archetypes.md`),
  jamais une question au PO non-dev (défaut annoncé, `pilote/defaults.md`).

Chaque kit **livre au moins deux choix par adaptateur** et le prouve : la même suite de gates passe
au vert quel que soit l'adaptateur sélectionné (ex. `integration` rejoué sur CQRS **et** ORM).

## Invariants communs à tous les kits (la partie qui ne change jamais)

- **Architecture hexagonale** : `Domain (pur) → Application (use-cases + ports) → Adapter → Http → Frontend`.
  Le domaine et l'application ne connaissent **aucune** techno (ni ORM, ni framework, ni SQL).
- **Adaptateur HTTP soigné** : désérialisation stricte, exceptions du domaine traduites en codes
  HTTP (400/404/409…), jamais de logique métier dans le routeur — **quel que soit le framework**.
- **Adaptateur de persistance soigné** : un **port** de repository côté domaine, ≥ 2 implémentations
  côté adapter (CQRS SQL ↔ ORM) ; migrations **réversibles** (`up`/`down`), mapping ligne↔entité isolé.
- **Contrat API matérialisé** : OpenAPI = source de vérité → **client généré** consommé par le
  front (jamais d'URL en dur), contract tests (gate `contrat` anti-drift).
- **Frontend îlots-first** : Astro pour le squelette + îlots Svelte pour l'interactivité, découplés
  du back par le client généré.
- **Triple harnais sur un seul parcours de référence** : E2E (correctness) + visuel (apparence,
  goldens) + doc vivante (preuve de valeur, vidéo + vitrine).
- **Autonomie** : gates exécutés sur **images Docker publiques** (aucune image privée) ; `docker/build.sh`.

## Kits de la famille

| Kit | Front | Adaptateur HTTP (choix) | Persistance (choix) | DB | Statut |
|---|---|---|---|---|---|
| **`kit-fastapi`** | Astro + Svelte | **FastAPI** (vanilla ASGI à venir) | **CQRS SQL** ↔ **ORM SQLAlchemy** | PostgreSQL | ✅ **disponible** |
| **`kit-php`** | Astro + Svelte | **vanilla PHP ↔ API Platform** ✅ | **CQRS SQL** ↔ **Doctrine** ✅ | MySQL | ✅ **HTTP et persistance au choix** · CI verte |
| **`kit-actix`** | Astro + Svelte | **Actix** (Rust) | **CQRS SQL** (`sqlx`) ✅ (ORM `sea-orm` backlog) | PostgreSQL | ✅ **disponible** · CI verte |

> Chaque kit **réimplémente uniquement les adaptateurs** (HTTP + persistance) et le point d'entrée ;
> le Domaine et l'Application restent structurés à l'identique. Un même parcours de référence
> (créer → lister → basculer → supprimer une entité) sert de test d'acceptation du kit, rejoué
> **pour chaque combinaison d'adaptateurs**.

## Backlog (à faire)

- ✅ **Client `api.ts` typé** — fait pour `kit-php` et `kit-fastapi` : `frontend-todos/scripts/gen-api.mjs`
  génère `frontend-todos/src/generated/api.ts` (interfaces des schémas OpenAPI + `createTodosClient`
  typé), bundlé dans l'îlot ; gate `contrat` (`run-contract.sh`) anti-drift. À reprendre dans `kit-actix`.
- **kit-fastapi · adaptateur HTTP alternatif** — un second choix (ex. ASGI nu / Starlette) pour prouver
  la permutabilité HTTP comme pour la persistance.
- **`kit-actix` · second adaptateur de persistance ORM** — l'adaptateur `sqlx` CQRS est fait ✅ ;
  ajouter `sea-orm` comme second choix pour prouver la permutabilité, comme kit-php (CQRS↔Doctrine)
  et kit-fastapi (CQRS↔ORM).

## Choix du kit par le pilote (sans friction pour le PO)

L'archétype et la pile sont des **défauts annoncés**, pas des questions au PO non-développeur
(cf. `pilote/defaults.md`). L'agent choisit le kit selon l'archétype et le contexte
(langage déjà présent, préférence d'équipe si exprimée en clair), l'**annonce en une phrase**,
et continue. Le PO ne tranche que le **métier**.

## Ajouter un kit (contrat minimal)

Un nouveau kit est « prêt » quand, sur un clone frais : `bash docker/build.sh` puis
`bash harness/ci.sh` passent **tous les gates au vert jusqu'à la preuve de valeur**, avec un
domaine d'exemple trivial (une entité, 4 opérations) et les mêmes **noms de gates** que
`pilote/gates/README.md`.
