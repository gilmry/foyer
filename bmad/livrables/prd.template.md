# PRD — [PROJET]

*Livrable du Product Manager · TOGAF Phases B-C. Chaque exigence se rattache à une capacité du Brief (traçabilité).*

## 1. Résumé exécutif
## 2. Objectifs produit (mesurables)
## 3. Périmètre — MVP / Hors scope
## 4. Glossaire DDD (repris et figé depuis le Brief)
## 5. Bounded contexts → modules

## 6. Exigences fonctionnelles
### Module : [= bounded context]
#### FR-001 — [Titre]
- **En tant que** [persona] **je veux** [capacité] **afin de** [bénéfice]
- **Critères d'acceptation (Gherkin)** :
  - `Étant donné … Quand … Alors …`
- **Capacité du Brief rattachée** : [§7.x]

## 7. Exigences non-fonctionnelles
[Performance · sécurité · disponibilité · sobriété · conformité — chacune mesurable.]

## 8. Frontend UX
- **Parcours par persona** : [étapes]
- **Arborescence des pages** (wireframes textuels)
- **i18n** : [langues, stratégie]

## 9bis. Contrat API (OpenAPI) · *API-first : de premier rang, écrit avant le code*
[Endpoints, schémas, codes d'erreur, versioning. Source de vérité des contract tests.]

## 9. Documentation Vivante (Test-Driven Emergence) · *full-stack : E2E cross-stack ; API-first : contract tests*
- **Flux critiques à couvrir en E2E** : [liste]
- **Alignement BDD ↔ E2E** : chaque flux critique = un scénario BDD = un test E2E

## 10. Modèle de données (entités DDD → tables PostgreSQL) · *stateful uniquement*
## 11. Intégrations externes
## 12. Contraintes et hypothèses
## 13. Critères de succès MVP
