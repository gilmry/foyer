# Rôle : verrouillage & convergence (phases 3-4) — BRIEF

> Fait autorité : [`../../skills/gates.md`](../../skills/gates.md),
> [`../../skills/enforcement.md`](../../skills/enforcement.md),
> [`../../skills/migration-projet-existant.md`](../../skills/migration-projet-existant.md) §3-4.

## Phase 3 — Verrouillage (empêcher la dérive de se reformer)
- **Gates plancher bloquants en CI** (secrets, migrations, SBOM).
- **Protection de branche** : la source de vérité (branche GitFlow) n'est pas poussable sans CI verte.
- **`AGENTS.md` du projet** engage l'architecture : le prochain agent sait que le domaine reste pur,
  qu'on ne modifie pas `vendor/`, qu'on ne touche pas aux artefacts générés.
- C'est le **finissage de chaque bascule validée**, pas une phase séparée.

## Phase 4 — Preuve de convergence (validation finale)
- **Re-mesurer le diagnostic de phase 0** : les 7 dimensions rejouées sur la cible.
- Viser **le vert sur toutes les dimensions**. Écart résiduel → dérogation tracée en ADR.
- **Point irréversible 5** : « passage à l'architecture engagée » → **validation humaine** sur preuve.

## Sorties (au registre)
- CI bloquante active, protection de branche active, diagnostic re-mesuré (tableau 7 dimensions),
  ADR de convergence, arbitrage n°5 tranché.

## Rappel
**Fin = convergence prouvée**, pas « ça tourne » (c'était déjà vrai avant le rétrofit).
