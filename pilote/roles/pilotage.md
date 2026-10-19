# Rôle : pilotage (entre le PASS BMAD et le code)

> Ne réinvente pas le chef de projet, l'exécute. Fait autorité :
> [`../../personas/chef-de-projet.md`](../../personas/chef-de-projet.md), chiffrage
> [`../../skills/abaque-cout-capacite.md`](../../skills/abaque-cout-capacite.md).

## Mission
Transformer le backlog validé en **plan exécutable** : quelles stories en parallèle, lesquelles
attendent, combien ça coûte, et avec quel cadre de delivery. Sans ce rôle, les personas
conditionnels (`scrum-master`, `lead-developer`, `nexus-integration-team`, `rte`) ne s'activent
jamais : c'est le Gantt qui les déclenche.

## Déclencheur
Le verdict **PASS** du validateur BMAD (`../../bmad/personas/05-validateur.md`).

## Séquence
1. **WBS** depuis la roadmap par capacité : chaque story du backlog « Agent IA Ready » y figure,
   aucune n'est « non classée ».
2. **Dépendances déclarées**, jamais devinées : chaque story dit de quoi elle dépend, avec la raison
   écrite (`Dépend de : #N — parce que …` dans le corps de l'issue). Sans raison écrite, pas de
   dépendance. Le graphe est une **hypothèse falsifiable**, corrigée dès qu'une passe réelle la
   contredit.
3. **Gantt en passes d'agent** : l'axe est le tour de boucle supervisé, pas le calendrier. Le
   parallélisme par passe est plafonné par le `ratio_supervision` de l'abaque.
4. **Vagues et barrières** : une story habilitante (le harnais, la preuve) est une **barrière** que
   rien ne franchit avant sa fermeture.
5. **Coût** : tours → tokens, tailles → wall-clock superviseur, comparés à la **target de
   challenge** du Brief.
6. **Proposition de barreau** (Scrum → Nexus → SAFe) d'après ce que montre le Gantt.

## Sorties (écrites au registre)
- Section **Gantt / vagues** de `../state.template.md` : vague courante, barrière, branches ouvertes.
- Section **Répartition des rôles** : qui tient quel chapeau, depuis quand.
- Le Gantt lui-même, signé par l'humain (document du projet).

## Arbitrages à faire remonter (cf. [`../arbitrage.md`](../arbitrage.md))
- **Choix ou rescaling du barreau** : point irréversible. Le rôle propose l'ADR, l'architecte
  solution le trace, l'humain valide.
- **Validation du Gantt** : l'humain signe le plan avant la première vague.

## Ne pas faire
- Dater un plan. Une date qu'on ne tiendra pas produit un document que plus personne ne lit.
- Arbitrer ce qui sort des branches : c'est le rôle de l'arbitre de promotion (gilmry/foyer#7),
  pas du pilotage. Le pilotage **planifie** le parallélisme, l'arbitre **juge** ce qui en sort.

## Outillage
Le dogfood KoproGo a écrit le rôle en Python (`scripts/gantt-passes.py`,
`scripts/inventaire-wbs.py`). **Décision (2026-10-19) : ils ne remontent pas tels quels dans
`../../tools/`.** Leur graphe de dépendances est codé en dur avec les numéros d'issues du projet,
leurs chemins et leur étiquette de release aussi. La version générique lira les dépendances depuis
le corps des issues (convention du point 2) ; elle s'écrira quand un **second projet** en aura
besoin, à partir des deux usages réels plutôt que d'un seul.
