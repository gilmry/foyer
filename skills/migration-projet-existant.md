# Skill — Migration d'un projet existant non conforme (rétrofit)

*Skill du dispositif, spécifique à la phase **Fabrication** d'un projet **existant** qui ne respecte pas l'architecture de référence. Hérite de `../Boucle-de-retroaction.md` ; compose `bootstrap-delivrabilite.md` (la reproductibilité), `contrat-api.md` (le harnais contrat) et `gates.md` (le plancher). Le moule de référence est `../../kit-php/`.*

> **La cible.** Un projet qui existe, qui « marche » (ou croit marcher), et qui n'a **ni harnais, ni architecture, ni preuve** : le code métier est collé au framework, le contrat API est à la main, les tests sont inexistants ou superficiels. Le rétrofit ne le réécrit pas — il l'**entoure de ce qui le rend répondable**, couche par couche, sans le faire tomber.
>
> **Le point d'arrivée est fixé : le périmètre du kit** (`../../kit-php/`) — Symfony hexagonal, **ApiPlatform** en adaptateur contrat, **Doctrine** en adaptateur persistance, spec OpenAPI générée du code, client front généré, frontend **îlots-first** (Astro + îlots Svelte). Le rétrofit amène **n'importe quel projet php/mysql** là-dessus. Le point d'arrivée ne se négocie pas ; ce qui se négocie (arbitrage humain, ADR) ce sont les **modalités** : la bascule de stack, le séquençage des périmètres, le moment des bascules. L'IA gère la complexité ; l'humain tranche l'opérationnel, jamais la destination.

> **Pourquoi ce n'est pas un bootstrap.** `bootstrap-nouveau-projet.md` part d'un moule vide : l'agent **verse** le métier dans la forme. Le rétrofit part d'une forme **déjà occupée** : l'agent doit **extraire** le métier de là où il est coincé (framework, SQL inline, front collé au back), et le **réinstaller** dans la forme — sans interrompre le service. C'est l'opération inverse, et c'est pour ça qu'elle est plus risquée : chaque geste peut casser ce qui marche.

---

## Le principe fondateur — le rétrofit est une histoire de **strangler**, pas de big-bang

On ne réécrit pas l'application en une fois : on la **cogne** (strangler fig) autour du harnais, un périmètre à la fois. Chaque périmètre migré devient **irréversible** (le harnais le protège ensuite) et **réversible en sécurité** (l'ancien code reste en place tant que le nouveau n'est pas prouvé). C'est l'anti-symétrique exact du piège de `contrat-api.md` (OpenMajor) : là, le contrat s'est délité parce qu'on l'a maintenu à la main **en continu**, sans harnais. Ici, on pose le harnais **avant** de toucher au métier, pour que la dérive ne se reforme pas pendant la migration elle-même.

## La séquence — cinq phases, dans l'ordre

### Phase 0 — Le diagnostic de dérive (avant de toucher quoi que ce soit)

L'agent **mesure** l'écart à l'architecture de référence, et le **consigne** (c'est un ADR : « l'état initial »). Le kit fournit la grille de lecture :

| Dimension | Ce qu'on cherche | Le signal de dérive |
|---|---|---|
| **Architecture** | le domaine est-il pur ? | `use Symfony\*` / `use Doctrine\*` dans la couche métier ; la logique métier dans les controllers/ORM |
| **Contrat API** | est-il matérialisé ? | client front à la main, `fetch` inline non typés, pas de spec, casing divergent front↔back |
| **Frontend — contrat (D1)** | est-il découplé du backend ? | frontend **collé** : `fetch`/`axios` en dur, URL d'endpoint dupliquées, aucun parcours de référence partagé, pas de preuve de valeur (doc filmée). Destination : **client généré** (phase 2, étape 5) |
| **Frontend — rendu (D2)** | quelle techno de rendu, et est-elle îlots-first ? | **rendu applicatif côté back** (le serveur génère le HTML) ; **SPA monolithique** (bundle lourd, tout le rendu à la main) ; monolithe vanilla ; code mort significatif. Destination : **îlots-first (Astro + îlots Svelte)** — périmètre du kit (phase 2, étape 6) |
| **Persistance** | Doctrine ? | SQL inline, `PDO` à la main, ORM maison, `ALTER` à la main, pas de `down.sql`, `datetime('now')` / `AUTO_INCREMENT` non portables. Destination : **Doctrine** + migrations Doctrine (up/down auto) |
| **Tests** | les 4 couches existent ? | pas de tests, ou des tests E2E seuls (le sommet de la pyramide sans socle) |
| **Secrets** | dans le dépôt ? | mot de passe en clair dans la config commitée, `.env` commité |

