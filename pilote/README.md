# Pilote Foyer — cadre agentique portable

Le **pilote** est la couche qui rend la méthode Foyer *exécutable par des agents*, sur
des équipes et des outils hétérogènes. Il ne réinvente rien : il **séquence** les skills,
les personas et la pipeline BMAD existants, tient un **registre d'état** partagé, et
**fait remonter les arbitrages** au bon moment.

> Pour s'en servir, pas à pas : [`MODE-D-EMPLOI.md`](MODE-D-EMPLOI.md).

## Portable multiagent — pourquoi ce format

Les équipes sont hétérogènes : les **développeurs** travaillent sur **Claude / Claude Code**,
les **product owners** sur **ChatGPT ou Qwen**. Le seul dénominateur commun que *tous* les
modèles savent lire, c'est **`AGENTS.md` + du Markdown + des scripts**. Donc :

- **Le cœur** (`parcours.md`, `journeys/`, `roles/`, `state.template.md`, `gates/`) est en
  **artefacts ouverts** — aucun runtime requis.
- **Les adaptateurs** (`adapters/claude/`, `adapters/opencode/`, `adapters/generic/`) sont
  **fins** : ils *pointent* vers le cœur, ils n'y logent aucune logique.

## Quatre portes d'entrée

Le point d'entrée unique est **`parcours.md`** (le dispatcher). Il pose une seule question :
quel est le contexte ? Puis il route :

| Porte | Quand | Parcours | Front-end |
|---|---|---|---|
| **Nouveau projet** | greenfield, on part de 0 | [`journeys/nouveau-projet.md`](journeys/nouveau-projet.md) | conception BMAD → bootstrap kit |
| **Rétrofit** | legacy en production à faire converger | [`journeys/retrofit.md`](journeys/retrofit.md) | diagnostic → harnais → extraction |
| **Planification de release** | produit existant, gros incrément à cadrer | [`journeys/planification-release.md`](journeys/planification-release.md) | conception BMAD → cycle-dev |
| **Exploitation** *(v0)* | produit en production | [`journeys/exploitation.md`](journeys/exploitation.md) | convergence → usage → recalage, rouvre une release |

## Deux portes d'usage (selon l'outil)

- **PO sur ChatGPT / Qwen** → ouvrir [`adapters/generic/PROMPT-PO.md`](adapters/generic/PROMPT-PO.md),
  coller le bootstrap, joindre `parcours.md` + le registre d'état du projet. Le PO lit l'état,
  demande « statut / prochaine étape », et **tranche les arbitrages** qu'on lui présente.
- **Dev sur Claude Code** → les commandes [`adapters/claude/commands/`](adapters/claude/commands/)
  (`/foyer-demarrer`, `/foyer-status`, `/foyer-next`, `/foyer-bascule`) et les sous-agents
  [`adapters/claude/agents/`](adapters/claude/agents/) (**un par rôle**, dix) exécutent les étapes.
  Ils opèrent sur **le même registre d'état** que le PO. Depuis la racine du dépôt Foyer,
  **`/foyer`** lance le bootstrap sans rien installer ; `/foyer-status`, `/foyer-next`,
  `/foyer-bascule` et les dix sous-agents (`.claude/agents/`) y sont aussi disponibles.
