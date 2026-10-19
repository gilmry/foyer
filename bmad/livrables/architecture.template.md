# Architecture Technique — [PROJET]

*Livrable de l'Architecte · TOGAF Phases C-D. Organisé par les sept couches ; à vérifier intégralement.*

## Vue d'ensemble
[Diagramme ASCII : anneaux concentriques, dépendances vers l'intérieur.]

## Couche 1 — Domain *(SOLID : SRP, DIP — racine : Ubuntu)*
[Entités, value objects, invariants codés dans les constructeurs. Aucune dépendance vers l'extérieur.]

## Couche 2 — Application *(ISP, OCP, DRY)*
[Ports (interfaces), use cases, DTOs. Orchestration sans logique métier.]

## Couche 3 — Infrastructure backend *(LSP, DIP)* · *persistance : stateful uniquement*
[Adaptateurs, handlers, **middleware dans les adapters API (FastAPI)**. Persistance : SQLAlchemy ORM **ou** CQRS SQL pur sur PostgreSQL → choix tracé en ADR.]

## Couche 4 — Frontend *(hexagonale light)* · *full-stack uniquement*
[Pages Astro statiques · îlots Svelte 5 (runes) · APIs TS. Composants par bounded context.]

## Couche 5 — IaC
- Conteneurs / VM · salt-ssh idempotent (config + durcissement) · GitOps (branche GitFlow = source de vérité) · build distroless en prod · rollback si tests échouent
- Progression YAGNI : activer chaque brique quand le besoin réel l'exige
- **Mapping ISO 27001 → IaC** :
  | Contrôle ISO 27001 | Mise en œuvre IaC |
  |---|---|
  | A.8 (gestion des actifs) | [inventaire déclaratif] |
  | A.9 (contrôle d'accès) | [RBAC, secrets] |
  | A.12 (sécurité d'exploitation) | [durcissement salt, logs] |
  | … | … |

## Couche 6 — CI/CD
[Jobs par couche · hooks Git locaux (DRY avec la CI) · au plus tard en pre-push : CI complète.]

## Couche 7 — Monitoring & Sécurité
[Observabilité (Prometheus/Loki) · AlertManager comme trigger du platform engineer · détection.]

**Plan de gestion des vulnérabilités** : livrable séparé, `plan-vulnerabilites.template.md` (CyFun ID.RA-08.1 ★I).

## Contrat API (OpenAPI) · *API-first : écrit avant le code, versionné*
[Le contrat est la source de vérité ; rupture = point irréversible, validation humaine.]

## Glossaire DDD → mapping code
## Stratégie de tests
[Pyramide TDD/BDD · couverture cible par couche · Test-Driven Emergence (BDD↔E2E↔doc vivante).]

## Classes de tests (4×N — hérité de `skills/cycle-dev.md`)
| Classe | BDD (Gherkin) | TDD (unitaire) | Conditionnement archétype |
|---|---|---|---|
| `@happy` | Chemin nominal | Invariants constructeurs, use case nominal | Tous |
| `@negative` | Entrées invalides | `Result::Err` attendu, validation DTOs | Tous |
| `@edge` | Bornes (vide, max, concurrence) | Concurrence, transitions d'état, propriété-based | **stateless** : property-based ; **stateful** : concurrence + DB |
| `@security` | Abus, injection, autorisation | Isolation tenant, injection SQL, XSS | **full-stack** : CSP/XSS Svelte ; **API-first** : abus contrat |
## API · Sécurité & RGPD

## ADR (Architecture Decision Records)
### ADR-001 — Hexagonale + SOLID *(racine : écologie des savoirs)*
### ADR-002 — TDD + BDD + Documentation Vivante *(racine : sept générations)*
### ADR-003 — DDD ubiquitous language → mapping code *(racine : Ubuntu)*
### ADR-00x — [Choix de persistance : SQLAlchemy vs CQRS — irréversible, validé par l'humain]
### ADR-00x — [Mapping branche GitFlow → environnement — irréversible, validé par l'humain]

*Chaque ADR : décision · contexte · alternatives écartées · conséquences · (racine sagesse si éclairant).*

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0). Source : [`github.com/gilmry/manifest`](https://github.com/gilmry/manifest).*
