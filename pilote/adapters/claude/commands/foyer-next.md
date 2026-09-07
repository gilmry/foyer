---
description: Exécute la prochaine étape déterministe du parcours Foyer
---

Applique la **boucle « next »** de `pilote/parcours.md` :

1. Lis le registre → porte active + phase/étape courante.
2. Ouvre `pilote/journeys/<porte>.md` → localise l'étape → identifie le **rôle**
   (`pilote/roles/<rôle>.md`) et sa **condition de sortie**.
3. Vérifie les pré-conditions (gates de l'étape précédente 🟢 — voir `pilote/gates/README.md`).
   Rouge → **stop**, renvoie au rôle `gate-runner`, ne passe pas.
4. **Si l'étape est un point irréversible** (`pilote/arbitrage.md`) → n'exécute PAS : bascule vers
   `/foyer-bascule`.
5. Sinon → joue le rôle, produis la sortie, fais passer les gates, **mets à jour le registre**,
   et **committe** `<porte>(<périmètre>): <étape>`.

Termine par : ce qui a été fait, l'état des gates, et la prochaine action.