**Le diagnostic est lui-même un livrable** : sans lui, on ne peut pas prouver plus tard que le projet est *devenu* conforme — on ne répond de rien. Il fixe aussi le **périmètre de migration** (ce qui est le plus dérivé migre en premier).

### Phase 1 — Le harnais avant le métier (le socle, non négociable)

Avant d'extraire **une seule ligne** de métier, on pose ce qui va objectiver la migration — exactement comme dans le bootstrap, mais **autour du code existant** :

1. **L'environnement reproductible** (`bootstrap-delivrabilite.md`) : image de travail, commande unique, base locale. Le projet doit **d'abord tourner dans le harnais** — même le code legacy.
2. **Les gates plancher** (`gates.md`) : secrets, migrations réversibles. Ce sont les deux qui capturent de l'information **irrécupérable** (un secret fuité, une migration jouée sans retour) — on les met **premier**, avant même les tests, parce que chaque jour sans eux est une perte sèche.
3. **La suite de tests caractérisation** : on écrit des tests qui figent le **comportement actuel** (y compris les bugs, qu'on documente), pas le comportement idéal. C'est le filet de sécurité du rétrofit : tant que le legacy est en place, ces tests sont la preuve que la migration **ne change rien** à l'extérieur.

**Condition de sortie de la phase 1** : le projet legacy tourne dans le harnais, les gates plancher sont verts, et la suite de caractérisation est verte. **On n'extraite rien tant que ce n'est pas vrai** — sinon on migre sur du sable.

### Phase 2 — L'extraction couche par couche (le cœur du rétrofit)

On extrait **une couche à la fois**, dans l'ordre de la dépendance (du plus pur au plus dépendant), et **chaque extraction passe le rouge/vert/bleu** de `cycle-dev.md` :

```
1. Domaine pur      — extraire les invariants métier du framework
                       (tests Unit 4 classes : le ROUGE d'abord)
2. Cas d'usage      — extraire l'orchestration des controllers
                       (tests BDD 4 classes, en langage métier)
3. Adaptateurs      — réécrire HTTP + persistance comme des adaptateurs
                       (tests Intégration 4 classes + harnais contrat) —
                       destination : ApiPlatform (adaptateur contrat) et
                       Doctrine (adaptateur persistance)
4. Le contrat       — matérialiser l'OpenAPI sur le périmètre du kit :
                       spec générée des ressources ApiPlatform, client généré,
                       désérialisation stricte (les 4 éléments de contrat-api.md)
5. Le frontend D1   — le découpler : consommer SEULEMENT le client généré
                       (supprimer les fetch/axios/URL en dur), poser le parcours
                        de référence partagé + E2E (gate) + preuve de valeur
                         cadencée (documentation-vivante.md)
6. Le frontend D2   — CONDITIONNEL (règle de sobriété) : si le front porte la
                       dérive, le migrer îlots-first (Astro + îlots Svelte),
                       régression visuelle (golden) incluse
```

**Le découplage du frontend (étape 5) est un mini-strangler.** Le projet
existant a un frontend **collé** à son backend : un `api.ts` écrit à la main,
des `fetch` inline non typés, des endpoints dupliqués (le piège OpenMajor,
`contrat-api.md`). On le découple **en trois temps, sans l'arrêter** :

1. **Poser le contrat** (étape 4 déjà faite) : le client généré existe.
2. **Basculer, périmètre par périmètre** : un écran/une feature à la fois
   remplace ses `fetch` inline par le **client généré** ; le code legacy et le
   nouveau **coexistent** tant que la caractérisation ne prouve pas
   l'équivalence. (La bascule totale du client à la main → généré est un point
   irréversible : ADR + validation, comme le contrat.)
