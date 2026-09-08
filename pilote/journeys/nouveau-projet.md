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

## Phase B0 — Résoudre le kit (déterministe, jamais bloqué)

Avant de « poser le kit », l'agent le **résout lui-même** (le PO ne fournit aucun indice) :

1. **Kit fourni** dans le dépôt Foyer (`../../kit-php/` et, à terme, les autres de
   [`../../KITS.md`](../../KITS.md)) → choisir celui qui colle à l'archétype/pile (défaut annoncé,
   cf. [`../defaults.md`](../defaults.md)) et l'instancier : `bash docker/build.sh` puis
   `bash harness/ci.sh` doivent passer **à vide/à froid** avant d'ajouter le domaine métier.
2. **Sinon, chercher un seed local** : repos frères du même archétype/pile — motifs
   `*-retrofit-test`, `kit-*`, projets voisins exposant `src/{Domain,Application,Adapter,Http}`.
   Un seed trouvé sert de **gabarit** (on copie le squelette, on retire ses périmètres, on garde
   harnais/gates/codegen/îlots).
3. **Sinon, scaffolder** un squelette minimal conforme à l'archétype (couches + harnais + un gate
   plancher qui passe « à vide »).
4. **Choisir le substrat** (cf. `../parcours.md` 0bis) : si le runtime du kit n'est pas installé,
   exécuter les gates via conteneur. Inscrire kit + substrat au registre, **en une phrase au PO**
   (défaut annoncé, cf. [`../defaults.md`](../defaults.md)), puis continuer sans attendre.

> La pile concrète est un **défaut annoncé**, pas une question au PO (friction F1/F2 du dogfood n°1).

## Phase B — Bootstrap du kit (les 7 gestes)
- **Rôle** : conception-bmad → puis extracteur-couche / frontend-ilots pour le 1er domaine.
- **Gestes** (`../../skills/bootstrap-nouveau-projet.md`) :
  1. Kit résolu en B0 → poser le squelette correspondant.
  2. **Reproductibilité** en une commande (`../../skills/bootstrap-delivrabilite.md`).
  3. **Vérifier le kit** (gates verts « à vide ») — [`../gates/README.md`](../gates/README.md).
  4. **Premier domaine** : Domaine pur → cas d'usage → adaptateurs → contrat (ordre des couches).
  5. **Frontend découplé + 3 harnais** : parcours de référence unique → E2E (gate) **+**
     régression **visuelle** (goldens) **+** **doc vivante** (preuve de valeur, filmée) —
     [`../roles/frontend-ilots.md`](../roles/frontend-ilots.md). Les trois angles vont **jusqu'au
     bout automatiquement** (DoD de `../parcours.md`), sans que le PO les réclame.
  6. **AGENTS.md du projet** (le contrat agent) : dérivé du kit — architecture + sa loi,
     commandes de gates **dans le substrat retenu**, harnais, règles de l'agent.
  7. **Points irréversibles** posés (cf. `../arbitrage.md`).
- **Sortie** : squelette exécutable, **tous les gates 🟢 jusqu'à la preuve de valeur** (E2E +
  visuel + vitrine), 1re story livrée. La preuve de valeur (vitrine) est produite, pas différée.

## Phase C — Cycle-dev sur le backlog
- **Rôle** : extracteur-couche + frontend-ilots, boucle `../../skills/cycle-dev.md` (rouge/vert/bleu).
- **Faire** : dérouler les stories « Agent IA Ready », un commit par étape conclusive, la doc
  vivante s'enrichit du même parcours de référence.
- **Sortie** : incréments livrés, gates verts, preuve de valeur à jour.

> La différence avec la porte **release** : ici on part d'un dépôt vide (bootstrap du kit) ;
> là-bas on applique la conception BMAD à un produit **existant** puis on enchaîne le cycle-dev.
