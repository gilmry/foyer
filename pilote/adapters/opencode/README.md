# Adaptateur OpenCode

Le dépôt Foyer porte déjà un `opencode.json` (racine) qui charge `AGENTS.md`, les `skills/` et
les `personas/` comme instructions. Pour piloter un rétrofit/projet, **étendre** ce fichier afin
que le cœur du pilote soit chargé.

## Ajouter à `instructions` (opencode.json)
```jsonc
{
  "instructions": [
    "AGENTS.md",
    // … existant …
    "./pilote/BOOTSTRAP.md",
    "./pilote/parcours.md",
    "./pilote/arbitrage.md",
    "./pilote/gates/README.md"
  ]
}
```

## Rôles : pas de sous-agents installés (écart annoncé)
L'adaptateur Claude Code installe un sous-agent par rôle (`../claude/agents/`). **Cet adaptateur
n'en installe pas** : le format d'agents d'OpenCode n'a pas été vérifié ici, et rien n'a été
essayé. L'équivalent est le cœur lui-même : à chaque étape, l'agent OpenCode **lit
`pilote/roles/<rôle>.md`** désigné par le parcours et le joue. Les dix rôles sont donc
disponibles, sans délégation à un sous-agent isolé.

## Livrer (phase L)
Un agent OpenCode qui a un shell, l'accès SSH et le `.env` du projet peut jouer
`pilote/roles/deployeur-heberge.md` comme Claude Code : le rôle ne dépend d'aucun runtime.
**Non prouvé** : la phase L n'a été jouée sous OpenCode sur aucun projet.

Au lancement, l'agent OpenCode lit `BOOTSTRAP.md`, amorce, pose Q0, crée le registre, puis suit
`parcours.md`. Même comportement que la porte Claude Code et que le PO sur ChatGPT/Qwen —
c'est le principe *portable multiagent* : un seul cœur, des portes d'entrée différentes.
