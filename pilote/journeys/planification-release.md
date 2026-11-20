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

## Phase A bis — Pilotage (entre le PASS et le code)
- **Rôle** : [`../roles/pilotage.md`](../roles/pilotage.md) (persona `../../personas/chef-de-projet.md`)
- **Faire** : WBS → dépendances déclarées → Gantt en passes d'agent → vagues et barrières → coût
  comparé à la target de challenge → proposition de barreau.
- **Arbitrage** : **choix du barreau** (irréversible) et validation du Gantt — cf. `../arbitrage.md`.
- **Sortie** : Gantt validé par l'humain, vagues et répartition des rôles inscrites au registre.

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
- **Sortie** : release prête, gates verts, preuve de valeur à jour, un commit par étape
  (`release(<périmètre>): <étape>`).

## Phase D — Clôture
- **Rôle** : [`../roles/verrouillage-convergence.md`](../roles/verrouillage-convergence.md)
- **Faire** : CI verte bloquante, tag de release, registre à jour (backlog soldé, ADR des
  arbitrages tranchés).
- **Sortie** : le head de la branche source de vérité porte le tag. Une promotion de branche, s'il
  y en avait une, est déjà jugée (gate `promotion`, `../roles/arbitre-de-promotion.md`) : la
  phase L livre ce head, elle ne promeut rien.

## Phase L — Livrer (quand tout est vert, sans qu'on le demande)
- **Déclencheur** : **tous les gates bloquants verts sur le head**, gate `deploiement` compris
  ([`../gates/README.md`](../gates/README.md)). Le pilote n'attend pas qu'on lui demande de livrer.
- **Rôle** : [`../roles/deployeur-heberge.md`](../roles/deployeur-heberge.md) (persona
  `../../personas/platform-engineer.md`, skill `../../skills/deploiement-heberge-infogere.md`).
  Le rôle choisit lui-même sa séquence : premier déploiement, ou redéploiement.
- **Cible** : lue au bloc « Cible de déploiement » du registre. Remplie : on entre dans la phase
  **sans poser de question**. Absente : le pilote la demande **une fois**
  ([`../parcours.md`](../parcours.md), § Cible de déploiement).
- **Seul arrêt d'un redéploiement** : une **migration de schéma** dans la release (`../arbitrage.md`).
  Un smoke public rouge n'est pas un arrêt : le rôle remet la version précédente et l'écrit.
- **Sortie** : smoke e2e vert contre l'adresse publique, **version en service inscrite au
  registre**. À la première livraison réussie, la porte `exploitation` s'ouvre
  ([`exploitation.md`](exploitation.md), E0) et coexiste avec celle-ci.
- **Hors de cette phase** : un projet livré par un serveur que l'on administre ou par une
  plateforme (`../../skills/convergence-iac.md`) ne passe pas par ce rôle : la phase est alors
  sans objet, et le registre le dit (cible « aucune »).
