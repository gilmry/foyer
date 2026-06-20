# Archétypes de composant — conditionnement des délivrables

*Référence partagée par tous les personas BMAD (DRY). L'archétype est déclaré en Étape 0 et sélectionne **quelles couches** sont en scope et **quelles sections** de chaque délivrable s'appliquent. Un composant hors archétype produit du bruit — la recherche montre qu'un contexte gonflé dégrade l'agent.*

## Deux facettes combinables

- **Facette état** : **stateless** (aucun état persisté — transform, gateway, fonction pure) ↔ **stateful** (possède un état persisté).
- **Facette surface** : **API-first** (le contrat est le produit, consommateurs externes) ↔ **full-stack** (front + back, les sept couches).

Combinaisons courantes : *stateless API-first* (transform exposé), *stateful API-first* (service métier consommé par des tiers), *stateful full-stack* (l'app canonique). Le superviseur déclare la combinaison en Étape 0.

## Ce que chaque archétype met en scope

**Stateless** — Domain léger (value objects, fonctions pures, pas d'invariant sur un état persisté) · **pas de couche persistance** (ni ORM/CQRS, ni migrations, ni entités→tables) · l'enjeu central est l'**idempotence et la pureté** (mêmes entrées → mêmes sorties) · tests : property-based, `@edge` sur les entrées, pas de fixtures DB.

**Stateful** — Domain complet, **invariants codés dans les constructeurs** · couche persistance requise (**décision ORM SQLAlchemy vs CQRS SQL pur**, tracée en ADR) · migrations, transactions, **concurrence et cohérence** · tests : transitions d'état, intégration DB, `@edge` sur la concurrence · point irréversible propre : **migration de schéma**.

**API-first** — le **contrat API (OpenAPI/AsyncAPI) est un délivrable de premier rang, écrit avant le code** · exigences PRD exprimées en endpoints · **versioning et rétro-compatibilité** · BDD au niveau contrat, **contract tests** · couche Frontend : N/A · point irréversible propre : **rupture de contrat / changement de version majeure**.

**Full-stack** — **les sept couches**, dont Frontend (pages Astro statiques + îlots Svelte 5) · **E2E cross-stack + Documentation Vivante** (flux critiques filmés) · point irréversible : cumul (schéma + contrat + mapping branche→env).

## Matrice d'applicabilité des sections

`✓` requis · `○` optionnel/si la facette état l'impose · `—` hors scope

| Section de délivrable | stateless | stateful | API-first | full-stack |
|---|---|---|---|---|
| Domain — invariants métier | ○ | ✓ | ○ | ✓ |
| Modèle de données (entités → tables), migrations | — | ✓ | ○ | ✓ |
| Idempotence / pureté | ✓ | ○ | ○ | ○ |
| Concurrence / cohérence / transactions | — | ✓ | ○ | ✓ |
| **Contrat API (OpenAPI)** + versioning | ○ | ○ | ✓ | ✓ |
| Frontend UX / îlots / arborescence pages | — | — | — | ✓ |
| Couche Frontend (architecture) | — | — | — | ✓ |
| E2E cross-stack + Documentation Vivante | ○ | ○ | contract tests | ✓ |
| Couches Application · IaC · CI/CD · Monitoring | ✓ | ✓ | ✓ | ✓ |

## Conséquence pour chaque persona

- **Analyste** : nomme l'archétype dès le Brief (§13 Contraintes) ; l'estimation point 0 en dépend (un stateless converge en moins de tours qu'un full-stack).
- **Product Manager** : pour API-first, exprime les exigences en endpoints et **produit le contrat OpenAPI** ; saute §10 (modèle de données) si stateless.
- **Architecte** : n'instancie que les couches en scope ; pour API-first, le contrat précède le code ; trace le point irréversible propre à l'archétype.
- **Scrum Master** : la **story habilitante** varie (stateless : pas de harnais DB ; API-first : ajoute le harnais de contract testing).
- **Validateur** : vérifie la **conformité à l'archétype** — une section hors scope présente, ou une section requise absente, est une incohérence.