- **Runtime OpenCode** → voir [`adapters/opencode/README.md`](adapters/opencode/README.md)
  (extension du `opencode.json` existant ; pas de sous-agents installés, l'agent lit les rôles).

## Le registre d'état : la source de vérité partagée

Chaque projet tient **un** fichier d'état dérivé de [`state.template.md`](state.template.md)
(par convention `RETROFIT.md`, `RELEASE.md` ou `PROJET.md` à la racine du projet). C'est **ce
que le PO et le dev regardent tous les deux** : porte active, position dans le parcours,
périmètres/backlog, bascules validées (qui/quand/ADR), **arbitrages en attente (🔴)**, statut
des gates, et **cible de déploiement** (où livrer, version en service, version précédente,
livraisons). Tout agent commence par le lire, et le met à jour à chaque étape conclusive. Il est
commité : ni jeton, ni mot de passe, ni nom de compte n'y figurent, il renvoie à un fichier local
ignoré par git.

## Livrer quand tout est vert

Les parcours `nouveau` et `release` se terminent par une **phase L — livrer** : tous les gates
bloquants verts sur le head, gate `deploiement` compris, le pilote livre **sans qu'on le lui
demande** ([`roles/deployeur-heberge.md`](roles/deployeur-heberge.md)), prouve par un passage du
smoke e2e contre l'adresse publique, et remet seul la version précédente si cette preuve échoue.
Le seul arrêt d'une livraison de routine est une **migration de schéma**
([`arbitrage.md`](arbitrage.md)). La première livraison réussie ouvre la porte `exploitation`.
Le parcours `rétrofit` n'a pas de phase L : son legacy est déjà en production, et sa mise en
service passe par ses bascules arbitrées.

## Qui joue quoi, à quelle étape (tenu à jour avec `roles/`, `personas/` et `skills/`)

Relevé du 2026-11-18, fait dans les fichiers : une ligne dit ce que `journeys/` et `roles/`
écrivent, pas ce qu'on aimerait y lire. Ajouter un rôle, une persona ou un skill = ajouter sa ligne
ici (et son sous-agent, [`adapters/claude/agents/`](adapters/claude/agents/README.md)).

### Persona → étape de parcours → rôle

| Persona | Étape de parcours | Rôle du pilote |
|---|---|---|
| `bmad/personas/01-analyste.md` | `nouveau` et `release`, phase A (1) | `roles/conception-bmad.md` |
| `bmad/personas/02-product-manager.md` | `nouveau` et `release`, phase A (2) | `roles/conception-bmad.md` |
| `bmad/personas/03-architecte.md` | `nouveau` et `release`, phase A (3) | `roles/conception-bmad.md` |
| `bmad/personas/04-scrum-master.md` | `nouveau`, phase A (4) ; en `release`, le parcours ne le nomme pas, le rôle le déroule | `roles/conception-bmad.md` |
| `bmad/personas/05-validateur.md` | `nouveau` et `release`, phase A (dernière étape) ; son PASS déclenche la phase A bis | `roles/conception-bmad.md` |
| `personas/chef-de-projet.md` | `nouveau` et `release`, phase A bis | `roles/pilotage.md` |
| `personas/platform-engineer.md` | `nouveau` et `release`, phase L ; `exploitation`, phase E1 | `roles/deployeur-heberge.md` (hébergement infogéré) ; aucun rôle pour E1 sur un serveur que l'on administre |
| `personas/support-engineer.md` | `exploitation`, phase E2 | aucun rôle : le parcours cite la persona directement |
| `personas/csi-engineer.md` | `exploitation`, phase E3 | aucun rôle : idem |
| `personas/estimateur-capacite-cout.md` | `exploitation`, phase E3 | aucun rôle : idem |
| `personas/scrum-master.md` | **hors parcours** : conditionnel au barreau Scrum, activé par le Gantt de la phase A bis (`roles/pilotage.md`) ; aucune étape ne le nomme ensuite | — |
| `personas/lead-developer.md` | **hors parcours** : même raison (barreau Scrum). Le cycle-dev des phases C est tenu par les rôles `extracteur-couche` et `frontend-ilots`, qui ne citent pas la persona | — |
| `personas/nexus-integration-team.md` | **hors parcours** : conditionnel au barreau Nexus, même raison | — |
| `personas/rte.md` | **hors parcours** : conditionnel au barreau SAFe, même raison | — |

L'**architecte solution** n'a pas de fichier de persona (`../personas/README.md`) : c'est l'agent
du Manifeste, qui trace les ADR à chaque arbitrage. L'**arbitre de promotion** est un rôle sans
persona ([`roles/arbitre-de-promotion.md`](roles/arbitre-de-promotion.md)) : aucun parcours n'en
fait une phase, il se joue avant toute promotion de branche (gate `promotion`,
[`gates/README.md`](gates/README.md)). Le parcours `rétrofit` ne cite aucune persona : ses phases
désignent des rôles (`diagnostic`, `harnais`, `extracteur-couche`, `frontend-ilots`,
`verrouillage-convergence`).

### Skill → étape de parcours → rôle

| Skill | Étape de parcours | Rôle du pilote |
|---|---|---|
| `skills/abaque-cout-capacite.md` | `nouveau` et `release`, phases A (chiffrage) et A bis ; `exploitation`, E3 | `conception-bmad`, `pilotage` |
| `skills/adoption.md` | `exploitation` (cité en tête du parcours ; boucle d'usage, E2) | aucun rôle |
| `skills/arbitrage-hybride.md` | transversal : fait autorité pour [`arbitrage.md`](arbitrage.md), appliqué à chaque point irréversible | tous |
| `skills/bootstrap-delivrabilite.md` | `rétrofit`, phase 1 (étape 1) ; `nouveau`, phase B (geste 2) | `harnais` |
| `skills/bootstrap-nouveau-projet.md` | `nouveau`, phase B (les 7 gestes) | `conception-bmad`, puis `extracteur-couche` et `frontend-ilots` |
| `skills/conformite.md` | `exploitation`, E3 (autoévaluation en gate review) ; phase L (conformité de l'hébergeur) | `deployeur-heberge` |
| `skills/contrat-api.md` | `rétrofit`, étape 2.4 ; `release`, phase A (3) | `extracteur-couche`, `frontend-ilots` |
| `skills/convergence-iac.md` | `exploitation`, E1 (serveur que l'on administre) | aucun rôle |
| `skills/cycle-dev.md` | `rétrofit`, phase 2 ; `nouveau` et `release`, phase C | `extracteur-couche` |
| `skills/deploiement-heberge-infogere.md` | `nouveau` et `release`, phase L ; `exploitation`, E1 infogéré | `deployeur-heberge` |
| `skills/depot-cible-sluis.md` | **hors parcours** (voir ci-dessous) | — |
| `skills/documentation-vivante.md` | partout où un écran est touché : `rétrofit` 2.5, `nouveau` phase B (geste 5), phases C | `frontend-ilots` |
| `skills/enforcement.md` | `rétrofit`, phase 3 ; `exploitation`, E1 (contenu externe) | `verrouillage-convergence` |
| `skills/gates.md` | toutes les étapes (plancher, puis gates de l'étape) | `gate-runner`, `harnais`, `verrouillage-convergence`, `deployeur-heberge` |
| `skills/migration-projet-existant.md` | `rétrofit`, phases 0 à 4 | `diagnostic`, `verrouillage-convergence` |

**Pourquoi `depot-cible-sluis` reste hors parcours.** Il ne sert que si le projet est déployé par
Sluis, et son juge est un outil extérieur au dépôt (le verdict MCP de Sluis). Aucun rôle ne le
joue, et aucun parcours n'a d'étape « générer le dépôt cible » : la porte `exploitation` est une
v0 écrite d'après le dispositif de Sluis, à recaler sur un premier relevé qui n'existe pas encore
(gilmry/foyer#10). Le brancher avant ce relevé serait écrire une étape que personne n'a traversée.
Proposition, non décidée : le brancher comme variante de la phase L (livraison par plateforme)
quand ce relevé existera.

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

Livré : dispatcher, registre, arbitrage, les 3 parcours séquencés plus la porte `exploitation` en v0, les rôles
`conception-bmad / pilotage / diagnostic / frontend-ilots / gate-runner` complets, `arbitre-de-promotion` provisoire,
`deployeur-heberge` en v0, les autres en briefs,
le contrat de gates, les adaptateurs (un sous-agent Claude par rôle), deux exemples de registre (dont le dogfood stagesmed).

**Non prouvé** : la phase L n'a été jouée de bout en bout sur aucun projet (gilmry/foyer#41) ; le
retour arrière automatique s'appuie sur le script `revenir.sh` des kits, prouvé par leur répétition
locale seulement.

**Reporté** (briefs posés, exécution à étoffer) : automatisation par fichier (Rector,
réécriture de couche) ; serveur MCP (`adapters/mcp/`) ; escalades temporisées d'arbitrage ;
génération automatique du backlog BMAD.
