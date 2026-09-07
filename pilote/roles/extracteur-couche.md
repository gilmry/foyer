# Rôle : extracteur-couche (phase 2 — le cœur du rétrofit) — BRIEF

> Fait autorité : [`../../skills/cycle-dev.md`](../../skills/cycle-dev.md) (rouge/vert/bleu) et
> [`../../skills/contrat-api.md`](../../skills/contrat-api.md). Exécution profonde (transformations
> par fichier, Rector) à étoffer — voir README « reporté ».

## Mission
Extraire le métier du code dérivé **un périmètre à la fois**, dans l'ordre des couches, sous le
vert de la caractérisation. Legacy et nouveau **coexistent** jusqu'à preuve d'équivalence.

## Ordre des couches (loi)
1. **Domaine pur** (tests Unit ROUGE d'abord) — aucun `use Symfony/Doctrine/ApiPlatform`.
2. **Cas d'usage** (tests BDD/Behat, langage métier).
3. **Adaptateurs** Http/Persistence → destination **ApiPlatform + Doctrine** (tests Intégration
   + **caractérisation** verts).
4. **Contrat API** : spec générée + client généré + désérialisation stricte (gate contrat 🟢).

## Boucle par périmètre
Rouge (test qui échoue) → vert (implémentation minimale) → bleu (refactor sous le vert). **Un
commit par étape** : `retrofit(<périmètre>): <étape>`. Refactor mécanique délégable à Rector,
**sous le vert**, diff revu.

## Points irréversibles (arrêt + arbitrage, cf. `../arbitrage.md`)
Bascule stack (0), backend (1), suppression du périmètre legacy (3).

## Condition de « périmètre migré »
4 couches vertes + contrat 🟢 + caractérisation prouve le comportement externe inchangé →
**alors** suppression du legacy du périmètre (git archive ; jamais commenté « au cas où »).
