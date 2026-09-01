# Skill — Bootstrap d'un nouveau projet avec le kit

*Skill du dispositif, spécifique à la phase **Fabrication** d'un projet **neuf**. Hérite de `../Boucle-de-retroaction.md` (le corollaire « story habilitante ») ; compose `bootstrap-delivrabilite.md` (la reproductibilité) et `contrat-api.md` (le harnais contrat, non optionnel). Le moule de référence est `../../kit-php/`.*

> **La cible.** Un agent reçoit un Brief valide, et en **sort une application qui boucle** : le harnais est en place **avant** la première story métier, pas après. Le projet ne démarre pas « en tournant » : il démarre **déjà conforme**, et la conformance est vérifiable à tout moment par un outil, pas par un avis.

> **Pourquoi un kit plutôt qu'un guide.** Un guide (« voici les conventions, applique-les ») laisse l'agent **décider** de la conformité à chaque choix. Un kit la **pré-décide** : les couches existent, les gates sont câblés, le contrat est matérialisé — l'agent *étend*, il ne *bâtit pas*. C'est la différence entre une recette et une moule : la moule a déjà la forme, il faut y verser le domaine métier.

---

## La séquence — sept gestes, dans l'ordre (le 5ᵉ est spécifique au full-stack)

### 1. Déclarer l'archétype (Étape 0, avant tout le reste)

L'archétype (`../bmad/archetypes.md`) conditionne **tout** ce qui suit :

- **stateless** — pas de persistance, pas de migrations, pas de harnais DB. Le kit se réduit : on garde le domaine pur + la pyramide Unit/Intégration, on supprime SQLite/migrations.
- **stateful** — persistance + migrations portables (chaque `NNNN_up.sql` a son `NNNN_down.sql`). Le kit tel quel.
- **API-first / full-stack** — **le harnais contrat est obligatoire** (`contrat-api.md`, ses quatre éléments) : annotation exhaustive, client généré commité, désérialisation stricte, gate contract en CI. Un bootstrap qui livre l'environnement **sans** ce harnais reproduit le piège documenté dans `contrat-api.md` (le socle « tourne » et dérive en silence).

L'archétype est **consigné** (Brief + `AGENTS.md` du projet) : c'est ce dont on répondra plus tard.

### 2. Poser la toolchain reproductible (la story habilitante, pur `bootstrap-delivrabilite.md`)

Le kit fournit le modèle, le projet l'instancie :

1. **Image de travail** (devcontainer / Dockerfile) — PHP figé, Node figé (si codegen), **uid 1000** pour que les fichiers montés soient exploitables. Le host n'a besoin que de docker.
2. **Commande unique** — un `go` / `make dev` qui monte tout (app + DB locale). Re-lancer = même état (idempotence prouvée par l'absence de diff).
3. **Environnements** — `dev` / `test` (sqlite isolé `data_test.db`) / `prod` (MySQL). Le mapping branche → environnement est déclaré.
4. **L'enforcement substrat** — CI (`.gitlab-ci.yml` ou équivalent) + pre-commit + **protection de branche**. Les hooks locaux font **DRY** avec la CI : même jeu de vérifications, deux points de contrôle.

**Condition de sortie du geste 2** : `git clone` neuf + la commande → l'app démarre et les gates passent. Sans ça, les gestes suivants n'ont pas de socle.

### 3. Vérifier que le harnais du kit est vivant (ne pas copier, **vérifier**)

Le kit est un moule, pas une photographie. À l'instanciation, l'agent **ré-exécute** la boucle complète et s'attend au vert :

```
scripts/verify.php           → les invariants structurels (purity, paires de migrations, contrat commité)
phpunit --testsuite Unit     → la couche domaine
phpunit --testsuite Integration → le contrat HTTP
behat                        → les cas d'usage (BDD)
app:gate:contract            → le harnais anti-drift
```

Puis une **preuve de sensibilité** (le gate ne doit pas être un décor) : introduire un drift artificiel (modifier la spec sans régénérer), vérifier que le gate passe au **rouge**, restaurer. Un gate qui ne s'est jamais montré rouge n'a pas prouvé qu'il bloque.

### 4. Remplacer le domaine d'exemple par le premier domaine métier

Le CRUD de référence du kit (ex. Contact) est un **sparring partner**, pas du code à garder. La bascule :

1. **D'abord le ROUGE** (`cycle-dev.md`) : les 4 classes de tests — `@happy @negative @edge @security` — écrites **avant** le code, dans les **quatre couches** au niveau adapté (Unit = invariants du domaine, BDD = cas d'usage en langage métier, Intégration = contrat HTTP, E2E = si full-stack).
2. **Puis le VERT** : le minimum pour passer — domaine pur → cas d'usage → adaptateurs (HTTP, persistance), dans **cet ordre** (la dépendance pointe toujours vers le domaine).
3. **Puis le BLEU** : refactor sous le vert, gates, commit.
4. Le domaine d'exemple est **retiré** (pas « conservé pour référence » — il est dans le kit, pas dans le projet).

### 5. (full-stack) Monter le frontend découplé + les deux harnais de valeur

Si l'archétype est **full-stack**, le bootstrap **complète** le socle avec le frontend — et le kit le démontre (`frontend/`). La séquence :

