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

## Table des sous-agents (un par rôle, tous écrits)
| Sous-agent | Rôle du cœur | Quand déléguer |
|---|---|---|
| `foyer-conception-bmad` | `roles/conception-bmad.md` | portes nouveau/release, phase A, avant tout code |
| `foyer-pilotage` | `roles/pilotage.md` | phase A bis, entre le PASS BMAD et le code |
| `foyer-diagnostic` | `roles/diagnostic.md` | rétrofit phase 0 (mesurer la dérive) |
| `foyer-harnais` | `roles/harnais.md` | rétrofit phase 1 (repro + plancher + caractérisation) |
| `foyer-extracteur-couche` | `roles/extracteur-couche.md` | extraction ou cycle-dev (domaine→app→adaptateurs→contrat) |
| `foyer-frontend-ilots` | `roles/frontend-ilots.md` | D1/D2 + doc vivante |
| `foyer-gate-runner` | `roles/gate-runner.md` | invoquer/lire les gates |
| `foyer-arbitre-de-promotion` | `roles/arbitre-de-promotion.md` | avant de promouvoir une branche (preuve réunie, décision posée à l'humain) |
| `foyer-verrouillage-convergence` | `roles/verrouillage-convergence.md` | rétrofit phases 3-4, clôture d'une release |
| `foyer-deployeur-heberge` | `roles/deployeur-heberge.md` | phase L : premier déploiement ou reprise, puis redéploiement autonome sur un hébergement infogéré |

Le nom d'un sous-agent est `foyer-` suivi du **nom du fichier de rôle**, sans exception (l'ancien
tableau annonçait `foyer-verrouillage` : c'est `foyer-verrouillage-convergence`).

## Installation
- **Dans le dépôt Foyer** : `.claude/agents/` (racine, versionné) porte un pointeur par sous-agent,
  sur le principe des commandes de `.claude/commands/` : même en-tête, un corps qui renvoie au
  fichier d'ici et n'ajoute que la localisation du projet cible.
- **Dans un projet consommateur** : copier ou lier `pilote/adapters/claude/agents/foyer-*.md` vers
  son `.claude/agents/` (voir [`../README.md`](../README.md)).

> Un rôle de plus dans `pilote/roles/` = un fichier de plus ici (recopier le patron en remplaçant
> `<rôle>`) **et** son pointeur dans `.claude/agents/`. Ils restent volontairement minimalistes :
> toute l'intelligence est dans `pilote/roles/` + les skills.
