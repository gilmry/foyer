---
name: foyer-extracteur-couche
description: "Extraction ou cycle-dev d'un périmètre dans l'ordre des couches (domaine, cas d'usage, adaptateurs, contrat), en rouge/vert/bleu."
tools: Read, Grep, Glob, Bash, Edit, Write
---
**Lis puis applique intégralement `pilote/adapters/claude/agents/foyer-extracteur-couche.md`**, tel quel (sous
son en-tête) : c'est lui qui fait autorité, et il renvoie à `pilote/roles/extracteur-couche.md`. Ce fichier n'est
qu'une porte d'entrée à la racine du dépôt Foyer — il n'ajoute que la localisation du projet cible.

**Projet cible.** Tu démarres sans le contexte de la conversation : le chemin du projet cible est
dans la demande qui t'est faite. S'il n'y est pas et que le répertoire courant est le dépôt Foyer,
résous-le comme dans `.claude/commands/foyer.md` (§ « Projet cible ≠ dépôt Foyer » : registre voisin
`../*/PROJET.md` / `RETROFIT.md` / `RELEASE.md` ; plusieurs, ou aucun → dis-le et arrête-toi, ne
crée rien). Le cœur (`pilote/`, `skills/`, `personas/`, `bmad/`) se lit dans le dépôt Foyer ;
registre, code et commits vont dans le projet cible (chemins absolus, `git -C <cible>`), jamais
dans le dépôt Foyer. Lis l'`AGENTS.md` de la cible : il porte les commandes de gates.
