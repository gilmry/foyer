# Skill — Convergence IaC

*Skill enfant de la primitive `../Boucle-de-retroaction.md`. Ici l'outil qui **objective** n'est pas un test pré-écrit mais **l'état observé** : on applique, on ré-applique, l'absence de diff prouve la convergence (idempotence). Invoque `gates.md`. Lit l'archétype (`../bmad/archetypes.md`).*

---

## Le cercle pour l'infrastructure

- **Conception** — tu **déclares l'état désiré** : états salt idempotents (config + durcissement) ; pour l'app, **la branche GitFlow déclare la cible**.
- **Construction** — tu **appliques** : `salt-ssh` pour la config/durcissement ; le réconciliateur GitOps pour l'app.
- **Résultat** — l'état a changé.
- **Évaluation** — tu **observes la convergence** : ré-appliquer ne produit **aucun diff** (idempotence prouvée) ; puis **security gate** (durcissement vérifié, mapping ISO 27001) ; puis tests de déploiement.
- **Amélioration** — tu ajustes la déclaration et tu reboucles jusqu'à stabilité.

Le GitOps *est* la primitive en continu : un réconciliateur compare en boucle l'état déclaré à l'état réel. Une **alerte AlertManager** = une divergence qui ré-entre dans le cercle (et déclenche le platform engineer).

## Deux moteurs

**Config + durcissement** — `salt-ssh`, **idempotent**. Cible : conteneur **ou** VM. La ré-exécution sans effet est la preuve d'Évaluation.

**Déploiement applicatif** — **GitOps**, la **branche GitFlow est la source de vérité**. Build **distroless** en production (surface d'attaque minimale). **Rollback automatique** si les tests de déploiement échouent.

## Conditionnement par archétype

- **stateless** — infra simple, pas de provisionnement DB ni de sauvegardes.
- **stateful** — provisionnement DB, **sauvegardes**, **migrations de schéma = irréversible** (validation humaine), procédures de restauration testées.
- **API-first** — exposition via passerelle/contrat ; quotas, versions d'API en parallèle.
- **full-stack** — hébergement statique des pages Astro (CDN/edge) + backend conteneurisé.

## Points irréversibles

Le **durcissement serveur**, le **mapping branche → environnement**, la **migration de schéma**, la **rotation de secret** sont coûteux ou impossibles à défaire. Principe : *louer le réversible, posséder l'irréversible ; au doute, traiter comme irréversible.* À chacun de ces points : tu présentes le motif et l'état, **l'humain valide**. *« Pourrai-je en répondre, et devant qui ? »*

## Condition de sortie

On reboucle **tant que la convergence n'est pas stable** ou qu'une gate bloque. On sort **quand le ré-apply est sans diff et les gates vertes**. En déploiement, **rollback** si les tests post-déploiement échouent — la sortie n'est jamais un état non vérifié.

## Coût

**Peu de tokens, fort wall-clock** : la convergence se prouve par des cycles d'application et d'observation, pas par génération. C'est l'asymétrie assumée de ce terrain (le coût dominant est superviseur, pas modèle).

---

*Registre guidance ; le blocage (gate, rollback, hooks) est l'enforcement. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
