# Skill — Enforcement (les trois anneaux)

*Skill transversal du dispositif. Contrepartie **enforcement** des skills *guidance*. Hérite de `../Boucle-de-retroaction.md`. Les fichiers markdown orientent ; **ce skill décrit ce qui contraint vraiment** — et où chaque contrainte doit vivre pour qu'on puisse en répondre.*

> **Principe.** L'enforcement n'est fiable que s'il est **hors de portée de la chose qu'il contraint**. Un blocage qui s'exécute dans le runtime de l'agent est nécessaire mais **contournable** ; le seul enforcement dont on *répond* est celui que l'agent ne peut pas atteindre.

---

## Anneau 1 — Permissions (déclaratif, `opencode.json`)

Chaque outil est `allow` / `ask` / `deny`, avec pattern-matching (dernière règle qui matche l'emporte).

```json
{ "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": { "*": "deny", "src/**": "allow", "infra/**": "ask" },
    "bash": { "*": "ask", "git *": "allow", "git push *": "deny", "rm -rf *": "deny", "sudo *": "deny" },
    "external_directory": "deny",
    "skill": { "*": "allow", "dangerous-*": "deny" }
  } }
```

Levier gouvernance : une organisation pousse des défauts via l'endpoint `.well-known/opencode` (couche de base que le local ne peut qu'étendre) — politique d'organisation centralisée.

## Anneau 2 — Plugin (programmatique, `tool.execute.before`)

Blocage calculé : inspecter la commande/diff réelle et lever une erreur. C'est le miroir in-agent de `gates.md`.

```ts
import type { Plugin } from "@opencode-ai/plugin"
export const FoyerGates: Plugin = async () => ({
  "tool.execute.before": async (input, output) => {
    const cmd = String(output?.args?.command ?? "")
    if (input.tool === "bash" && /git commit/.test(cmd) && !gatesGreen())
      throw new Error("Gates non vertes — commit bloqué")
    if (input.tool === "edit" && touchesIrreversibleBoundary(output?.args?.filePath))
      throw new Error("Frontière irréversible — validation humaine requise")
  },
  "tool.execute.after": async (input) => auditLog(input)   // registre TRACE
})
```

**Limite connue (à ne jamais oublier) :** ces hooks **n'interceptent pas les sous-agents** lancés via l'outil `task` — un agent peut donc contourner la politique en déléguant. L'anneau 2 est de la défense en profondeur, **pas une garantie**.

## Anneau 3 — Le substrat (le seul enforcement dont on répond)

Hors de portée de l'agent et de ses sous-agents :

- **Hooks Git pre-commit / pre-push** — exécutés par git, refusent le commit/push si les gates échouent. `gates.md` à sa vraie place.
- **CI/CD** — rejoue tout côté plateforme ; rien ne fusionne sans elle.
- **Protection de branche (serveur)** — la branche GitFlow source de vérité est protégée par règle de merge ; les points irréversibles ne sont pas un `ask` mais une règle qu'aucun agent ne franchit.
- **Sandbox conteneur/VM** — montages read-only, **allowlist d'egress réseau**, permissions OS.

## La règle de placement

| Type de contrainte | Anneau |
|---|---|
| Confort, garde-fous courants (rm, push, edit hors scope) | 1 (permissions) |
| Gate calculée (commit sans tests, secret, frontière) | 2 (plugin) + miroir en 3 |
| **Tout point irréversible** (push branche-vérité, migration schéma, tier, destination entité haute-cardinalité) | **3 (substrat) obligatoire** |
| Audit / trace | 2 (`tool.execute.after`) + logs substrat |

Les permissions font le confort et la défense en profondeur ; **la protection de branche et la CI font la garantie**. *« La parade est l'architecture, pas le contrat. »*

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0).*
