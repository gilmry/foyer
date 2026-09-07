# Parcours RÉTROFIT (strangler)

> Fait autorité : [`../../skills/migration-projet-existant.md`](../../skills/migration-projet-existant.md).
> Ici : la séquence exécutable (phase → étape → rôle → condition de sortie → gate).
> Invariant : **le harnais précède le métier** ; l'ordre des couches est une loi ;
> legacy et nouveau **coexistent** jusqu'à preuve d'équivalence, puis le legacy est supprimé.

## Phase 0 — Diagnostic de dérive
- **Rôle** : [`../roles/diagnostic.md`](../roles/diagnostic.md)
- **Faire** : mesurer l'écart aux 7 dimensions, consigner l'état initial (ADR + snapshot git).
- **Sortie** : rapport de dérive archivé. **Aucune extraction.**

## Phase 1 — Le harnais avant le métier
- **Rôle** : [`../roles/harnais.md`](../roles/harnais.md)
- **Étapes, dans l'ordre** :
  1. **Environnement reproductible** (`../../skills/bootstrap-delivrabilite.md`).
  2. **Gates plancher** (secrets, migrations réversibles) — [`../gates/README.md`](../gates/README.md).
  3. **Suite de caractérisation** : fige le comportement actuel (bugs compris, documentés).
- **Sortie** : le legacy tourne dans le harnais, **gates plancher + caractérisation verts**.
- **Gate bloquant** : plancher 🟢 et caractérisation 🟢 avant toute extraction.

## Phase 2 — Extraction couche par couche (le cœur)
Itérer **par périmètre** (ordre = arbitrage de séquençage, cf. `../arbitrage.md`).
Pour chaque périmètre, boucle rouge/vert/bleu (`../../skills/cycle-dev.md`), **dans l'ordre** :

| Étape | Rôle | Sortie / gate |
|---|---|---|
| 2.1 Domaine pur | [`../roles/extracteur-couche.md`](../roles/extracteur-couche.md) | tests Unit verts ; `verify` : Domain sans `use Symfony/Doctrine/ApiPlatform` |
| 2.2 Cas d'usage | extracteur-couche | tests BDD (Behat) verts, langage métier |
| 2.3 Adaptateurs (Http/Persistence) | extracteur-couche | tests Intégration + **caractérisation** verts (destination ApiPlatform+Doctrine) |
| 2.4 Contrat API | extracteur-couche | `../../skills/contrat-api.md` : spec+client généré+désérialisation stricte ; gate contrat 🟢 |
| 2.5 Frontend D1 (découplage) | [`../roles/frontend-ilots.md`](../roles/frontend-ilots.md) | `fetch` inline remplacés par le client généré ; **parcours de référence + E2E + doc vivante** |
| 2.6 Frontend D2 (rendu) — **conditionnel** | frontend-ilots | si dérive de rendu mesurée : îlots-first + **régression visuelle** verte |

- **Points irréversibles** rencontrés ici : bascule stack (0), backend (1), frontend D2 (2),
  suppression du périmètre legacy (3) → **arrêt + arbitrage** (`../arbitrage.md`).
- **Un périmètre est « migré »** seulement quand : 4 couches vertes + contrat 🟢 + caractérisation
  prouve le comportement externe inchangé. **Alors** le legacy du périmètre est supprimé (git archive).
- **Commit par étape** : `retrofit(<périmètre>): <étape>`.

## Phase 3 — Verrouillage
- **Rôle** : [`../roles/verrouillage-convergence.md`](../roles/verrouillage-convergence.md)
- **Faire** : gates plancher bloquants en CI ; protection de branche ; `AGENTS.md` du projet
  engage l'architecture. (Finissage de chaque bascule validée, pas une phase à part.)

## Phase 4 — Preuve de convergence
- **Rôle** : verrouillage-convergence
- **Faire** : **re-mesurer le diagnostic de phase 0** ; viser le vert sur les 7 dimensions.
- **Point irréversible 5** : passage à l'architecture engagée → validation humaine.
- **Fin = convergence prouvée**, pas « ça tourne ».
