---
description: Prépare un point irréversible et demande l'arbitrage de modalité au PO
argument-hint: "[nom du point, ex. bascule-n2-medecins]"
---

Un **point irréversible** est atteint. Applique le protocole de `pilote/arbitrage.md` — **sans
exécuter la bascule** :

1. Identifie le point ($ARGUMENTS) dans le tableau de `pilote/arbitrage.md`.
2. **Assemble la preuve** exigée (tests 4 couches + caractérisation + régression visuelle selon
   le point) et vérifie qu'elle est verte via `gate-runner`.
3. **Écris une entrée 🔴 « arbitrage en attente »** dans le registre : preuve jointe + question de
   **modalité** (timing / séquençage / rollback) + 2–3 options.
4. **Présente au PO** l'état, la preuve et la question. **Arrête-toi.** Ne committe rien
   d'irréversible, ne supprime aucun legacy.

Quand le PO tranche : écris l'**ADR** (décision + pourquoi + alternatives écartées), déplace
l'entrée en ✅ dans le registre, puis exécute uniquement la modalité choisie.
