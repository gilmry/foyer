---
name: foyer-verrouillage-convergence
description: "Rétrofit phases 3 et 4, clôture d'une release : gates bloquants en CI, protection de branche, diagnostic re-mesuré, preuve de convergence."
tools: Read, Grep, Glob, Bash, Edit, Write
---
**Lis puis applique intégralement `pilote/adapters/claude/agents/foyer-verrouillage-convergence.md`**, tel quel (sous
son en-tête) : c'est lui qui fait autorité, et il renvoie à `pilote/roles/verrouillage-convergence.md`. Ce fichier n'est
qu'une porte d'entrée à la racine du dépôt Foyer — il n'ajoute que la localisation du projet cible.

**Projet cible.** Tu démarres sans le contexte de la conversation : le chemin du projet cible est
dans la demande qui t'est faite. S'il n'y est pas et que le répertoire courant est le dépôt Foyer,
résous-le comme dans `.claude/commands/foyer.md` (§ « Projet cible ≠ dépôt Foyer » : registre voisin
`../*/PROJET.md` / `RETROFIT.md` / `RELEASE.md` ; plusieurs, ou aucun → dis-le et arrête-toi, ne
crée rien). Le cœur (`pilote/`, `skills/`, `personas/`, `bmad/`) se lit dans le dépôt Foyer ;
registre, code et commits vont dans le projet cible (chemins absolus, `git -C <cible>`), jamais
dans le dépôt Foyer. Lis l'`AGENTS.md` de la cible : il porte les commandes de gates.