1. **Le frontend îlots-first, découplé du backend.** Le frontend se rend **îlots-first** (Astro pour le squelette et les pages, îlots Svelte pour l'interactivité) et ne parle à l'API **qu'à travers le client généré** (`contrat-api.md` élément 2) : aucun `fetch`/`axios`/URL d'endpoint en dur. Un invariant le verrouille (un appel réseau à la main hors `src/generated/` = rouge). C'est le **second pilier anti-drift**, en regard du premier (le contrat). C'est le **rendu par défaut du moule** : un projet qui s'en éloigne (SPA monolithique, rendu applicatif côté back) se met en dérive D2 et doit justifier par ADR (`migration-projet-existant.md`, règle de sobriété).
2. **Le parcours de référence (source de vérité partagée).** Un `journeys/` contient le parcours de référence (étapes id + description en langage métier + action + assertion). C'est **l'objet unique** consommé par les deux harnais — pas une copie dans le test et une dans la doc.
3. **Les deux harnais sur ce parcours** (`documentation-vivante.md`) :
   - **E2E** (gate, bloquant) : rejoue le parcours **à la vitesse**.
   - **Preuve de valeur** (rapport, **non bloquant**) : rejoue le **même** parcours en **cadence 1 action/1s**, capture images + vidéo, publie une **galerie HTML** en artefact CI.
4. **L'invariant anti-dette de doc** : chaque harnais **doit** importer le parcours partagé (`*.journey`) — une doc recoupée du test = rouge. La doc est **dérivée** du parcours rejoué (pas écrite à part) et le parcours est posé **au fil de l'eau** (ici), donc **pas de dette de documentation**.

Le kit se **complète** ici ; un full-stack qui se contente de l'E2E (gate) sans la preuve de valeur livre un projet **vert mais illisible** — le défaut que `documentation-vivante.md` décrit.

### 6. Écrire le `AGENTS.md` du projet (le contrat agent)

Le kit en porte un ; le projet le **dérive** : architecture et sa loi (l'ordre des couches), commandes, harnais, gates, et les **règles de l'agent** — en tête, *ne jamais modifier `vendor/` ; adapter de notre côté de la frontière, ou avec l'adaptateur que le framework fournit*. C'est le fichier que le prochain agent lira : s'il faut lui réexpliquer ce qui est écrit ailleurs, c'est qu'il est mal écrit.

### 7. Les points irréversibles — l'humain valide

Créer la production, poser la protection de branche, provisionner un datastore, la première migration de schéma : l'agent **présente l'état** (suite verte + gates + CI), l'humain décide. Le bootstrap lui-même passe par les gates, comme toute story. Pour le full-stack, l'humain choisit aussi **quels parcours sont « critiques »** (ce qu'on filme, c'est ce qu'on dit valoir la peine d'être vu).

## Les pièges connus (et leur antidote)

| Piège | Adhésion tentante | L'antidote |
|---|---|---|
| « Le harnais, on le metra quand l'app marchera » | livrer « 85 % » vite | Le harnais **précède** la première story métier — corollaire de la boucle. Sans outil qui objective, pas d'Évaluation, pas de cercle. |
| « Le contrat est décrit dans le README » | section en prose cochée `✓` | `contrat-api.md` : un contrat décrit n'est pas un contrat matérialisé. Les 4 éléments, ou rien. |
| « On n'a pas besoin de la couche BDD, les tests PHPUnit suffisent » | une couche de moins à écrire | La BDD est la **Documentation Vivante** : le cas d'usage en langage métier, pas le code de statut. La pyramide n'est pas redondante, elle est à niveaux. |
| « Le sqlite local prouve la portabilité des migrations » | le test local passe | Le gate MySQL en CI joue les `up.sql` sur MySQL. Le sqlite ne prouve que le sqlite. |
| « Le gate est vert, donc il marche » | le vert ne prouve rien | La **preuve de sensibilité** (geste 3) : un drift artificiel doit le faire passer au rouge. |
| « L'E2E vert suffit, la doc viendra après » | un harnais de moins, une doc écrite à part | L'E2E prouve **correctness** ; la preuve de valeur prouve **lisible** (`documentation-vivante.md`). Et « la doc après », c'est **la** dette : ici la doc est **dérivée** du parcours rejoué, pas rédigée. |

## Conditionnement

- **Archétype** — voir le geste 1. Le kit se **réduit** (stateless : persistance et migrations sortent) ou se **complète** (full-stack : frontend + E2E Playwright + unit front), mais l'ordre ne change jamais : **harnais d'abord, métier ensuite**.
- **Taille** — même pour un Micro (1-3 BC), les 4 éléments du contrat et les 4 couches restent : le coût de la dérive est asymétrique, invisible jusqu'au NO-GO. On peut réduire le *formalisme* (un ADR d'une page), jamais le *mécanisme*.
- **Stack** — la stack du kit (Symfony + ApiPlatform + Doctrine) **fait partie de la cible** : le harnais contrat et les migrations automatiques en sont mécanisés, et c'est le point d'arrivée de tout projet (bootstrap **et** rétrofit, `migration-projet-existant.md`). Un brief qui l'exclut (contrainte d'hébergement, toolchain existante) est un **arbitrage produit humain**, consigné en ADR — avec le résidu de risque mesuré (`contrat-api.md` § stack sans écosystème d'annotation) ; ce n'est pas un jugement de sobriété de l'agent.

## Definition of Done du bootstrap

1. Clone neuf + une commande → l'app démarre, idempotent.
2. **Gates verts en local et en CI**, et chaque gate a montré qu'il bloque (preuve de sensibilité).
3. Le premier domaine métier existe, avec ses 4 classes de tests dans les 4 couches.
4. Le domaine d'exemple est retiré ; `AGENTS.md` écrit.
5. Protection de branche active, pre-commit DRY avec la CI.
6. L'humain a validé les points irréversibles.
7. *(full-stack)* le parcours de référence est rejoué par **les deux** harnais (E2E gate + preuve de valeur cadencée) et l'invariant anti-dette de doc est en place.

---

*Registre : guidance. Le kit (`../../kit-php/`) est le substrat ; les gates et la CI sont l'enforcement. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
