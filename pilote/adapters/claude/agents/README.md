# Sous-agents Claude Code — un par rôle du pilote

Chaque sous-agent est un **fin pointeur** vers un rôle du cœur (`pilote/roles/*.md`), qui lui-même
référence le skill/persona/bmad faisant autorité. On ne duplique pas la méthode dans l'agent.

## Patron d'un fichier sous-agent (`.claude/agents/<nom>.md`)
```markdown
---
name: foyer-<rôle>
description: <quand déléguer à cet agent — une phrase>
tools: Read, Grep, Glob, Bash, Edit, Write
---
Tu joues le rôle **<rôle>** du pilote Foyer. Ta référence unique de comportement est
`pilote/roles/<rôle>.md` (et les skills qu'il cite). Lis d'abord le registre d'état du projet,
respecte l'ordre des couches et les gates, et **ne tranche jamais un point irréversible**
(remonte-le via le protocole `pilote/arbitrage.md`). Termine en mettant à jour le registre.
```

## Table des sous-agents à créer
| Sous-agent | Rôle du cœur | Quand déléguer |
|---|---|---|
| `foyer-conception-bmad` | `roles/conception-bmad.md` | portes nouveau/release, avant tout code |
| `foyer-diagnostic` | `roles/diagnostic.md` | rétrofit phase 0 (mesurer la dérive) |
| `foyer-harnais` | `roles/harnais.md` | rétrofit phase 1 (repro + plancher + caractérisation) |
| `foyer-extracteur-couche` | `roles/extracteur-couche.md` | phase 2 (domaine→app→adaptateurs→contrat) |
| `foyer-frontend-ilots` | `roles/frontend-ilots.md` | D1/D2 + doc vivante |
| `foyer-gate-runner` | `roles/gate-runner.md` | invoquer/lire les gates |
| `foyer-verrouillage` | `roles/verrouillage-convergence.md` | phases 3-4 |

> Créer ces fichiers = recopier le patron en remplaçant `<rôle>`. Ils restent volontairement
> minimalistes : toute l'intelligence est dans `pilote/roles/` + les skills.
