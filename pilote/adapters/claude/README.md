# Adaptateur Claude Code (super devs)

Fin adaptateur : il **pointe** vers le cœur (`pilote/parcours.md`, `journeys/`, `roles/`,
le registre). Aucune logique métier ici.

## Depuis le dépôt Foyer (rien à installer)
La racine du dépôt versionne `.claude/commands/foyer.md` : ouvrir Claude Code à la racine et taper
**`/foyer`** (optionnellement suivi de la description de l'app) exécute `pilote/BOOTSTRAP.md`.
Le projet cible est créé **à côté** du dépôt Foyer (`../<nom-du-projet>`), jamais dedans ; relancer
`/foyer` propose de reprendre un registre voisin existant. Pour un travail long, ouvrir ensuite la
session dans le projet cible (ou `/add-dir <cible>`) afin d'éviter les demandes de permission.

`/foyer-status`, `/foyer-next` et `/foyer-bascule` sont également disponibles à la racine : elles
renvoient aux commandes ci-dessous et retrouvent le registre dans le projet cible voisin.

Les **dix sous-agents** (un par rôle) y sont installés de la même façon, dans `.claude/agents/` :
de fins pointeurs vers [`agents/`](agents/), qui n'ajoutent que la localisation du projet cible.

## Installation dans un projet
Rendre les commandes et sous-agents visibles de Claude Code (copie ou lien) :

```
.claude/commands/  ←  pilote/adapters/claude/commands/*.md
.claude/agents/    ←  pilote/adapters/claude/agents/*.md   (cf. agents/README.md)
```

## Commandes (surface dev)
- `/foyer-demarrer` — amorce (lit le cœur, pose Q0, crée le registre).
- `/foyer-status` — restitue l'état (lecture seule).
- `/foyer-next` — exécute la prochaine étape déterministe.
- `/foyer-bascule` — prépare un point irréversible et demande l'arbitrage de modalité.

## Sous-agents
Un sous-agent par rôle (`pilote/roles/*.md`), dix en tout — voir [`agents/README.md`](agents/README.md).
Le pilote leur délègue l'étape que le parcours désigne ; `foyer-deployeur-heberge` joue la phase
« livrer » (phase L) quand tous les gates bloquants sont verts.

## Rappel
Le dev et le **PO (ChatGPT/Qwen)** partagent **le même registre d'état** commité. Les commandes
ne sont qu'une porte d'entrée ergonomique vers le parcours ; le comportement est défini par le
cœur, identique quel que soit le runtime.
