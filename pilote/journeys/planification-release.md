# Parcours PLANIFICATION DE RELEASE (produit existant)

> Fait autorité : [`../../bmad/BMAD-Conception.md`](../../bmad/BMAD-Conception.md) pour cadrer,
> [`../../skills/cycle-dev.md`](../../skills/cycle-dev.md) pour exécuter,
> [`../../skills/abaque-cout-capacite.md`](../../skills/abaque-cout-capacite.md) pour chiffrer.
> Le produit **tourne déjà** (et est censé conforme) ; on cadre et livre un **gros incrément**.

## Phase A — Conception BMAD ciblée sur la release
- **Rôle** : [`../roles/conception-bmad.md`](../roles/conception-bmad.md)
- **Faire** :
  1. **Analyste** → cadrage de la release (objectif, valeur, périmètre exclu).
  2. **Product Manager** → epics/stories de la release.
  3. **Architecte** → impacts sur l'architecture existante (respecte l'ordre des couches ;
     pas de rupture de contrat non déclarée — `../../skills/contrat-api.md`).
  4. **Validateur** → backlog **« Agent IA Ready »** validé.
- **Chiffrage & capacité** : `../../skills/abaque-cout-capacite.md` (coût tokens + supervision).
- **Arbitrage** : **découpage de release** (quel périmètre, quel ordre, quelle capacité) — cf.
  `../arbitrage.md`. L'IA propose l'ordre optimal, l'humain tranche la modalité.
- **Sortie** : plan de release chiffré + backlog priorisé (inscrits au registre).

## Phase B — Vérifier le socle avant d'ajouter
- **Rôle** : [`../roles/gate-runner.md`](../roles/gate-runner.md)
- **Faire** : passer les gates existants (verify structurel, contrat, tests 4 couches, E2E) pour
  partir d'un **vert connu**. Rouge → corriger la cause **avant** d'empiler la release.
- **Sortie** : socle 🟢 documenté au registre.

## Phase C — Cycle-dev de la release
- **Rôle** : extracteur-couche (back) + [`../roles/frontend-ilots.md`](../roles/frontend-ilots.md) (front)
- **Faire** : dérouler les stories en rouge/vert/bleu, dans l'ordre des couches ; **contrat**
  régénéré (jamais édité à la main) ; **doc vivante** enrichie du parcours de référence (une
  story = un parcours filmé si elle touche un écran critique).
- **Points irréversibles possibles** : bascule de rendu D2 sur un écran refondu, rupture de
  contrat → arbitrage (`../arbitrage.md`).
- **Sortie** : release livrée, gates verts, preuve de valeur à jour, un commit par étape
  (`release(<périmètre>): <étape>`).

## Phase D — Clôture
- **Rôle** : [`../roles/verrouillage-convergence.md`](../roles/verrouillage-convergence.md)
- **Faire** : CI verte bloquante, tag de release, registre à jour (backlog soldé, ADR des
  arbitrages tranchés).
