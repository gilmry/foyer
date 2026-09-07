# Rôle : frontend-îlots (D1 découplage, D2 rendu, doc vivante INTÉGRÉE)

> Fait autorité : [`../../skills/documentation-vivante.md`](../../skills/documentation-vivante.md)
> et [`../../skills/contrat-api.md`](../../skills/contrat-api.md).
> Vaut pour les 3 portes dès qu'un écran est touché.

## Mission
Découpler le frontend du backend via le **client généré**, et — au même moment — poser/rejouer
le **parcours de référence unique** qui sert **à la fois** l'E2E (gate) et la **preuve de valeur**.
La doc vivante n'est pas une annexe : c'est une étape de la boucle.

## D1 — Découplage (obligatoire)
- Remplacer tout `fetch`/URL d'endpoint en dur par le **client généré** (`src/generated/`, jamais
  édité à la main). Un appel manuel = invariant rouge.
- Poser **un seul** parcours de référence (`journeys/*.ts`) rejoué par :
  - `e2e/` **à vitesse** → gate correctness (bloquant) ;
  - la **doc vivante** **cadencée** (~1 action/s), narration incrustée → galerie + vidéo (preuve de
    valeur, non bloquante).
- **Ne pas dupliquer** la doc : un parcours, deux rejeux.

## D2 — Rendu îlots-first (CONDITIONNEL)
- **Uniquement si** une dérive de rendu est mesurée (rendu serveur applicatif, SPA monolithique,
  code mort). Sinon **report** accepté sur ADR (cf. `../arbitrage.md`).
- Squelette **Astro** + **îlots Svelte** (`client:load`). Mini-strangler : ancien et nouveau rendu
  coexistent jusqu'à preuve.
- **Gate de bascule** : **régression visuelle** verte (goldens par rôle/écran, tolérance définie)
  **en plus** de l'E2E. C'est un **point irréversible** → arbitrage (quels parcours critiques ?
  lance-t-on l'écran ?).

## Sorties (au registre)
- D1 : client consommé partout, E2E 🟢, preuve de valeur générée (lien vitrine).
- D2 : régression visuelle 🟢, entrée d'arbitrage bascule n°2 préparée.

## Ne pas faire
- Éditer `src/generated/` à la main (régénérer via la spec).
- Lancer D2 sans dérive mesurée, ni sans régression visuelle verte.
- Filmer un second parcours « pour la doc » : c'est le parcours d'E2E qu'on rejoue.
