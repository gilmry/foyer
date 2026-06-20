# Skill — Bootstrap & délivrabilité (la story habilitante aboutie)

*Skill du dispositif. C'est la **story habilitante** (Sprint 0) portée à son aboutissement : non plus « installer le harnais de tests », mais **rendre tout reproductible depuis un clone**. Hérite de `../Boucle-de-retroaction.md` ; compose `enforcement.md` et `convergence-iac.md`. À l'échelle programme, c'est l'*architectural runway* de SAFe.*

> **La cible.** Un `git clone` neuf + **une commande d'agent** reconstruit l'intégralité : les quatre environnements, les postes superviseur, l'enforcement — **idempotent** (re-lancer = même état). Sans elle, il n'y a pas de capacité de boucler ; elle **précède** toute story métier (point de concours du Gantt).

> **Pourquoi c'est du *répondre-de*.** On ne peut répondre que d'un environnement qu'on sait **reconstruire**. La reproductibilité n'est pas du confort, c'est la condition de l'imputabilité : un environnement non reproductible est une dépendance subie non assumée.

---

## Les six couches à déclarer dans le dépôt (tout est code)

1. **Versions d'outils** — `.tool-versions` / `mise` / `Nix`. Tout figé (Rust, Node, Python, CLI) : superviseurs *et* CI ont des outils identiques. Élimine le « ça marche chez moi ».
2. **Poste superviseur** — devcontainer / `docker-compose` / `Makefile`. `make up` monte la stack complète (proxy + DB + backend + S3). Le superviseur clone et boucle en minutes.
3. **Les quatre environnements** — `dev` / `integration` (test) / `staging` / `production`, via IaC (`convergence-iac.md`) : provisioning (Terraform), config+durcissement (salt idempotent), déploiement (GitOps). **Mapping branche GitFlow → environnement** déclaré.
4. **L'enforcement substrat** — installer les hooks git, configurer la CI, **poser la protection de branche** (API), définir la politique de sandbox/egress. Voir `enforcement.md`.
5. **La config agent** — `AGENTS.md` (ou champ `instructions`), `opencode.json` (permissions), les fichiers du dispositif, et les défauts d'organisation via `.well-known/opencode`.
6. **Références de secrets** — Vault / sealed-secrets : le bootstrap câble les **références**, jamais les secrets eux-mêmes (rotation par réversibilité, cf. doctrine).

## L'idempotence, comme la convergence IaC

Le bootstrap est une boucle de convergence : on applique, on ré-applique, l'absence de diff prouve l'état. Re-lancer un clone existant ne casse rien. C'est `convergence-iac.md` appliqué à l'amorçage lui-même.

## Les points irréversibles du bootstrap

Créer la **production**, poser la **protection de branche**, le **mapping branche→prod**, provisionner un **datastore** : coûteux à défaire → l'agent présente le plan, **l'humain valide** (et ces gestes s'enforcent au **substrat**, pas dans l'agent — anneau 3). Le bootstrap lui-même passe par les gates.

## Conditionnement

- **Archétype** : un *stateless* bootstrap moins (pas de datastore, pas de migrations) ; un *full-stack* monte les quatre environnements + build frontend + E2E cross-stack.
- **Échelle** : dev/test en `compose` ; staging/prod selon le tier (`compose` → `K3s` → `K8s`, cf. l'abaque — le tier pèse sur mémoire *et* coût).

## Definition of Done de la story de délivrabilité

Un clone neuf + la commande d'agent →  (1) les quatre environnements joignables ; (2) gates vertes en local et en CI ; (3) protection de branche active ; (4) un **smoke test E2E** passe de bout en bout dans chaque environnement ; (5) re-lancer le bootstrap ne produit aucun diff (idempotence prouvée).

---

*Registre : le bootstrap installe l'enforcement (substrat) ; le skill lui-même est guidance. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
