# Rôle : arbitre de promotion (juger sur preuve)

> **Version provisoire, métriques non mesurées.** Écrite avant le chiffre pour instrumenter la
> mesure, pas pour la remplacer (gilmry/foyer#7). Les valeurs marquées `[caler]` sont des priors ;
> elles se recalent sur le relevé des premières promotions de KoproGo : bascules de périmètre du
> rétrofit, puis mises en production par Sluis.

## Mission
Promouvoir une branche, ou la renvoyer, **sur la foi de sa preuve**. `gate-runner` **mesure**
(il lit des exit codes) ; ce rôle **juge** ce que la mesure ne dit pas : la valeur est-elle là ?

## Déclencheur
Une ou plusieurs branches prêtes à franchir un point de promotion : bascule de périmètre en
rétrofit, fusion vers la branche source de vérité, mise en production approuvée par la plateforme
(chez Sluis : l'environnement GitHub protégé à relecteur requis).

## Trois entrées, et rien d'autre
1. **La vitrine** : le parcours filmé de la story (`doc-vivante`).
2. **Les gates** : verts ou rouges sur le head de la branche, avec leur cause.
3. **Les quatre classes** (`@happy`, `@negative`, `@edge`, `@security`) : présentes **et
   exécutées**, pas seulement déclarées.

Le gate `promotion` (`../gates/README.md`) vérifie que ces trois entrées **existent** avant que
l'arbitrage commence. Une branche qui ne le passe pas est inarbitrable : elle retourne au rôle qui
l'a produite, sans jugement.

## Ce que ce rôle ne fait jamais
- **Relire le diff ligne à ligne.** Ça ne passe pas à l'échelle, et c'est précisément ce que la
  preuve doit rendre inutile.
- **Promouvoir sur un gate rouge**, quel que soit l'argument.

## Point irréversible
**La promotion elle-même** (cf. `../arbitrage.md`). Quand l'arbitre et l'auteur sont la même
personne, la séparation reste écrite : la décision se pose au registre avec sa preuve avant d'être
prise (section *Répartition des rôles* de `../state.template.md`).

## Métriques (relevées au registre, section *Promotions*)
- **Minutes d'arbitrage par branche** `[caler]` : forme mesurable du `ratio_supervision` de
  `../../skills/abaque-cout-capacite.md` quand le travail se fait en parallèle. Il plafonne
  toujours le *répondre-de*, mais il se chronomètre.
- **Diff ouvert quand même** (oui / non, et pourquoi) : chaque oui est un **échec de la preuve**,
  pas de l'arbitre.

## Signal d'alerte
Quand le nombre de diffs ouverts monte, on ne double pas l'arbitre : on **répare la preuve**
(vitrine trop longue, gate muet sur sa cause, classe de tests déclarée mais non jouée).

## Après la mesure
Le relevé KoproGo donne la valeur de la constante, inscrite dans l'abaque avec sa provenance ; ce
rôle est alors amendé depuis ce que le relevé a montré, et perd sa mention « provisoire ».
