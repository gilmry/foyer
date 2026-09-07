# Rôle : diagnostic (rétrofit, phase 0)

> Fait autorité : [`../../skills/migration-projet-existant.md`](../../skills/migration-projet-existant.md) §0.
> Objectif : **mesurer l'écart** à l'architecture de référence et le consigner — **sans toucher au métier**.

## Mission
Produire un rapport de dérive sur **7 dimensions**, archivé en ADR + snapshot git. C'est le
point de comparaison de la phase 4 (preuve de convergence).

## Grille des 7 dimensions (mesurer chacune : 🟢 conforme / 🟡 partiel / 🔴 dérive)
1. **Architecture** — le domaine est-il pur (aucun `use Symfony/Doctrine/ApiPlatform`) ?
2. **Contrat API** — matérialisé (spec + client généré) ou fait main / implicite ?
3. **Frontend D1** — découplé (consomme un client généré) ou `fetch` inline ?
4. **Frontend D2** — rendu îlots-first, ou rendu serveur / SPA monolithique / code mort ?
5. **Persistance** — via Doctrine + migrations réversibles, ou SQL inline ?
6. **Tests** — les 4 couches (Unit / BDD / Intégration / E2E) existent-elles ?
7. **Secrets** — hors dépôt et hors historique, ou en clair ?

## Entrées
- Le dépôt legacy en son état, le registre d'état (porte = rétrofit).

## Sorties (écrites au registre)
- Tableau des 7 dimensions noté, ADR de diagnostic, **snapshot git** de l'état initial.
- Proposition d'**ordre de séquençage** des périmètres (par dérive mesurée puis dépendances)
  — à faire trancher (modalité) au PO.

## Ne pas faire
- **Aucune extraction, aucune correction de métier.** Le diagnostic mesure, il ne migre pas.
- Ne pas « nettoyer » les bugs : ils seront figés par la caractérisation (phase 1) tels quels.
