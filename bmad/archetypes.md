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

**Full-stack** — **les sept couches**, dont Frontend (**îlots-first** — Astro pour le squelette, îlots Svelte pour l'interactivité — découplé du backend via le client généré) · **E2E cross-stack (gate) + Documentation Vivante (preuve de valeur) + régression visuelle (apparence)** : un parcours de référence rejoué à la vitesse (gate) **et** en cadence 1 action/1s (galerie + vidéo, rapport non bloquant) **et** en goldens (bloquant à la bascule de rendu D2), sans dette de doc — voir `../skills/contrat-api.md` (correctness), `../skills/documentation-vivante.md` (valeur + 3e harnais) et `../skills/migration-projet-existant.md` (D1/D2, règle de sobriété) · point irréversible : cumul (schéma + contrat + mapping branche→env). **Le contrat API doit être matérialisé, pas seulement décrit** — annotation exhaustive + client généré + désérialisation stricte + contract tests CI, voir `../skills/contrat-api.md` (skill né d'un incident réel : contrat non matérialisé → NO-GO en production).

## Matrice d'applicabilité des sections

`✓` requis · `○` optionnel/si la facette état l'impose · `—` hors scope

| Section de délivrable | stateless | stateful | API-first | full-stack |
|---|---|---|---|---|
| Domain — invariants métier | ○ | ✓ | ○ | ✓ |
| Modèle de données (entités → tables), migrations | — | ✓ | ○ | ✓ |
| Idempotence / pureté | ✓ | ○ | ○ | ○ |
| Concurrence / cohérence / transactions | — | ✓ | ○ | ✓ |
| **Contrat API (OpenAPI)** + versioning — *matérialisé, pas décrit* ¹ | ○ | ○ | ✓ | ✓ |
| Frontend UX / îlots / arborescence pages | — | — | — | ✓ |
| Couche Frontend (architecture) | — | — | — | ✓ |
| E2E cross-stack (gate) + Preuve de valeur (doc vivante) ² | ○ | ○ | contract tests | ✓ |
| Couches Application · IaC · CI/CD · Monitoring | ✓ | ✓ | ✓ | ✓ |

¹ Un `✓` ici n'est acquis que si les quatre éléments de `../skills/contrat-api.md` sont en place (annotation exhaustive, client généré, désérialisation stricte, contract tests CI) — une section PRD §9bis en prose sans ces mécanismes reste un `—` de facto, quelle que soit la case cochée.

² Un `✓` ici n'est acquis que si le parcours de référence est **une source de vérité partagée** rejouée par **deux harnais** (E2E gate + preuve de valeur cadencée) et verrouillé par un invariant anti-dette — `../skills/documentation-vivante.md`. Une liste de « flux à couvrir » en prose reste un `—` de facto.

## Conséquence pour chaque persona

- **Analyste** : nomme l'archétype dès le Brief (§13 Contraintes) ; l'estimation point 0 en dépend (un stateless converge en moins de tours qu'un full-stack).
- **Product Manager** : pour API-first ou full-stack, exprime les exigences en endpoints et **produit le contrat OpenAPI** — §9bis doit nommer l'outil d'annotation et l'outil de codegen, pas seulement décrire des conventions REST (`../skills/contrat-api.md`) ; saute §10 (modèle de données) si stateless.
- **Architecte** : n'instancie que les couches en scope ; pour API-first et full-stack, le contrat précède le code et sa **matérialisation fait l'objet d'un ADR dédié** avant la Phase 1 (annotation, codegen, `deny_unknown_fields`, contract tests) — traité avec le même sérieux que la migration de schéma, voir `../skills/contrat-api.md` ; trace le point irréversible propre à l'archétype.
- **Scrum Master** : la **story habilitante** varie (stateless : pas de harnais DB ; API-first et full-stack : ajoute le harnais de contract testing **comme sous-story non optionnelle du Sprint 0**, jamais reléguée en GO-forward — `../skills/contrat-api.md`).
- **Validateur** : vérifie la **conformité à l'archétype** — une section hors scope présente, ou une section requise absente, est une incohérence ; pour API-first/full-stack, vérifie que le contrat est **matérialisé** (les 4 éléments), pas seulement décrit.
