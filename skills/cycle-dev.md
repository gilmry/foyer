# Skill — Cycle dev (rouge / vert / bleu)

*Skill enfant de la primitive `../Boucle-de-retroaction.md`. C'est **l'instance canonique du cercle** : l'outil qui objective est une suite de tests écrite à l'avance. Lit l'archétype déclaré (`../bmad/archetypes.md`).*

---

## La séquence — une story = un tour de cercle

### 🔴 ROUGE — *Conception : poser le critère avant de produire*

Tu écris les tests **avant** le code, dans cet ordre :

1. **BDD** (comportement, lisible métier) — scénarios Gherkin
2. **TDD** (unitaire, contrat technique)

Chacun couvre **quatre classes**, sans en sauter :

- `@happy` — le chemin nominal
- `@negative` — les entrées invalides et les échecs attendus, gérés proprement
- `@edge` — les bornes (vide, max, concurrence…)
- `@security` — abus, injection, autorisation

**Tous les tests échouent.** Le rouge prouve que le critère est falsifiable et actuellement non satisfait (hypothèse posée, au sens Popper).

### 🟢 VERT — *Construction : produire jusqu'à l'objectivation*

Tu écris le **minimum de code** pour faire passer toute la suite au vert. Rien de spéculatif (YAGNI). La suite verte est la **première Évaluation** : le résultat est objectivé par un outil externe, pas par ton jugement.

### 🔵 BLEU — *Amélioration + Évaluation lourde, puis sortie*

1. **Refactor** sous la protection de la suite verte (lisibilité, SOLID, DRY).
2. **Quality gate** (code) → voir `gates.md` *(à écrire)*.
3. **Compléter** avec **E2E + tests d'intégration**.
4. **Security gate** (code + e2e) → voir `gates.md`.
5. **Commit.** Hooks locaux (DRY avec la CI) ; **au plus tard en pre-push : CI complète**.

## Conditionnement par archétype

Tu adaptes `@edge`, le harnais et le `@security` selon l'archétype :

- **stateless** — `@edge` = property-based sur les entrées ; **pas de harnais DB** ; tests d'**idempotence/pureté**.
- **stateful** — `@edge` = concurrence et transitions d'état ; **intégration DB** en phase bleue.
- **API-first** — BDD **au niveau contrat** ; **contract tests** ; `@security` = abus de contrat, autorisation, versioning.
- **full-stack** — **E2E cross-stack** en bleu ; `@security` inclut CSP/XSS sur les îlots Svelte ; **Documentation Vivante** (flux critiques filmés).

## La condition de sortie

On reboucle **tant qu'un test ou une gate réfute** (rouge, gate bloquée, e2e en échec). On sort **quand tout est vert et les gates passent**. Le **push vers une branche GitFlow source de vérité du déploiement** est un point **irréversible** : tu présentes l'état (suite + gates + CI), **l'humain valide**.

## Coût du tour (rappel primitif)

- **Tokens** — génération des tests puis du code → coût modèle.
- **Wall-clock** — quasi nul pour l'unitaire/BDD ; plus élevé pour E2E et run CI → coût superviseur.

Le nombre de tours d'une story est estimé au **point 0** (Brief/Stories) et resserré story après story par le **CSI**.

---

*Registre guidance ; les gates et hooks (enforcement déterministe) sont le filet. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
