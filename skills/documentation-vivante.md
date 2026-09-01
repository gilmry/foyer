# Skill — Documentation vivante (la preuve de valeur)

*Skill du dispositif, spécifique à la facette **full-stack** (et, en version allégée, à *API-first*). Hérite de `../Boucle-de-retroaction.md` ; compose `contrat-api.md` (le harnais de *correctness*), `cycle-dev.md` (le bleu) et `enforcement.md` (le substrat). Le moule de référence est `../../kit-php/` (`frontend/journeys/` + `frontend/docs-living/`).*

> **Le piège.** Un projet full-stack peut **passer tous ses gates** — domaine, BDD, contrat, E2E — et rester **inutilisable pour un humain** : les parcours ne sont que des lignes vertes dans un CI, personne ne voit *à quoi ça ressemble*, et la doc qui montrerait ça n'existe pas (ou s'est érigée). La « Documentation Vivante » décrite en prose dans `bmad/archetypes.md` et le PRD §9 se corrompt silencieusement : elle est **écrite à part**, et une chose écrite à part **s'effondre** dès qu'on ne la met pas à jour. Le défaut n'est pas l'absence de test E2E (ça, `contrat-api.md` / `cycle-dev.md` s'en chargent) : c'est l'absence d'un **rendu du parcours, en valeur, qui ne peut pas s'éroder**.

---

## Deux lectures d'un même parcours — le principe fondateur

Le problème n'est pas de *plus* de tests : c'est que le test et la preuve de valeur doivent être **la même chose, lue deux fois**. Un **parcours de référence** est écrit **une seule fois** (source de vérité partagée), et deux **harnais distincts** le rejouent :

| | **E2E** (correctness) | **Preuve de valeur** (documentation vivante) |
|---|---|---|
| Rejoue le parcours | **à la vitesse** | **en cadence — 1 action, 1 seconde** |
| Rend | vert / rouge | **galerie HTML + captures + vidéo** |
| Bloquent le build ? | **oui** (gate) | **non** (rapport) |
| Répond à | « le parcours **marche**-il ? » | « à quoi ça **ressemble** pour un humain ? » |
| En CI | job bloquant | job non bloquant, **artefact** publié |

C'est **`contrat-api.md`** en miroir : là, on empêche la dérive du *contrat* (correctness) ; ici, on produit et on **garantit** la *valeur lisible* du parcours. Les deux ne se remplacent pas — un parcours peut être *correct* (test vert) et *incompréhensible* (aucune preuve de valeur), et inversement.

## Le troisième harnais — la régression visuelle (la dimension D2)

Les deux harnais ci-dessus répondent de **l'existence** de l'écran (ça marche, ça se voit). Ils ne répondent pas de **l'invariance** de l'apparence — et c'est exactement ce que la **bascule de rendu D2** (îlots-first, `migration-projet-existant.md` étape 6) exige de prouver : l'écran migré doit **ressembler à l'écran qu'il remplace**.

Le **troisième harnais** consomme **le même parcours partagé** et ajoute une lecture :

| | **Régression visuelle** (apparence) |
|---|---|
| Rejoue le parcours | à la vitesse, **avant et après** la bascule D2 |
| Rend | **goldens** (captures de référence) + comparaison (diff, tolérance définie) |
| Bloquent le build ? | **oui** — c'est la gate de la bascule n°2 |
| Répond à | « l'écran migré **ressemble**-il à l'ancien ? » |

Deux règles, sinon le harnais se délite :

1. **Les goldens sont dérivés du rendu ancien** — capturés sur le parcours partagé **avant** la bascule, jamais recopiés à la main, jamais « recalés » sur le nouveau rendu (un golden dérivé du nouveau prouve que le nouveau est égal à lui-même).
2. **L'invariant anti-recopie** — comme l'invariant anti-dette (4) : le harnais visuel **doit** importer le parcours partagé, et la référence doit être une **capture**, pas un artefact dessiné — sinon le harnais ne prouve plus rien.

Ainsi le parcours partagé rejoué une seule fois porte **trois lectures** : correctness (E2E), valeur (cadence), apparence (goldens) — la même anti-dérive que `contrat-api.md`, appliquée au rendu.

## Ce qui rend une preuve de valeur réelle (et pas décorative)

Quatre éléments, **non optionnels**, à poser comme le harnais de contrat (pas en GO-forward) :

1. **Une source de vérité partagée — le parcours.** Le parcours de référence est un **artefact unique** (ex. `journeys/contact.journey.ts` : étapes id + description en langage métier + action + assertion), consommé **par les deux harnais**. Pas de copie du parcours dans le test *et* dans la doc. Si le parcours n'est pas le même objet des deux côtés, on a recréé la double-maintenance que ce skill est censé éliminer.

2. **Le rythme — 1 action, 1 seconde.** La preuve de valeur rejoue le parcours **en cadence** : une action, une pause (≈ 1 s), une capture. Ce n'est **pas un film ralenti** (ça ne prouverait rien de plus, ça coûterait du wall-clock) : c'est un **pas lisible par l'œil** — l'humain perçoit chaque geste (remplir → valider → voir le résultat) et la capture correspond exactement à l'état après l'action. La cadence est une **constante nommée**, pas un chiffre magique.

3. **Un harnais séparé, rendu en CI comme rapport (jamais bloquant).** La preuve de valeur **n'est pas un test** : elle ne doit pas faire tomber le build. C'est un **harnais distinct** (sa propre config, son propre runner) qui rejoue le parcours, capture les étapes et la vidéo, et **publie une galerie HTML** en artefact CI (non bloquant). La mélanger au gate E2E (le rendre lent et bloquant) ou en faire un test qu'on « attend » de réussir, c'est lui confier la responsabilité qu'on ne peut pas lui confier (le verdict) — et ça finira coupé du pipeline.

4. **L'invariant qui interdit la dette de documentation.** Un **invariant structurel** (ex. `verify.php`) oblige **chaque harnais à importer le parcours partagé** : un harnais de valeur qui ne rejoue plus le parcours (c'est-à-dire qu'on a recoupé la doc à la main) fait passer la suite au **rouge**. C'est l'anneau substrat de ce skill : la doc n'est pas « mise à jour », elle est **dérivée** du parcours rejoué, et on ne peut pas la découpler du test sans déclencher le rouge.

Les quatre ensemble ferment la boucle : (1) empêche la double-maintenance, (2) rend le rendu *lisible* (pas une séquence de captures ininterrogeables), (3) donne à la valeur un **lieu** (artefact CI) sans en faire un verdict, (4) rend la dérive de la doc **impossible à ignorer**.

## Pourquoi il n'y a pas de dette de documentation

La dette de documentation, c'est une doc **écrite à part** qu'on ne met plus à jour. Ce skill la rend **structurellement impossible** par deux verrous simultanés :

- **La doc est dérivée, pas écrite.** Elle est produite en **rejouant** le parcours (captures + vidéo + galerie), pas rédigée. Il n'y a pas de page à synchroniser avec le code.
- **Le parcours est écrit au fil de l'eau.** Le parcours de référence est posé **avec** la fonctionnalité, dans le même geste que son test (le `cycle-dev.md` bleu). On n'écrit pas « la doc » après coup : on ajoute **une étape au parcours** (et son assertion) au moment où l'écran existe.

Deux conséquences opérationnelles : il n'y a **pas de phase** « il faut maintenant écrire la doc » (donc pas de dette accumulée en fin de sprint), et la preuve de valeur est **toujours à jour** parce qu'elle *est* le test rejoué.

## Où ça se rattache dans BMAD

- **Product Manager (A2)** — PRD §9 « Documentation Vivante » ne se satisfait plus d'une *liste de flux à couvrir* : il doit nommer le **parcours de référence** (l'artefact unique) et le **rendu** (galerie + captures + vidéo, cadence). Le « flux critique » n'est plus un souhait : c'est une entrée du parcours partagé.
- **Architecte (A3)** — pour le full-stack, pose un **ADR de la preuve de valeur** (source de vérité partagée, cadence, harnais séparé non bloquant, invariant anti-dette) avec le même sérieux que l'ADR de matérialisation du contrat (`contrat-api.md`) : c'est le second harnais du full-stack, et le laisser au « GO-forward » reproduit le piège (vertes CI, aucune valeur lisible).
- **Scrum Master (A4)** — la story habilitante (Sprint 0) d'un full-stack **monte les deux harnais** comme le harnais de contrat : E2E (gate) **et** preuve de valeur (rapport), sur le même parcours, dès le socle. Pour un *existant* sans ça, c'est une story de correction structurelle dédiée.
- **Validateur (A5)** — ajoute au barème : « preuve de valeur **matérialisée** (parcours partagé + cadence + harnais séparé + invariant anti-dette), pas seulement une liste de flux ». Une section §9 remplie en prose sans ces quatre éléments est un défaut, même si le reste est cohérent.

