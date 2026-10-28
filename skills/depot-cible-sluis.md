# Skill — Générer un dépôt cible pour Sluis

*Skill enfant de la primitive `../Boucle-de-retroaction.md`. L'outil qui **objective** n'est ni un test ni un analyseur de ce dépôt : c'est **le verdict de Sluis lui-même**, l'outil MCP `sluis_verifier_depot`, qui applique les règles que Sluis appliquera à l'exécution. Invoque `gates.md` et `convergence-iac.md`. Lit l'archétype (`../bmad/archetypes.md`). Côté Sluis : ADR-034, « le contrat du dépôt cible ».*

> **Règle cardinale.** Ce skill **ne recopie pas le contrat**. Il ne nomme aucun chemin, aucune clé, aucun nom de check-run. Il dit où lire le contrat et comment se faire juger. Une règle recopiée ici dériverait de Sluis au premier changement ; c'est exactement ce qu'ADR-034 interdit.

---

## Qui fait quoi

- **Toi (la skill)** : tu **écris** les fichiers du projet. Tu ne les exécutes jamais.
- **Sluis** : il **lit, juge, puis exécute**. Il détient le contrat et le publie.
- **L'humain** : il valide chaque point irréversible et la proposition finale.

Aucune brique ne détient tout : celui qui écrit ne juge pas son propre travail, celui qui exécute n'écrit pas ce qu'il exécute.

## Le cercle

- **Conception** — tu **lis le contrat** à une **version étiquetée** de Sluis : le fichier `contrat/depot-cible.v1.json` de ce tag, ou la sortie de `sluis contract` du binaire de ce tag. Jamais `main`, jamais ta mémoire d'une session précédente. Tu notes le tag et le champ `version` dans le registre d'état du pilote.
- **Construction** — tu génères ce que le contrat demande, rien de plus : l'arborescence d'infrastructure, la déclaration de charge, les profils de cluster, les cellules, les modules OpenTofu avec leur fichier de verrouillage, le workflow de Tier 1 **copié du gabarit de Sluis** (jamais réécrit), et une CI dont les jobs de gate portent les noms du contrat. Pour la CI, pars des gabarits de `../tools/gates/github/workflows/` : ils sont déjà nommés selon le contrat.
- **Résultat** — un dépôt candidat, non proposé.
- **Évaluation** — tu appelles **`sluis_verifier_depot`** avec la racine du dépôt. Le verdict dit `conforme`, liste les `ecarts` (bloquants, avec règle, chemin et détail) et les `remarques` (non bloquantes).
- **Amélioration** — chaque écart se corrige à la source, puis tu rappelles l'outil. Tu ne contournes jamais un écart en modifiant ce que Sluis lit pour le tromper (renommer un job trivial, vider une section).

## Condition de sortie

Tu proposes le dépôt **seulement** quand :

1. le verdict est `conforme` ;
2. les remarques sont **présentées à l'humain**, pas tues : un dossier non reconnu ou des fournisseurs non jugés (liste blanche vide sur le Sluis interrogé) sont des faits qu'il doit voir ;
3. les gates de `gates.md` sont vertes sur le dépôt lui-même.

Un dépôt non conforme est refusé à l'admission par Sluis. Le proposer quand même, c'est déplacer l'échec vers le déploiement, au pire moment.

## Conditionnement par archétype

- **stateless** — la gate de retour de migration n'est pas exigée.
- **stateful** — elle l'est : le gabarit `postgresql-migrations` la nomme selon le contrat, et Sluis la lit si son déploiement déclare l'archétype `stateful`.
- **API-first**, **full-stack** — aucune règle de plus côté contrat à ce jour ; le contrat fait foi si cela change.

## Points irréversibles

- **La forme du contrat** est irréversible côté Sluis (ADR-034) : un dépôt généré selon une version se reprend à la main si la version change. Une **nouvelle version** du contrat se signale à l'humain, elle ne se suit pas en silence.
- **La liste blanche des fournisseurs** OpenTofu appartient au déploiement de Sluis, pas au dépôt : tu ne la choisis pas, tu la demandes.
- **Le mapping branche → environnement** et le **workflow de Tier 1** portent l'approbation humaine ; y toucher se présente avec le motif et l'état, **l'humain valide**.

## Coût

**Peu de tokens, cycles courts** : un appel d'outil en lecture par tour, sans infrastructure louée. C'est le moins cher des cercles de production, et celui qui en évite le plus d'échecs tardifs.

---

*Registre guidance ; le blocage (refus à l'admission, refus avant `tofu init`, refus de dispatch) est l'enforcement, et il vit dans Sluis. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
