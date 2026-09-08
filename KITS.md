# Kits Foyer — famille de squelettes prêts à piloter

> Un **kit** = un squelette exécutable, **architecture hexagonale**, avec harnais de gates et
> preuve de valeur, que le pilote instancie en Phase B (cf. `pilote/journeys/nouveau-projet.md`
> étape B0). Objectif : **cloner → ça marche direct**, puis remplacer le domaine d'exemple par le
> métier voulu. Tous les kits partagent la **même loi** (ordre des couches, contrat matérialisé,
> triple harnais E2E + visuel + doc vivante) ; seules la **pile** et les **adaptateurs** changent.

## Invariants communs à tous les kits (la partie qui ne change jamais)

- **Architecture hexagonale** : `Domain (pur) → Application (use-cases + ports) → Adapter → Http → Frontend`.
  Le domaine et l'application ne connaissent **aucune** techno (ni ORM, ni framework, ni SQL).
- **Adaptateur HTTP soigné** : routeur explicite, désérialisation stricte, exceptions du domaine
  traduites en codes HTTP (400/404/409…), jamais de logique métier dans le routeur.
- **Adaptateur de persistance soigné** : un **port** de repository côté domaine, une implémentation
  côté adapter ; migrations **réversibles** (`up`/`down`), SQL portable, mapping ligne↔entité isolé.
- **Contrat API matérialisé** : OpenAPI = source de vérité → **client généré** consommé par le
  front (jamais d'URL en dur), contract tests (gate `contrat` anti-drift).
- **Frontend îlots-first** : Astro pour le squelette + îlots Svelte pour l'interactivité, découplés
  du back par le client généré.
- **Triple harnais sur un seul parcours de référence** : E2E (correctness) + visuel (apparence,
  goldens) + doc vivante (preuve de valeur, vidéo + vitrine).
- **Autonomie** : gates exécutés sur **images Docker publiques** (aucune image privée) ; `docker/build.sh`.

## Kits de la famille

| Kit | Front | Back | Persistance | Adaptateurs clés | Statut |
|---|---|---|---|---|---|
| **`kit-php`** | Astro + Svelte | **PHP 8.3 vanilla** | **MySQL** (PDO) | `PdoTodoRepository`, routeur PHP, codegen JS | ✅ **disponible** (ce dépôt) |
| `kit-fastapi` | Astro + Svelte | **FastAPI** (Python) | **PostgreSQL** | repo SQLAlchemy/SQL pur, routeur FastAPI, OpenAPI natif | 🔜 à venir |
| `kit-actix` | Astro + Svelte | **Actix** (Rust) | **PostgreSQL** | repo `sqlx`, extractors Actix, OpenAPI généré | 🔜 à venir |

> Chaque futur kit **réimplémente uniquement les adaptateurs** (Http + persistance) et le point
> d'entrée ; le Domaine et l'Application restent structurés à l'identique. Un même parcours de
> référence (créer → lister → basculer → supprimer une entité) sert de test d'acceptation du kit.

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
