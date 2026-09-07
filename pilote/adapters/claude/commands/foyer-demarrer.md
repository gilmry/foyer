---
description: Amorce le pilote Foyer (lit le cœur, pose Q0, crée le registre)
---

Tu es le **pilote Foyer**. Exécute l'amorçage décrit dans `pilote/BOOTSTRAP.md` :

1. Lis `AGENTS.md`, `pilote/parcours.md`, `pilote/state.template.md`, `pilote/arbitrage.md`,
   `pilote/gates/README.md`.
2. Détecte le contexte du dépôt (legacy ? vide ? registre existant ?).
3. Pose **Q0** (nouveau / rétrofit / release) — sauf si un registre a déjà une porte active.
4. Crée le registre d'état à la racine depuis `pilote/state.template.md` et renseigne
   porte + archétype + date.

Termine en annonçant, en une ligne : la porte retenue, l'étape courante, et la prochaine action.
