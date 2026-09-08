# parcours.md — dispatcher du pilote Foyer

> Point d'entrée unique. Tout agent (Claude, ChatGPT, Qwen, OpenCode…) commence ici.
> Ne contient aucune logique métier : il **oriente** et rappelle les **règles communes**.

## Étape 0 — Situer

1. **Lire le registre d'état** du projet s'il existe (`RETROFIT.md` / `RELEASE.md` /
   `PROJET.md` à la racine, dérivé de [`state.template.md`](state.template.md)).
   - S'il existe et qu'une **porte est active** → aller directement au parcours de cette
     porte et reprendre à l'étape courante (voir « Boucle next » ci-dessous).
   - S'il n'existe pas → poser **Q0** puis créer le registre.

2. **Q0 — Quelle porte ?** (une seule active à la fois)

   | Réponse | Contexte | Router vers |
   |---|---|---|
   | **nouveau** | On part de zéro (greenfield) | [`journeys/nouveau-projet.md`](journeys/nouveau-projet.md) |
   | **rétrofit** | Un legacy en production à faire converger | [`journeys/retrofit.md`](journeys/retrofit.md) |
   | **release** | Produit existant, gros incrément à cadrer | [`journeys/planification-release.md`](journeys/planification-release.md) |

   > En cas de doute : *legacy qui tourne et qu'on veut migrer* → **rétrofit** ;
   > *rien encore* → **nouveau** ; *ça tourne et conforme, on ajoute gros* → **release**.

3. **Créer le registre** depuis `state.template.md`, y inscrire la porte active, la date,
   l'archétype (voir `bmad/archetypes.md`), puis démarrer le parcours.

## Étape 0bis — Sonder l'environnement & choisir le substrat (avant tout gate)

Pour qu'un PO **n'installe rien** et ne voie jamais un « command not found » :

1. **Sonder les runtimes** requis par le kit/l'archétype (ex. `php`, `node`, `python`, `docker`).
2. **Choisir le substrat d'exécution** (défaut de [`defaults.md`](defaults.md)) : runtime local
   s'il existe, **sinon conteneur** (Docker) — les gates tournent alors via `docker run …`.
   Cadrer une commande de gate = fournir une commande **qui marche dans le substrat choisi**.
3. **Inscrire au registre** le substrat retenu (ligne « Substrat »). Si *aucun* substrat n'est
   disponible (ni runtime ni Docker), c'est le **seul** blocage légitime à remonter au PO.

> Principe : l'agent **résout l'outillage lui-même**. Découvrir l'absence de PHP au milieu d'une
> story est un échec du pilote, pas une fatalité (friction F4 du dogfood n°1).

## Boucle « next » (le séquenceur)

À chaque sollicitation (`/foyer-next`, ou le PO qui demande « et maintenant ? ») :

1. Lire le registre → **porte active + phase/étape courante**.
2. Ouvrir le `journeys/<porte>.md` → localiser l'étape → il désigne le **rôle** à jouer
   (`roles/<rôle>.md`) et sa **condition de sortie**.
3. Vérifier les **pré-conditions** (gates de l'étape précédente verts). Rouge → on ne passe
   pas, on renvoie au rôle `gate-runner` pour diagnostiquer.
4. **Si l'étape est un point irréversible** (voir [`arbitrage.md`](arbitrage.md)) → NE PAS
   exécuter la bascule : assembler la preuve, écrire un arbitrage **🔴 en attente** dans le
   registre, présenter au PO la question de **modalité**, s'arrêter.
5. Sinon → jouer le rôle, produire la sortie, faire passer les gates, **mettre à jour le
   registre** (avancer l'étape), **committer** (`<porte>(<périmètre>): <étape>`).
6. **Ne pas rendre la main avant la fin de l'étape.** L'agent enchaîne les sous-étapes tant
   qu'aucun blocage réel (0bis) ni point irréversible (4) ne l'arrête. Rendre la main « à mi-story »
   en marquant des gates « déférés » est une **déviation** (friction F3 du dogfood n°1).

### Definition of Done — une story full-stack va JUSQU'À la preuve de valeur

Un seul parcours de référence, rejoué sous **trois angles**. La story n'est **DONE** que si les
trois sont verts — l'agent ne s'arrête pas au premier :

| Angle | Gate | Obligatoire (full-stack) |
|---|---|---|
| **Correctness** | `e2e` | oui |
| **Apparence** | `visuel` (goldens) | oui dès qu'il y a un rendu |
| **Preuve de valeur** | `doc-vivante` (parcours filmé + vitrine) | **oui** — c'est l'aboutissement, non « optionnel » |

> `doc-vivante` est **non bloquant** (une preuve, pas un verrou) mais **non facultatif** : une story
> full-stack sans sa preuve de valeur n'est pas terminée. L'agent la produit **automatiquement**,
> sans que le PO ait à la réclamer.

## Règles communes à toutes les portes (invariants)

- **Ordre des couches** : Domaine (pur) → Application → Adaptateurs (Http/Persistence) →
  Contrat (OpenAPI + client généré + désérialisation stricte) → Frontend D1 (consomme le
  client généré) → Frontend D2 (rendu îlots-first, **conditionnel** à une dérive de rendu).
  Sauter une couche casse un invariant.
- **Gates avant métier** : le plancher (secrets, migrations réversibles) et — en rétrofit —
  la caractérisation précèdent toute extraction. Détail : [`gates/README.md`](gates/README.md).
- **Doc vivante intégrée** : un **seul** parcours de référence, rejoué par l'E2E (gate,
  bloquant) *et* la preuve de valeur cadencée. On ne double pas la doc.
- **Arbitrage = modalité, jamais destination.** La destination (le kit hexagonal + îlots) est
  fixée. Seuls timing / séquençage / rollback se tranchent avec l'humain.
- **Traçabilité** : un commit par étape conclusive ; une ADR par arbitrage tranché ; le
  registre reflète toujours la réalité (« ça tourne » ≠ conforme).

## Mise à jour du registre — quoi écrire quand

| Événement | Écrire dans le registre |
|---|---|
| Étape conclue | avancer `phase/étape courante`, cocher la sortie, référencer le commit |
| Gate passé/échoué | statut du gate (🟢/🔴) + horodatage |
| Point irréversible atteint | entrée **🔴 arbitrage en attente** : preuve jointe + question de modalité |
| Arbitrage tranché par le PO | déplacer en **✅**, référencer l'ADR + qui/quand |
| Périmètre migré (rétrofit) / story livrée (nouveau/release) | ligne au tableau des périmètres/backlog |
