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
   | **exploitation** | Produit en production : alertes, doléances, recalage | [`journeys/exploitation.md`](journeys/exploitation.md) *(v0)* |

   > En cas de doute : *legacy qui tourne et qu'on veut migrer* → **rétrofit** ;
   > *rien encore* → **nouveau** ; *ça tourne et conforme, on ajoute gros* → **release** ;
   > *c'est en production et on le fait vivre* → **exploitation**, qui coexiste avec une autre porte.
   > Elle n'a pas besoin de Q0 pour s'ouvrir : **la première livraison réussie** (phase L d'un
   > parcours `nouveau` ou `release`, smoke public vert) l'ajoute au registre à côté de la porte active.

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
   qu'aucun blocage réel (0bis), ni point irréversible (4), ni la **question unique sur la cible**
   (ci-dessous) ne l'arrête. Rendre la main « à mi-story » en marquant des gates « déférés » est
   une **déviation** (friction F3 du dogfood n°1).
7. **Tous les gates bloquants verts sur le head, `deploiement` compris → livrer.** Le parcours
   passe à sa **phase L** sans attendre qu'on le demande : rôle
   [`roles/deployeur-heberge.md`](roles/deployeur-heberge.md). Ce n'est pas une promotion de
   branche : on livre le head d'une branche dont la promotion est déjà jugée.

### Cible de déploiement — demandée une fois, jamais devinée

Avant la phase L, lire le bloc « Cible de déploiement » du registre :

- **Remplie** → entrer dans la phase **sans poser de question**.
- **« pas encore demandée »**, ou **bloc absent** (registre antérieur à ce gabarit : le recopier
  depuis [`state.template.md`](state.template.md)) → poser **une** question, en langage clair (« où met-on l'application
  en ligne ? » : hébergeur, alias SSH, nom de l'instance, adresse), puis **inscrire la réponse**,
  datée. Ce qui identifie le compte va dans `.foyer/cible.env` du projet, pas au registre : avant
  d'y écrire, ajouter `/.foyer/` au `.gitignore` du projet et vérifier par
  `git check-ignore -q .foyer/cible.env` (échec = on n'écrit pas). Le jeton d'API, lui, est posé
  par l'humain dans le `.env` du projet : le pilote ne le demande pas dans la conversation et ne
  l'affiche jamais.
- **« aucune »** (l'humain a répondu qu'on ne livre pas, ou pas par ce moyen) → inscrit et daté de
  la même façon ; la phase L est sans objet.

Dans les trois cas la ligne « Cible » du registre porte une date : **le pilote ne redemande plus**.
Seul l'humain rouvre la question, en modifiant le registre.

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
- **Gates avant métier** : le plancher (celui de `../skills/gates.md`) et — en rétrofit —
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
| Cible de déploiement donnée (ou refusée) par l'humain | bloc « Cible de déploiement », ligne « Cible » datée ; rien qui identifie le compte |
| Livraison réussie (smoke public vert) | version en service + commit, version précédente, ligne au tableau *Livraisons* ; à la première : ajouter la porte `exploitation` |
| Livraison échouée, retour arrière | ligne *Livraisons* : l'échec, sa sortie (étape, code de sortie), la version restaurée ; jamais de sortie brute ni de secret |
