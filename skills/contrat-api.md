# Skill — Contrat API matérialisé (prévenir le drift front↔back)

*Skill du dispositif, spécifique à la facette **full-stack** (et applicable à *API-first*). Hérite de `../Boucle-de-retroaction.md` ; compose `bootstrap-delivrabilite.md` et `enforcement.md`. Née d'un incident réel : OpenMajor/Taginy, juillet 2026 — voir cas d'étude ci-dessous.*

> **Le piège.** `archetypes.md` marque « Contrat API (OpenAPI) » `✓` pour full-stack. Un agent (ou un superviseur pressé) lit ce `✓` comme « il existe une section qui décrit les conventions REST » et considère la case cochée. Ce n'est pas ce que `✓` doit vouloir dire : un contrat **décrit** n'est pas un contrat **matérialisé**. Sans mécanisme qui rend la dérive impossible à ignorer, le contrat se délite route par route, silencieusement, jusqu'à casser un flux critique en production.

---

## Cas d'étude — OpenMajor/Taginy (juillet 2026)

Le premier passage BMAD (v1.0) avait déclaré l'archétype `stateful full-stack`, rempli PRD §9bis « Contrat API » en prose (conventions REST, auth Bearer) et conclu à un MVP « 85 % livré ». Un testing E2E piloté par agent a ensuite rendu un verdict **NO-GO** sur deux bugs bloquants confirmés par code HTTP, et un audit structurel a chiffré la dérive :
- **145 routes backend, 0 annotées** (aucun schéma OpenAPI généré — la « spec » n'existait que dans la tête du code).
- **`api.ts` de 2134 lignes maintenu à la main** côté frontend + **27 appels `fetch` inline** non typés, dupliquant silencieusement les DTO backend.
- Dérive de casing non détectée à la compilation : un DTO paiement en `PascalCase` face à un autre en `snake_case` sur le même flux.
- Dérive de nommage : un même champ produit lu `base_price` et écrit `price`.
- Dérive de placement : un `seller_id` porté tantôt par l'URL, tantôt par le body selon l'endpoint — **cause racine directe** d'un bug bloquant (500 systématique sur la création de partenariat).
- Surface admin entière non typée (`getJson<any>`).

Aucun de ces signaux n'était visible en lisant PRD §9bis v1.0 — la section existait, décrivait des conventions plausibles, et **masquait** l'absence totale de mécanisme de synchronisation. Le contrat était un vœu, pas un artefact.

## Ce qui rend un contrat réellement matérialisé (et pas seulement documenté)

Pour toute facette **full-stack** (et *API-first*), les quatre éléments suivants sont **non optionnels**, à poser dès le Sprint 0 (story habilitante, `bootstrap-delivrabilite.md`) — pas en GO-forward, pas « si le temps le permet » :

1. **Annotation exhaustive à la source** — chaque route et chaque DTO annotés (ex. `utoipa` en Rust, `drf-spectacular` en Python, décorateurs OpenAPI en TS) de sorte que le spec **se génère depuis le code**, jamais l'inverse. Un sous-ensemble « routes critiques seulement » reproduit le problème à plus petite échelle : la dérive migre vers les routes non annotées.
2. **Client frontend généré, jamais écrit à la main** — codegen depuis le spec (ex. `openapi-ts`, `orval`, `openapi-generator`) pour types **et** fonctions d'appel. Un fichier API hand-rolled qui coexiste avec le codegen recrée la double-maintenance qu'on cherche à éliminer ; la bascule doit être totale (big-bang) ou strictement scoping-isolée avec date de fin.
3. **Désérialisation stricte** — `deny_unknown_fields` (ou équivalent) sur tous les DTO de body/query. Sans ça, un champ qui dérive silencieusement (renommé, oublié, mal placé) ne casse rien à la compilation ni en test superficiel — il échoue en silence, exactement comme le bug #1 d'OpenMajor (stock/statut ignorés côté serveur, `200 OK` renvoyé quand même).
4. **Tests contract en CI** — spec-sync (le spec généré correspond au code déployé), et endpoints-exist (chaque route documentée répond, chaque route appelée par le front existe). Anneau 3 (`enforcement.md`) : ce test doit vivre en CI, pas seulement en boucle agent — sinon un sous-agent peut le contourner en déléguant (limite connue de l'anneau 2).

Les quatre ensemble ferment la boucle : (1) empêche d'oublier d'annoter, (2) empêche la duplication manuelle, (3) transforme un drift silencieux en échec bruyant, (4) empêche la régression de passer inaperçue jusqu'au merge.

**Ce skill ne couvre que D1 (la dimension contrat).** Un frontend découplé (client généré, aucun `fetch`/URL en dur) n'est **pas** un frontend *rendu* conformément au moule : la dimension **D2 (rendu — îlots-first, Astro + îlots Svelte)** est une décision à part, tranchée par la **règle de sobriété** de `migration-projet-existant.md` (obligatoire si le front porte la dérive, sinon ADR) et posée par défaut dans `bootstrap-nouveau-projet.md` (geste 5). D1 sans D2 tranchée = un front qui consomme le contrat mais dont l'apparence n'est ni prouvée ni engagée.

## Où ça se rattache dans BMAD

- **Product Manager (A2)** — PRD §9bis n'est pas satisfait par de la prose décrivant des conventions. Doit nommer le mécanisme concret : outil d'annotation, emplacement du fichier spec généré, outil de codegen. Une section §9bis purement descriptive est un signal à remonter, pas une case cochée.
- **Architecte (A3)** — pour tout archétype full-stack (ou API-first), produit un **ADR de matérialisation du contrat** (outil d'annotation, stratégie de codegen, politique `deny_unknown_fields`, adossement CI) **avant** le début de la Phase 1 des cycles. C'est un point à traiter avec le même sérieux que la migration de schéma (`archetypes.md` § stateful) : coûteux à retrofit une fois le drift installé — mieux vaut le poser dès le socle que le découvrir via un testing report NO-GO.
- **Scrum Master (A4)** — la story habilitante (Sprint 0, `bootstrap-delivrabilite.md`) d'un projet full-stack **inclut** le harnais contrat (annotation + codegen + `deny_unknown_fields` + contract tests CI) comme sous-story non optionnelle, séquencée avant ou avec la première story métier — jamais reléguée en GO-forward. Sur un projet *existant* qui n'a jamais eu ce harnais (rétrofit, comme OpenMajor), c'est une story de correction structurelle dédiée, dimensionnée à part, qui **bloque** le reste tant qu'elle n'est pas fermée.
- **Validateur (A5)** — ajoute au barème de fidélité un critère explicite : « contrat matérialisé (annotation + codegen + désérialisation stricte + contract tests), pas seulement décrit ». Une section §9bis remplie en prose sans ces quatre éléments cités nommément est un défaut à signaler, même si la traçabilité Brief→PRD→Archi est par ailleurs cohérente.

## Conditionnement

- **Stateless / API-first sans frontend propre** : le contrat est déjà `✓` premier rang (`archetypes.md`), ce skill s'applique presque tel quel (moins l'élément 2, pas de client généré si aucun frontend interne au périmètre).
- **Full-stack** : les quatre éléments s'appliquent intégralement — c'est la combinaison qui a fait défaut chez OpenMajor. Ils couvrent **D1** ; la dimension **D2 (rendu)** se décide en regard de la règle de sobriété (`migration-projet-existant.md`) : îlots-first par défaut, ADR sinon.
- **Petit projet (Micro/Petit, 1-3 BC)** : l'investissement en outillage codegen peut sembler disproportionné au premier coup d'œil — il ne l'est pas dès que le projet dépasse une poignée d'endpoints, precisément parce que le coût de la dérive est asymétrique (invisible jusqu'au NO-GO). Ne pas sauter les 4 éléments sous prétexte de petite taille ; en réduire éventuellement le formalisme de l'ADR, pas le mécanisme lui-même.
- **Stack sans écosystème d'annotation** — les quatre éléments s'appliquent, mais leur **mécanisation** (spec générée du code, codegen automatique) est **câblée** à un framework qui sait annoter (ApiPlatform, utoipa, drf-spectacular…). Pour le **kit** (et tout nouveau projet), la stack **est** ApiPlatform : les quatre éléments y sont mécanisés tels quels. Un projet **existant** sur une stack qui n'a pas d'annotation (PHP vanilla, no-Composer) se rapproche du kit en deux temps : (a) **transitoire** — miroiter les gates sur la stack existante (spec écrite à la main + codegen scripté + check de synchronisation), un contrat **plus faible** (la spec est un artefact maintenu à la main, le même risque de dérive silencieuse qu'un client manuel), acceptable **pendant** la migration ; (b) **destination** — la stack du kit (ApiPlatform), point d'arrivée fixé de `migration-projet-existant.md` : l'arbitrage humain porte sur les **modalités** de bascule (quand, rebase ou strangler), jamais sur le fait d'y arriver. Le résidu « gates miroités » doit apparaître au diagnostic de dérive jusqu'à extinction.

---

*Registre : les éléments 1-3 sont du code (anneau substrat par construction — un DTO non annoté ne compile pas contre le spec) ; l'élément 4 est de l'enforcement CI (anneau 3, `enforcement.md`). Dérivé du Manifeste Maury (CC BY-SA 4.0).*