3. **Supprimer** le client à la main du périmètre — et poser le **parcours de
   référence partagé** + les deux harnais (E2E gate + preuve de valeur) : le
   frontend devient **découplé et prouvé**, et la doc vivante est **dérivée**
   du parcours (pas de dette).

Un invariant verrouille le résultat : aucun `fetch`/`axios`/URL d'endpoint en
dur hors du client généré — un appel réseau à la main = rouge.

**Le rendu du frontend (étape 6) est un mini-strangler à part, conditionnel.**
L'étape 5 prouve que le front **consomme le contrat** ; l'étape 6 décide de
**comment le front se rend**. La destination est **îlots-first** (Astro pour
le squelette + les pages, Svelte pour les îlots interactifs) : c'est le
rendu léger par défaut du moule, et le point d'arrivée des fronts dérivés
(SPA monolithique, HTML généré par le serveur applicatif). La même mécanique
que l'étape 5, mais avec un harnais de plus :

1. **Golden d'apparence** : capturer l'apparence actuelle du périmètre
   (screenshots de référence, **dérivés** des mêmes parcours, jamais recopiés
   à la main). C'est la 3e harnais du rétrofit, après la caractérisation
   (comportement) et l'E2E (correctness) : la **régression visuelle**, gate
   de la bascule n°2.
2. **Construire îlots-first** : l'écran en Astro + îlots Svelte, qui
   consomme le client généré (étape 5), côte à côte avec l'ancien rendu.
3. **Prouver l'équivalence** : E2E verts **et** régression visuelle verte
   (les goldens comparés, tolérance définie). Les deux font foi : un E2E
   vert ne prouve pas que l'écran ressemble à l'ancien.
4. **Bascule n°2** (point irréversible) : les écrans sont servis en îlots-
   first ; l'humain valide sur les deux preuves.
5. **Supprimer l'ancien rendu** du périmètre (même règle que l'étape 5 :
   le git est l'archive).

