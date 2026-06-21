# Boucle de rétroaction — primitive

*Skill-socle de la Méthode Foyer. Portable : chargeable comme `AGENTS.md`, `CLAUDE.md`, ou via le champ `instructions` d'`opencode.json`. Tous les autres skills (enfants) et tous les personas (grains) en héritent.*

---

## La primitive — un cercle en cinq temps

Tout travail tourne sur le même cercle :

> **Conception → Construction → Résultat → Évaluation → Amélioration → (Conception…)**

- **Conception** — tu poses le critère *avant* de produire (l'hypothèse, falsifiable d'avance) : specs, ADR, plan.
- **Construction** — tu produis.
- **Résultat** — l'artefact existe.
- **Évaluation** — un **outil externe objective** le résultat. Jamais ton seul jugement.
- **Amélioration** — tu révises, et le cercle **referme** sur une nouvelle Conception.

Compression mnémonique : *agir → un outil objective → ça remonte → tu ajustes.* C'est la vérification rendue mécanique — l'antidote au danger *« assez fiable pour qu'on cesse de vérifier »*.

Le cycle dev rouge/vert/bleu n'est qu'**une instance** de ce cercle (l'outil qui objective y est une suite de tests écrite à l'avance).

## Le cercle monte — cercle à chaque grain, spirale entre les grains

À grain constant, le cercle **itère** : story après story. Entre les grains, l'**Amélioration d'un grain alimente la Conception du grain au-dessus** — la fabrication nourrit le pilotage (CSI), qui nourrit l'architecture (ADM). Même forme à tous les grains : c'est l'auto-similarité.

## La condition de sortie

Un cercle ne s'arrête pas seul ; une story, si. On referme **tant que l'Évaluation réfute** (rouge, gate qui bloque, IaC non convergée) ; on sort **quand elle ne réfute plus**. Avant toute sortie sur un choix irréversible, **l'humain valide**.

## L'unité de travail

Le **tour de cercle est l'unité** — l'axe relatif du Gantt, la maille de l'estimation. Une story = *N* tours. Les terrains ne divergent pas sur l'unité, mais sur **quel outil objective** (à l'Évaluation) et **combien de tours pour converger**.

## Corollaire — la story habilitante

Sans outil pour objectiver, pas d'Évaluation, donc pas de cercle. **Mettre en place ce qui permet de boucler est donc une story** : harnais de tests, quality/security gates, observabilité, CI. Elle livre *la capacité de boucler* et **précède** les stories qui en dépendent (point de concours du Gantt). Sa forme aboutie est la **délivrabilité reproductible** — `git clone` + agent reconstruit les quatre environnements et les postes superviseur, sous enforcement (voir `skills/bootstrap-delivrabilite.md`). À l'échelle programme, c'est l'*architectural runway* de SAFe.

## Le coût d'un tour — deux axes

- **Tokens** — ce que l'agent génère et relit → coût du modèle (piloté par OpenCode).
- **Wall-clock** — la latence de l'outil d'Évaluation : quasi nulle pour un test unitaire, longue pour une convergence IaC ou un run CI → coût du superviseur.

Coût d'une story ≈ *N* tours × (tokens + wall-clock). L'asymétrie des terrains (IaC, DevSecOps : peu de tokens, fort wall-clock) n'est qu'une ventilation différente de ces deux coûts.

> Le superviseur est idéalement un **binôme** (parfois un trio), pas une personne seule : le wall-clock supplémentaire est un **investissement** dans la transmissibilité et contre le *bus factor 1* — un répondre-de tenu par une seule tête est fragile. Voir Manifeste (conviction 3) et `skills/abaque-cout-capacite.md`.

## Les deux axes de spécialisation

Le cercle se spécialise selon **deux axes orthogonaux** — à ne pas mélanger :

- **Axe terrain** = *quel outil objective* → les **skills enfants** (techniques, réutilisables, sans titulaire).
- **Axe rôle/grain** = *qui tient le cercle et à quelle échelle* → les **personas** (chacun tient le cercle à son grain et compose les skills-terrains).

### Enfants — une instance par outil objectivant *(à écrire)*

- **Cycle dev** (`skills/cycle-dev.md`) — outil : tests pré-écrits. Rouge (BDD puis TDD, tags `@happy @negative @edge @security`, tout échoue) → Vert (code jusqu'au succès) → Bleu (refactor + quality gate ; puis e2e/intégration + security gate).
- **Gates qualité & sécurité** (`skills/gates.md`) — outil : analyseurs statiques, scanners (transversal).
- **Convergence IaC** (`skills/convergence-iac.md`) — outil : l'état observé (apply → re-apply stable) ; idempotence salt-ssh.
- **Adoption / usage** (`skills/adoption.md`) — outil : doléances des issues + signaux **RACE** (*Convert → Adoption*) ; priorisation par **RICE / WSJF** (*Confidence* ← CSI, *Effort* ← estimation en tours).

### Personas — un grain par échelle *(à écrire)*

Invariants au grain (montent avec l'échelle, **un persona chacun**) : architecte solution (méta-boucle ADR/ADM), chef de projet (pilotage : WBS→Gantt→coût→cadre), CSI engineer, support engineer.

Propres à un barreau (**personas conditionnels**, activés si le barreau est déployé) : lead developer & scrum master (Scrum) · Nexus Integration Team (Nexus) · RTE (SAFe Essential).

## La méta-boucle — le cycle ADR/ADM de TOGAF

La décision d'architecture est ce même cercle, **d'ordre supérieur** : son outil d'Évaluation, ce sont *les autres boucles*. Ce que la fabrication, le CSI et l'usage révèlent remonte et **nourrit ou révise les ADR**. Son rythme **dépend du cadre de fabrication déployé** (Scrum/Nexus/SAFe, sélectionné par le Gantt selon les parallélismes et points de concours) : la cadence des gate reviews suit la cadence de delivery. Le choix ou le rescaling du barreau est un point coûteux à défaire → **ADR** proposé par le chef de projet, tracé par l'architecte solution.

## Le point irréversible

Quand un tour engage un choix **irréversible** (mapping branche GitFlow → environnement, durcissement serveur, dépendance non rotable, choix de barreau), tu présentes le motif et **l'humain valide**. *« Pourrai-je en répondre, et devant qui ? »*

---

*Ce fichier **oriente** (registre guidance) ; il ne remplace pas les garde-fous déterministes (hooks, permissions) qui seuls contraignent. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
