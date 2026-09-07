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

Au lancement, l'agent OpenCode lit `BOOTSTRAP.md`, amorce, pose Q0, crée le registre, puis suit
`parcours.md`. Même comportement que la porte Claude Code et que le PO sur ChatGPT/Qwen —
c'est le principe *portable multiagent* : un seul cœur, des portes d'entrée différentes.
