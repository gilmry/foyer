# Pilote Foyer — cadre agentique portable

Le **pilote** est la couche qui rend la méthode Foyer *exécutable par des agents*, sur
des équipes et des outils hétérogènes. Il ne réinvente rien : il **séquence** les skills,
les personas et la pipeline BMAD existants, tient un **registre d'état** partagé, et
**fait remonter les arbitrages** au bon moment.

## Portable multiagent — pourquoi ce format

Les équipes sont hétérogènes : les **développeurs** travaillent sur **Claude / Claude Code**,
les **product owners** sur **ChatGPT ou Qwen**. Le seul dénominateur commun que *tous* les
modèles savent lire, c'est **`AGENTS.md` + du Markdown + des scripts**. Donc :

- **Le cœur** (`parcours.md`, `journeys/`, `roles/`, `state.template.md`, `gates/`) est en
  **artefacts ouverts** — aucun runtime requis.
- **Les adaptateurs** (`adapters/claude/`, `adapters/opencode/`, `adapters/generic/`) sont
  **fins** : ils *pointent* vers le cœur, ils n'y logent aucune logique.

## Trois portes d'entrée

Le point d'entrée unique est **`parcours.md`** (le dispatcher). Il pose une seule question :
quel est le contexte ? Puis il route :

| Porte | Quand | Parcours | Front-end |
|---|---|---|---|
| **Nouveau projet** | greenfield, on part de 0 | [`journeys/nouveau-projet.md`](journeys/nouveau-projet.md) | conception BMAD → bootstrap kit |
| **Rétrofit** | legacy en production à faire converger | [`journeys/retrofit.md`](journeys/retrofit.md) | diagnostic → harnais → extraction |
| **Planification de release** | produit existant, gros incrément à cadrer | [`journeys/planification-release.md`](journeys/planification-release.md) | conception BMAD → cycle-dev |

## Deux portes d'usage (selon l'outil)

- **PO sur ChatGPT / Qwen** → ouvrir [`adapters/generic/PROMPT-PO.md`](adapters/generic/PROMPT-PO.md),
  coller le bootstrap, joindre `parcours.md` + le registre d'état du projet. Le PO lit l'état,
  demande « statut / prochaine étape », et **tranche les arbitrages** qu'on lui présente.
- **Dev sur Claude Code** → les commandes [`adapters/claude/commands/`](adapters/claude/commands/)
  (`/foyer-demarrer`, `/foyer-status`, `/foyer-next`, `/foyer-bascule`) et les sous-agents
  [`adapters/claude/agents/`](adapters/claude/agents/) exécutent les étapes. Ils opèrent sur
  **le même registre d'état** que le PO.
- **Runtime OpenCode** → voir [`adapters/opencode/README.md`](adapters/opencode/README.md)
  (extension du `opencode.json` existant).

## Le registre d'état : la source de vérité partagée

Chaque projet tient **un** fichier d'état dérivé de [`state.template.md`](state.template.md)
(par convention `RETROFIT.md`, `RELEASE.md` ou `PROJET.md` à la racine du projet). C'est **ce
que le PO et le dev regardent tous les deux** : porte active, position dans le parcours,
périmètres/backlog, bascules validées (qui/quand/ADR), **arbitrages en attente (🔴)**, statut
des gates. Tout agent commence par le lire, et le met à jour à chaque étape conclusive.

## Invariants (jamais négociables)

1. **Le harnais précède le métier** (rétrofit) ; **les gates plancher précèdent le code**.
2. **L'ordre des couches est une loi** : Domaine → Application → Adaptateurs → Contrat → Frontend D1 → Frontend D2.
3. **Un gate rouge = stop.** On corrige la cause, on ne force pas.
4. **Aux points irréversibles, l'agent prépare la preuve et pose une question de _modalité_** —
   jamais la destination. Voir [`arbitrage.md`](arbitrage.md).
5. **La doc vivante est intégrée au parcours**, pas une annexe : le parcours de référence
   unique est rejoué par l'E2E (gate) *et* la preuve de valeur.
6. **Un commit par étape conclusive**, nommé `<porte>(<périmètre>): <étape>` — l'historique
   raconte la trajectoire.

## Périmètre de cette version (walking skeleton)

Livré : dispatcher, registre, arbitrage, les 3 parcours séquencés, les rôles
`conception-bmad / diagnostic / frontend-ilots / gate-runner` complets, les autres en briefs,
le contrat de gates, les adaptateurs, deux exemples de registre (dont le dogfood stagesmed).

**Reporté** (briefs posés, exécution à étoffer) : automatisation par fichier (Rector,
réécriture de couche) ; serveur MCP (`adapters/mcp/`) ; escalades temporisées d'arbitrage ;
génération automatique du backlog BMAD.
