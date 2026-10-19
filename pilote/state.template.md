<!--
  Registre d'état Foyer — SOURCE DE VÉRITÉ PARTAGÉE (PO ↔ dev).
  Copier ce gabarit à la racine du projet (RETROFIT.md / RELEASE.md / PROJET.md).
  Tout agent LE LIT avant d'agir et LE MET À JOUR à chaque étape conclusive.
  Markdown volontairement lisible : le PO (ChatGPT/Qwen) doit le comprendre sans outil.
-->
# État Foyer — <NOM DU PROJET>

- **Porte active** : `nouveau` | `rétrofit` | `release` | `exploitation`  <!-- une seule, sauf `exploitation` qui coexiste avec une autre tant que le produit tourne -->
- **Parcours** : `pilote/journeys/<porte>.md`
- **Archétype** : stateless | stateful | api-first | full-stack  <!-- défaut inféré, cf. defaults.md -->
- **Niveau CyFun® visé** : Basic | Important | Essential  <!-- défaut inféré, cf. defaults.md ; abaissement sous Essential = ADR -->
- **Substrat d'exécution** : runtime local | conteneur (Docker) | …  <!-- sonde 0bis, cf. parcours.md -->
- **Démarré le** : AAAA-MM-JJ
- **Dernière mise à jour** : AAAA-MM-JJ (par : <agent/humain>)

## Répartition des rôles

| Rôle | Qui | Depuis |
|---|---|---|
| **PO** (tranche les modalités, valide sur preuve, signe) | <nom> | AAAA-MM-JJ |
| **Dev** (exécute, assemble la preuve, ne tranche jamais) | <nom> + agent | AAAA-MM-JJ |

<!-- Deux chapeaux sur une même personne : la séparation reste ÉCRITE. Un arbitrage se pose en 🔴
     avec sa preuve AVANT d'être tranché, même quand celui qui pose et celui qui tranche sont le même. -->

## Gantt / vagues

- **Gantt** : <chemin du document signé> (signé le AAAA-MM-JJ par <nom>)
- **Vague courante** : <n> · **barrière** : <story habilitante qui doit fermer avant la suivante>
- **Branches ouvertes** : <liste, une par story en cours>
- **Barreau** : Scrum | Nexus | SAFe (ADR <n>)

## Position courante

- **Phase / étape** : <ex. Phase 2 · étape 3 (adaptateurs) · périmètre `X`>
- **Prochaine action attendue** : <une phrase — ce que `/foyer-next` ferait>
- **Rôle à jouer** : `pilote/roles/<rôle>.md`

## Gates (dernier statut)

| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher (secrets · SBOM · conteneur · migrations si stateful) | 🟢/🔴/⚪ | | cf. `pilote/gates/README.md` |
| caractérisation (rétrofit) | 🟢/🔴/⚪ | | |
| verify structurel | 🟢/🔴/⚪ | | |
| contrat (anti-drift) | 🟢/🔴/⚪ | | |
| tests 4 couches | 🟢/🔴/⚪ | | |
| E2E (correctness) | 🟢/🔴/⚪ | | |
| régression visuelle (si D2) | 🟢/🔴/⚪ | | |
| doc vivante (preuve de valeur) | 🟢/🔴/⚪ | | non bloquant |
| jalon (SAST · SCA · qualité) | n findings | | rapport, non bloquant, trié en gate review |

**Dernière gate review** : AAAA-MM-JJ · autoévaluation CyFun : seuils atteints oui / non, n écarts (`skills/conformite.md` §2quater)

## Périmètres / backlog

<!-- rétrofit : un périmètre par ligne ; nouveau/release : une story « Agent IA Ready » par ligne -->

| Périmètre / story | État | Couches vertes | Bascule | Commit / ADR | Tours | Tokens | Wall-clock |
|---|---|---|---|---|---|---|---|
| <ex. periods> | migré | D/A/Ad/C/F1/F2 | n°2 ✅ | `retrofit(periods): …` | <n> | <k> | <h> |

<!-- Télémétrie : relevée à la clôture de chaque story. Sans elle, le CSI n'a rien à recaler et les
     priors [caler] de l'abaque ne se resserrent jamais (gilmry/foyer#10). -->

## Promotions

| Branche | Preuve complète (gate `promotion`) | Minutes d'arbitrage | Diff ouvert ? (pourquoi) | Décision | Le |
|---|---|---|---|---|---|
| <branche> | 🟢/🔴 | <min> | non / oui : <raison> | promue / renvoyée | AAAA-MM-JJ |

<!-- Relevé de l'arbitre de promotion (pilote/roles/arbitre-de-promotion.md). Chaque « oui » dans
     la colonne diff est un échec de la preuve, pas de l'arbitre (gilmry/foyer#7). -->

## Arbitrages

### 🔴 En attente (l'humain doit trancher une MODALITÉ)

<!-- Une entrée par point irréversible atteint. L'agent NE tranche PAS. -->
- **Point** : <ex. bascule n°2 — frontend D2 périmètre `medecins`>
  - **Preuve jointe** : <E2E vert + régression visuelle verte 3 rôles + …>
  - **Question de modalité** : <ex. lance-t-on l'écran îlots maintenant ? quels parcours critiques ? rollback ?>
  - **Options présentées** : <A / B / C>

### ✅ Tranchés

| Point | Décision (modalité) | Par | Le | ADR |
|---|---|---|---|---|
| | | | | |

## Journal (chronologie courte)

- AAAA-MM-JJ — <événement> (commit `…`)
