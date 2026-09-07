# Adaptateur Claude Code (super devs)

Fin adaptateur : il **pointe** vers le cœur (`pilote/parcours.md`, `journeys/`, `roles/`,
le registre). Aucune logique métier ici.

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
Un sous-agent par rôle (`pilote/roles/*.md`) — voir [`agents/README.md`](agents/README.md).

## Rappel
Le dev et le **PO (ChatGPT/Qwen)** partagent **le même registre d'état** commité. Les commandes
ne sont qu'une porte d'entrée ergonomique vers le parcours ; le comportement est défini par le
cœur, identique quel que soit le runtime.
