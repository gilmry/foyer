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
