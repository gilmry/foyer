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
- **Migrations tracées** : un outil du kit (`migrate up|down|status`) applique les migrations
  manquantes dans l'ordre et les trace ; aucune n'est rejouée, aucun harnais n'exécute un fichier
  SQL à la main.
- **Login sans privilège** : tous les gates se connectent à la base avec un login qui n'est ni
  administrateur ni propriétaire de l'instance, comme chez un hébergeur ; `integration` échoue sinon.
- **Déployable hors conteneur** : Docker sert aux gates, pas à la production. Chaque kit porte
  `deploiement/alwaysdata/` (script rejouable, guide) et un gate `deploiement` qui **répète le
  déploiement en local** sur une cible jetable avant d'aller chez l'hébergeur ; le smoke e2e vise
  n'importe quelle adresse par `E2E_BASE_URL` (contre un hébergeur réel : `E2E_PROFIL=public`,
  parcours allégé et espacé, un seul passage). Le pourquoi : `skills/deploiement-heberge-infogere.md`.

## Kits de la famille

| Kit | Front | Adaptateur HTTP (choix) | Persistance (choix) | DB | Authentification | Statut |
|---|---|---|---|---|---|---|
| **`kit-fastapi`** | Astro + Svelte | **FastAPI ↔ Starlette** ✅ | **CQRS SQL** ↔ **ORM SQLAlchemy** ✅ | PostgreSQL | session par cookie **et** jeton porteur, cloisonnement par propriétaire ✅ | ✅ **HTTP et persistance au choix** |
| **`kit-php`** | Astro + Svelte | **API Platform / Symfony** (référence) ↔ vanilla PHP ✅ | **CQRS SQL** ↔ **Doctrine** ✅ | MySQL / MariaDB | Symfony Security : session par cookie **et** jeton porteur, cloisonnement par propriétaire ✅ (vanilla : jeton porteur seul) | ✅ **HTTP et persistance au choix** |
| **`kit-actix`** | Astro + Svelte | **Actix** (Rust) | **CQRS SQL** (`sqlx`) ↔ **ORM** (`sea-orm`) ✅ | PostgreSQL | aucune (foyer#32) | ✅ **persistance au choix** |

### Déploiement infogéré (alwaysdata)

Chaque kit porte son guide dans `deploiement/alwaysdata/README.md`. **Deux niveaux de preuve, à ne
pas confondre** : la *répétition locale* (gate `deploiement` : le vrai script, joué deux fois sur
une cible jetable qui ressemble à l'hébergeur, puis le smoke e2e contre son adresse) et le
*déploiement réel* (le même smoke contre l'adresse publique).

Avec le jeton d'API de l'hébergeur, `deployer.sh` crée lui-même ce qui manque avant tout envoi —
l'utilisateur de base, la base, le site — après l'avoir annoncé, sans jamais modifier ni supprimer
l'existant ; `revenir.sh` remet la version précédente en service. Ces deux gestes ne sont prouvés
qu'en **répétition locale**, contre un faux serveur d'API (`harness/faux-hebergeur.py`) : non
prouvé chez l'hébergeur. Pour les seules créations, les mêmes appels d'API y ont été faits à la
main le 2026-11-18, pas par le script. Les preuves « chez l'hébergeur » du tableau ci-dessous
ont été obtenues avec le script d'alors, avant ces deux ajouts. Les fichiers
communs `hebergeur.sh`, `hebergeur.py` et `faux-hebergeur.py` sont identiques dans les trois kits.

| Kit | Montage chez l'hébergeur | Répétition locale (2026-11-18) | Chez l'hébergeur |
|---|---|---|---|
| **`kit-actix`** | programme utilisateur : binaire construit sur le poste (Debian 12), PostgreSQL géré | 🟢 `cqrs` et `orm`, écoute IPv6 | 🟢 **2026-11-18** : `cqrs` et `orm`, smoke public, script joué deux fois |
| **`kit-fastapi`** | **A** — programme utilisateur (uvicorn, recommandé) ; **B** — site Python (uWSGI + pont ASGI→WSGI). Dépendances préparées sur le poste, Python 3.12 de l'hébergeur | 🟢 8 combinaisons : 2 montages × 2 adaptateurs HTTP × 2 persistances | 🟢 **2026-11-18** : les 8 combinaisons, smoke complet contre l'adresse publique |
| **`kit-php`** | site PHP natif (Apache et PHP de l'hébergeur), racine sur `public/`, MariaDB gérée ; `vendor/` construit sur le poste | 🟢 4 combinaisons : 2 adaptateurs HTTP × 2 persistances, sur MariaDB | 🟢 **2026-11-18** : les 4 combinaisons, smoke public, script joué deux fois |

Relevé chez l'hébergeur le 2026-11-18, **en lecture seule** : Debian 12 (glibc 2.36), Python 3.12
qui accepte les paquets binaires `manylinux`, uWSGI 2.0, PHP 8.3 et 8.4 avec `pdo_mysql`. La
colonne de droite se remplit par un déploiement réel, sur un site et une base d'essai, suivi de
`E2E_PROFIL=public E2E_BASE_URL=https://… bash harness/e2e-smoke.sh` — **un seul passage** :
neuf parcours complets enchaînés ont fait bloquer l'adresse du poste par le frontal de l'hébergeur,
pour tous les sites du compte. Le déploiement de kit-fastapi a aussi trouvé un défaut que la
répétition locale ne montrait pas (un refus 413 perdu derrière le frontal), corrigé depuis.

> Chaque kit **réimplémente uniquement les adaptateurs** (HTTP + persistance) et le point d'entrée ;
> le Domaine et l'Application restent structurés à l'identique. Un même parcours de référence
> (créer → lister → basculer → supprimer une entité) sert de test d'acceptation du kit, rejoué
> **pour chaque combinaison d'adaptateurs**.

## Backlog (à faire)

- ✅ **Client `api.ts` typé** — fait pour les **trois** kits : `frontend-todos/scripts/gen-api.mjs`
  génère `frontend-todos/src/generated/api.ts` (interfaces des schémas OpenAPI + `createTodosClient`
  typé), bundlé dans l'îlot ; gate `contrat` (`run-contract.sh`) anti-drift.
- ✅ **Adaptateurs enfichables prouvés** — kit-php : HTTP vanilla↔API Platform **et** persistance
  CQRS↔Doctrine ; kit-fastapi : persistance CQRS↔ORM ; kit-actix : persistance CQRS↔sea-orm.
- ✅ **Authentification et cloisonnement par propriétaire** — kit-php (API Platform / Symfony
  Security) et kit-fastapi (FastAPI et Starlette) ; décision dans `docs/adr/ADR-001-authentification.md`
  de chaque kit. **kit-actix** reste à faire (foyer#32).
- ✅ **Déploiement réel chez l'hébergeur** — les trois kits sont prouvés contre une adresse
  publique (2026-11-18, sites et bases d'essai). Reste, par kit, ce que son guide marque « non
  prouvé chez l'hébergeur » (pannes provoquées, arrêt pour inactivité, parcours complet du smoke).
- **kit-actix · adaptateur HTTP alternatif** — un second choix (ex. Axum) pour l'axe HTTP côté Rust.

## Choix du kit par le pilote (sans friction pour le PO)

L'archétype et la pile sont des **défauts annoncés**, pas des questions au PO non-développeur
(cf. `pilote/defaults.md`). L'agent choisit le kit selon l'archétype et le contexte
(langage déjà présent, préférence d'équipe si exprimée en clair), l'**annonce en une phrase**,
et continue. Le PO ne tranche que le **métier**.

## Ajouter un kit (contrat minimal)

Un nouveau kit est « prêt » quand, sur un clone frais : `bash docker/build.sh` puis
`bash harness/ci.sh` passent **tous les gates au vert jusqu'à la preuve de valeur** (gate
`deploiement` compris), avec un
domaine d'exemple trivial (une entité, 4 opérations) et les mêmes **noms de gates** que
`pilote/gates/README.md`.
