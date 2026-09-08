<!--
  Registre d'état Foyer — SOURCE DE VÉRITÉ PARTAGÉE (PO ↔ dev).
  Copier ce gabarit à la racine du projet (RETROFIT.md / RELEASE.md / PROJET.md).
  Tout agent LE LIT avant d'agir et LE MET À JOUR à chaque étape conclusive.
  Markdown volontairement lisible : le PO (ChatGPT/Qwen) doit le comprendre sans outil.
-->
# État Foyer — <NOM DU PROJET>

- **Porte active** : `nouveau` | `rétrofit` | `release`  <!-- une seule -->
- **Parcours** : `pilote/journeys/<porte>.md`
- **Archétype** : stateless | stateful | api-first | full-stack  <!-- défaut inféré, cf. defaults.md -->
- **Substrat d'exécution** : runtime local | conteneur (Docker) | …  <!-- sonde 0bis, cf. parcours.md -->
- **Démarré le** : AAAA-MM-JJ
- **Dernière mise à jour** : AAAA-MM-JJ (par : <agent/humain>)

## Position courante

- **Phase / étape** : <ex. Phase 2 · étape 3 (adaptateurs) · périmètre `X`>
- **Prochaine action attendue** : <une phrase — ce que `/foyer-next` ferait>
- **Rôle à jouer** : `pilote/roles/<rôle>.md`

## Gates (dernier statut)

| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher (secrets/migrations) | 🟢/🔴/⚪ | | cf. `pilote/gates/README.md` |
| caractérisation (rétrofit) | 🟢/🔴/⚪ | | |
| verify structurel | 🟢/🔴/⚪ | | |
| contrat (anti-drift) | 🟢/🔴/⚪ | | |
| tests 4 couches | 🟢/🔴/⚪ | | |
| E2E (correctness) | 🟢/🔴/⚪ | | |
| régression visuelle (si D2) | 🟢/🔴/⚪ | | |
| doc vivante (preuve de valeur) | 🟢/🔴/⚪ | | non bloquant |

## Périmètres / backlog

<!-- rétrofit : un périmètre par ligne ; nouveau/release : une story « Agent IA Ready » par ligne -->

| Périmètre / story | État | Couches vertes | Bascule | Commit / ADR |
|---|---|---|---|---|
| <ex. periods> | migré | D/A/Ad/C/F1/F2 | n°2 ✅ | `retrofit(periods): …` |

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
