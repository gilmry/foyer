# Parcours NOUVEAU PROJET (greenfield)

> Fait autorité : [`../../skills/bootstrap-nouveau-projet.md`](../../skills/bootstrap-nouveau-projet.md)
> pour l'instanciation du kit, [`../../bmad/BMAD-Conception.md`](../../bmad/BMAD-Conception.md)
> pour la conception. On **part de zéro** : le kit `foyer/kit-php` est la destination et le point
> de départ. La conception BMAD précède tout code.

## Phase A — Conception BMAD (avant tout code)
- **Rôle** : [`../roles/conception-bmad.md`](../roles/conception-bmad.md)
- **Faire** (personas `../../bmad/personas/` + livrables `../../bmad/livrables/`) :
  1. **Analyste** → *product-brief* (problème, valeur, contraintes).
  2. **Product Manager** → *PRD* + *epics/stories*.
  3. **Architecte** → choix d'**archétype** (`../../bmad/archetypes.md`) + *architecture*.
  4. **Scrum Master / Validateur** → backlog de **stories « Agent IA Ready »** validées.
- **Chiffrage** : [`../../skills/abaque-cout-capacite.md`](../../skills/abaque-cout-capacite.md).
- **Arbitrage** : choix d'archétype (fixe les gates conditionnels) — cf. `../arbitrage.md`.
- **Sortie** : backlog priorisé « Agent IA Ready » + archétype engagé (inscrits au registre).

## Phase B — Bootstrap du kit (les 7 gestes)
- **Rôle** : conception-bmad → puis extracteur-couche / frontend-ilots pour le 1er domaine.
- **Gestes** (`../../skills/bootstrap-nouveau-projet.md`) :
  1. Archétype retenu → poser le kit correspondant.
  2. **Reproductibilité** en une commande (`../../skills/bootstrap-delivrabilite.md`).
  3. **Vérifier le kit** (gates verts « à vide ») — [`../gates/README.md`](../gates/README.md).
  4. **Premier domaine** : Domaine pur → cas d'usage → adaptateurs → contrat (ordre des couches).
  5. **Frontend découplé + 2 harnais** : parcours de référence unique → E2E (gate) **et**
     **doc vivante** (preuve de valeur) — [`../roles/frontend-ilots.md`](../roles/frontend-ilots.md).
  6. **AGENTS.md du projet** (le contrat agent) : dérivé du kit — architecture + sa loi,
     commandes, harnais, gates, règles de l'agent (*ne jamais modifier `vendor/`*).
  7. **Points irréversibles** posés (cf. `../arbitrage.md`).
- **Sortie** : squelette exécutable, gates 🟢, 1re story livrée avec sa preuve de valeur.

## Phase C — Cycle-dev sur le backlog
- **Rôle** : extracteur-couche + frontend-ilots, boucle `../../skills/cycle-dev.md` (rouge/vert/bleu).
- **Faire** : dérouler les stories « Agent IA Ready », un commit par étape conclusive, la doc
  vivante s'enrichit du même parcours de référence.
- **Sortie** : incréments livrés, gates verts, preuve de valeur à jour.

> La différence avec la porte **release** : ici on part d'un dépôt vide (bootstrap du kit) ;
> là-bas on applique la conception BMAD à un produit **existant** puis on enchaîne le cycle-dev.