**Le refactor mécanique se délègue, le métier non.** Pour la migration du **code PHP pur** (upgrade de version, patterns dépréciés, renommages, signatures), l'outil est **Rector** (`../tools/gates/ADR-outillage.md`, registre jalon) : on l'exécute **sous le vert** de la suite de caractérisation, on **revue le diff**, on le committe par périmètre. La frontière : Rector fait la mécanique (il ne lit pas l'intention) ; l'agent fait l'extraction sémantique (invariants métier, découpage des couches) ; les tests tranchent. Un Rector lancé au rouge, ou dont on ne révise pas le diff, est un big-bang déguisé.

**Les évolutions de la stack de destination suivent le même cercle.** Une fois convergé sur le périmètre du kit, les sauts de version **Symfony / ApiPlatform / Doctrine** ne se font **pas au feeling des changelogs** : ce sont les **indices de dépréciation des frameworks** qui pilotent. Le framework signale lui-même ce qui doit bouger (`trigger_deprecation` Symfony, `Deprecation` Doctrine, logs de dépréciation en CI) ; les **rulesets de refactor** font la mécanique (Rector : règles de version PHP + les sets intégrés `SymfonySetList` / `DoctrineSetList` de `rector/rector` — les rulesets framework vivent **dans** le paquet Rector, pas dans des paquets séparés ; ApiPlatform n'a **pas** de ruleset officiel, ses dépréciations se traitent à la main sous revue) ; la suite de tests (4 classes) prouve que rien n'a changé à l'extérieur. Le geste par saut de version : (1) monter la dépendance, (2) lire la **liste des dépréciations émises** (pas les notes de version), (3) refactorer les signaux avec les rulesets **sous le vert**, (4) vérifier **zéro dépréciation nouvelle** au vert. Une suite verte avec des dépréciations non traitées est un vert partiel — le compteur de dépréciations est un gate de jalon (`gates.md`) : il produit un rapport, l'humain tranche le triage, mais la tendance ne doit jamais monter.

**La règle d'or du rétrofit** : le code legacy et le nouveau code **coexistent** pendant la migration, et c'est le **traffic réel** (ou la suite de caractérisation) qui tranche lequel est bon — pas l'opinion de l'agent. Un périmètre n'est déclaré « migré » que quand :

- ses tests 4 classes sont verts dans les 4 couches,
- le harnais contrat le couvre (spec + client + désérialisation stricte),
- et la suite de caractérisation prouve que le comportement externe est **inchangé**.

À ce moment-là seulement, le legacy du périmètre est **supprimé** (pas « commenté », pas « conservé au cas où » — le git l'a).

### Phase 3 — Le verrouillage (on empêche la dérive de se reformer)

C'est la phase que le bootstrap n'a pas besoin de faire et que le rétrofit **doit** faire : le projet a déjà une mémoire de la dérive. On verrouille :

- **Les gates en CI deviennent bloquants** (plancher, `gates.md`) : ce qui passe en local passe en CI, même jeu (DRY). Un périmètre migré qui dériverait à nouveau casse le build.
- **La protection de branche** : on ne pousse plus vers la branche source de vérité sans CI verte.
- **L'`AGENTS.md` du projet** : la nouvelle architecture est le contrat agent — le prochain agent qui y touchera sait que le domaine doit rester pur, que le contrat se régénère et ne s'édite pas.

### Phase 4 — La preuve de convergence

Le rétrofit est fini quand le diagnostic de la phase 0 est **re-mesuré et vert** sur toutes les dimensions. On ne dit pas « c'est migré » : on **montre** la grille de diagnostic passée de rouge à vert, et l'humain valide (c'est un point irréversible — l'architecture est désormais engagée).

## Les pièges connus (et leur antidote)

| Piège | Adhésion tentante | L'antidote |
|---|---|---|
| « On réécrit tout d'un coup, c'est plus propre » | le big-bang, une coupure nette | Le strangler. Chaque périmètre migre seul, prouvé, sans tomber le reste. Le big-bang est le seul scénario où le projet ne marche **plus** en cours de migration. |
| « Les tests, on les écrira après la migration » | migrer vite, sécuriser après | La phase 1 est **avant** la phase 2. Sans suite de caractérisation, on ne prouve rien — et on ne répond de rien. |
| « On migre le métier, le harnais viendra après » | l'inverse du bootstrap | Exactement le piège d'OpenMajor : le harnais **précède** l'extraction, sinon la dérive se reforme pendant la migration. |
| « Le legacy, on le garde en commentaire au cas où » | la sécurité par accumulation | Le git est l'archive. Du code mort commité est une dette qui pousse à la dérive (personne ne le lit plus, personne ne le teste). |
| « La migration est finie parce que l'app tourne » | « ça marche » = conforme | La phase 4 re-mesure le diagnostic. « Ça tourne » est l'état initial — il était déjà vrai avant, et le projet n'en était pas moins dérivé. |
| « On saute la persistance, c'est le plus long » | migrer d'abord le domaine (court) | L'ordre de la dépendance (phase 2) impose de finir une couche avant de passer : un adaptateur persistance half-migré laisse le domaine s'appuyer sur du legacy, et la pureté n'est pas prouvable. |
| « L'E2E passé, le frontend est migré — la doc, plus tard » | un périmètre « fait » mais illisible | Le découplage (étape 5) inclut la **preuve de valeur** (parcours partagé + cadence), dérivée du test. « Plus tard » = la doc qui s'érige (`documentation-vivante.md`). |
| « L'E2E est vert, l'écran est donc migré » (étape 6) | correctness = apparence | L'E2E prouve que **ça marche**, pas que **ça ressemble à l'ancien**. La bascule n°2 exige la **régression visuelle** (goldens) en plus : sans elle, l'utilisateur voit un écran qui marche mais qui a changé sans qu'on le sache. |
| « Le golden, je le recopie à la main sur le nouveau rendu » | l'apparence « validée » à l'œil | Un golden recopié sur le **nouveau** rendu prouve que le nouveau est égal à lui-même. Les goldens sont **dérivés du rendu ancien** (même parcours, capture avant bascule) : c'est la référence, pas la copie. |
| « Le front est découplé (D1 vert), donc le rendu, on le laisse » | D1 = D2 | D1 (contrat) et D2 (rendu) sont **deux dimensions distinctes** : D1 vert ne dispense pas D2. La destination est îlots-first (périmètre du kit) ; si la dérive de rendu est mesurée, l'étape 6 s'exécute, sinon le report est **consigné** (ADR + phase 4) — jamais un abandon. |
| « On migre l'architecture, la stack on la laissera telle quelle » | destination = architecture seule | La destination est le **périmètre du kit** : ApiPlatform en adaptateur contrat, Doctrine en adaptateur persistance. Les gates ne sont mécanisés que par cette stack ; un « gates miroités » permanent n'est pas une destination, c'est un résidu de dérive qui doit apparaître au diagnostic (arbitrage humain sur les **modalités** de bascule, jamais sur le point d'arrivée). |

## Les points irréversibles — l'humain valide

Comme dans le bootstrap, mais le rétrofit a **deux bascules nommées**, irréversibles, validées par l'humain sur preuve :

- **Bascule n°0 — stack** (si le projet n'est pas déjà sur la stack du kit) : le périmètre migre **sur** ApiPlatform + Doctrine (contrat mécanisé, migrations Doctrine). C'est la bascule de destination ; l'humain valide sur tests 4 couches + caractérisation + re-validation de la recette (rebase).
- **Bascule n°1 — backend** : les routes servent les adaptateurs (le SQL inline est retiré du périmètre), et le frontend consomme le client généré (l'ancien client à la main est supprimé du périmètre). C'est la bascule du contrat + de l'extraction ; l'humain valide sur tests 4 couches + caractérisation.
- **Bascule n°2 — frontend** : les écrans sont servis en îlots-first, l'ancien rendu est supprimé du périmètre (étape 6). L'humain valide sur E2E verts **+ régression visuelle verte** (goldens comparés). N'existe que si la règle de sobriété a déclenché l'étape 6.

Les autres points irréversibles du rétrofit :

- La **suppression d'un périmètre legacy** (phase 2) : irréversible en pratique (le trafic y est passé) → l'humain valide, sur la preuve (tests 4 couches + caractérisation).
- La **suppression d'une migration legacy** ou sa réversion en production : le point irréversible propre à l'état (`archetypes.md` § stateful).
- Le **passage à l'architecture engagée** (phase 4) : l'humain valide sur la grille de diagnostic revenue verte.

## La règle de sobriété — D1 est obligatoire, D2 est déclenchée par la dérive mesurée

La destination est fixée (îlots-first, périmètre du kit) ; la sobriété porte sur le **déclenchement** et le **moment** :

- **D1 (contrat)** — le front **consomme le contrat** (client généré, pas de `fetch`/URL en dur). **Toujours obligatoire** : c'est le découplage, c'est ce qui rend le périmètre répondable. Aucun ADR ne dispense D1.
- **D2 (rendu)** — le front se rend **îlots-first** (Astro + Svelte), **dès que le front porte la dérive** (rendu applicatif côté back, SPA monolithique, code mort significatif — les signaux de la phase 0). La règle de sobriété dit : **on ne migre pas le rendu « pour la propreté »** — si la phase 0 ne mesure pas de dérive de rendu, l'étape 6 s'exécute au fil de l'eau (au prochain périmètre touché) plutôt que comme une opération dédiée, et ce report **consigné en ADR** (poids de dérive mesuré à zéro) est un état transitoire qui doit apparaître au diagnostic de la phase 4 jusqu'à extinction.

## Conditionnement

- **Taille de la dérive** — un projet à 1 BC dérivé : les 5 phases s'appliquent, la phase 2 tient en un périmètre. Un programme multi-BC : la phase 2 **multiplie** (un BC à la fois, dans l'ordre du diagnostic), et chaque BC a sa propre boucle rouge/vert/bleu. Le diagnostic (phase 0) devient alors un **cartographie** : la matrice BC × dimensions de dérive, priorisée.
- **Urgence opérationnelle** — si le projet a un incident en cours, la phase 1 (le harnais) se pose **même en premier**, parce qu'elle est ce qui rendra l'incident **répondable** (on saura quoi tester pour vérifier le correctif). Le métier attend ; le harnais non.
- **Ce qui ne migre jamais** — les données de production. Le rétrofit migre le **code**, jamais les données : la migration de schéma (si le modèle change) est un point irréversible à part, traité selon `archetypes.md` § stateful, avec son `down.sql`.
- **La destination est le périmètre du kit — c'est fixé, pas négociable.** Le point d'arrivée est toujours le kit : ApiPlatform en adaptateur contrat, Doctrine en adaptateur persistance, spec générée, client généré, îlots-first. Ce que le rétrofit « amène là-dessus », c'est **n'importe quel projet php/mysql** — déjà sur Symfony, ou bien vanilla / no-Composer. Les gates du kit (contrat, migrations automatiques) ne sont **mécanisés que par cette stack** : rester sur une autre stack avec des « gates miroités » à la main n'est **pas une destination**, c'est un résidu de dérive (le même contrat plus faible que décrit `contrat-api.md` § stack sans écosystème d'annotation) — acceptable comme **état transitoire** pendant la migration, jamais comme point d'arrivée.
- **Ce qui se négocie, ce sont les modalités (arbitrage humain, ADR).** (1) **La bascule de stack** : pour un projet **déjà sur** la stack du kit, le strangler converge périmètre par périmètre (controllers → ressources ApiPlatform, SQL inline → repositories Doctrine), sans rebase. Pour un projet **sur une autre stack**, le passage à la stack du kit est un **rebase d'échelle projet** (nouveau déploiement, re-validation de la recette production) : l'humain décide **quand** et **comment** (rebase préliminaire, ou périmètre par périmètre avec les deux stacks en cohabitation), sur coût/bénéfice mesuré — **pas s'il** y passe. (2) **Le séquençage** : l'ordre des périmètres, le découpage des bascules. L'IA produit l'analyse et le plan ; l'humain tranche l'opérationnel. Le point d'arrivée ne fait jamais partie de l'arbitrage.

## Definition of Done du rétrofit

1. La phase 0 est consignée (l'état initial, mesuré).
2. Le harnais est en place **avant** toute extraction (phase 1 verte).
3. Chaque périmètre est migré par la séquence rouge/vert/bleu, ses 4 classes de tests sont vertes dans les 4 couches, et la caractérisation prouve le comportement inchangé.
4. Le harnais contrat est matérialisé (les 4 éléments de `contrat-api.md`).
5. **La stack est le périmètre du kit** : ApiPlatform en adaptateur contrat, Doctrine en adaptateur persistance, spec générée du code, migrations Doctrine (up/down) — ou, à défaut, le résidu de stack reste **consigné** au diagnostic comme dérive mesurée (ADR, arbitrage modal).
6. **Le frontend D1 est découplé** (consomme le client généré, pas de `fetch`/URL en dur) **et la preuve de valeur est dérivée** (parcours partagé + cadence — `documentation-vivante.md`).
7. **Le frontend D2 est tranché** (règle de sobriété) : la migration îlots-first est prouvée (E2E + régression visuelle, bascule n°2 validée, ancien rendu supprimé), ou le report est **consigné** (ADR + visible au diagnostic de phase 4).
8. Les gates plancher bloquent en CI, la protection de branche est active, l'`AGENTS.md` engage l'architecture.
9. Le diagnostic re-mesuré (phase 4) est **vert sur toutes les dimensions** — et l'humain a validé.

---

*Registre : guidance. Le kit (`../../kit-php/`) est la forme de destination ; les gates et la CI sont l'enforcement. La migration est une séquence de points irréversibles — c'est pour ça qu'elle se présente à l'humain, périmètre par périmètre. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