## Conditionnement par archétype

- **Full-stack** — les quatre éléments s'appliquent intégralement : c'est la combinaison que le kit démontre (`frontend/journeys/` → `frontend/e2e/` + `frontend/docs-living/`). La **régression visuelle** (troisième harnais) s'ajoute dès qu'une **bascule D2** (îlots-first) est engagée : c'est sa gate.
- **API-first** — il n'y a **pas de frontend à filmer** : la preuve de valeur n'est pas un parcours filmé, elle est le **contrat matérialisé** (les contract tests de `contrat-api.md`) qui prouve, pour un consommateur, ce que l'API vaut. Le skill se réduit à « la valeur lisible = le contrat », mais l'idée (valeur objectivée, pas décrite) reste.
- **Stateless** — pas de parcours UI ; la preuve de valeur est la doc des fonctions/contrats, le cadence ne s'applique pas.
- **Petit projet (1-3 BC)** — même logique, un seul parcours de référence suffit souvent ; la cadence et l'harnais séparé restent (le coût de la preuve de valeur dérivée est quasi nul, celui de la doc érigée est asymétrique).

## Les pièges connus (et leur antidote)

| Piège | Adhésion tentante | L'antidote |
|---|---|---|
| « L'E2E vert, c'est déjà la preuve » | un harnais de moins | L'E2E prouve **correctness** (ça marche). La preuve de valeur prouve **lisible** (à quoi ça ressemble). Un parcours peut être correct et incompréhensible. Deux harnais, une lecture de plus. |
| « La doc, on l'écrit à la fin du sprint » | la phase doc en bout | C'est **exactement** la dette. La preuve de valeur est **dérivée** du parcours rejoué, et le parcours est écrit **au fil de l'eau** avec la feature. Pas de phase, pas de dette. |
| « On met la capture dans le test E2E » | un seul harnais | Le gate doit rester **rapide et bloquant**. La preuve de valeur est **lente** (cadence) et **non bloquant** : harnais **séparé**, rendu en rapport. Mélanger = le gate devient lent et le rapport devient un verdict. |
| « 1 seconde par action, c'est arbitraire / long » | pas de pause (plus vite) ou pause longue (plus « joli ») | 1 s est le **pas lisible par l'œil** : assez pour percevoir l'état après l'action, pas un film ralenti. C'est une **constante nommée** (réglable), pas un décor. |
| « La galerie, on la commit comme code source » | le rendre éditable | C'est un **artefact dérivé** (comme le client généré de `contrat-api.md`) : **on ne l'édite jamais à la main**, on rejoue le parcours. L'invariant (4) verrouille le lien parcours↔doc. |

## Les points à présenter à l'humain

La preuve de valeur n'est pas un point irréversible, mais deux **jugements** sont humains : (1) **quels parcours comptent comme « critiques »** (le choix de ce qu'on filme, c'est le choix de ce qu'on dit valoir la peine d'être vu) ; (2) **le verdict de valeur** — l'humain regarde la galerie et dit « c'est bien / ça ne va pas », ce qu'aucun gate ne peut remplacer. L'agent produit la preuve ; l'humain en tire le jugement.

---

*Registre : les éléments 1-2 sont du code (le parcours, le runner cadencé) ; l'élément 3 est de l'enforcement CI (rapport non bloquant, `enforcement.md` anneau 3) ; l'élément 4 est un invariant substrat (un harnais qui ne rejoue plus le parcours ne passe pas). Dérivé du Manifeste Maury (CC BY-SA 4.0).*
