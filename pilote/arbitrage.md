# arbitrage.md — points irréversibles & protocole

> Fait autorité : [`../skills/arbitrage-hybride.md`](../skills/arbitrage-hybride.md).
> Ici : la liste opérationnelle des points et le **protocole** que l'agent applique.

## Règle d'or

**L'IA prépare et présente la preuve ; l'humain décide la _modalité_ — jamais la destination.**
La destination (kit hexagonal + contrat matérialisé + îlots-first) est **fixée**. Ce qui se
tranche : *timing, séquençage, mécanique de bascule, rollback, dérogations tracées en ADR*.

### Filtre « vibe codeur » (PO non-développeur) — appliquer AVANT de poser toute question

Un point ne remonte au PO **que s'il est irréversible ET formulable en langage métier**. Tout
choix **technique réversible** est **tranché par l'agent** avec le défaut de
[`defaults.md`](defaults.md), **annoncé en une phrase**, sans vote. En particulier :
- **Archétype, pile, ORM/SQL, base de dev, substrat** = **défauts annoncés**, jamais des questions.
- On reformule toujours en métier : « supprime-t-on définitivement ? » (oui) plutôt que
  « hard delete ? » (non). Si un mot devrait être googlé par le PO, **c'est un défaut, pas une
  question** (friction F1 du dogfood n°1).

## Protocole (à chaque point atteint)

1. **Ne pas exécuter la bascule.**
2. **Assembler la preuve** exigée par le point (voir tableau) et la joindre au registre.
3. **Écrire une entrée 🔴 « arbitrage en attente »** dans le registre d'état (section Arbitrages).
4. **Présenter à l'humain** : l'état, la preuve, et une **question de modalité** avec 2–3 options.
5. **S'arrêter** et rendre la main. Ne rien committer d'irréversible.
6. Quand l'humain tranche → **ADR** (décision + pourquoi + alternatives écartées), déplacer
   l'entrée en ✅ dans le registre, puis exécuter la modalité choisie.

## Points irréversibles — RÉTROFIT

| # | Point | Preuve que l'IA assemble | Question de modalité (humain) |
|---|---|---|---|
| 0 | **Bascule de stack** (projet pas sur ApiPlatform+Doctrine) | Analyse coût/bénéfice : rebase préliminaire vs coexistence deux stacks ; tests 4 couches + caractérisation du périmètre | Quand ? rebase global ou strangler périmètre par périmètre ? re-recette prod ? |
| 1 | **Bascule backend** (SQL inline retiré, front sur client généré) | Contrat matérialisé (spec+client+routes), tests 4 couches + caractérisation verts | Front et back basculent ensemble ? calendrier opérationnel ? |
| 2 | **Bascule frontend D2** (rendu îlots-first) | E2E vert **+ régression visuelle verte** (goldens, tolérance définie), ancien rendu côte à côte | Lance-t-on l'écran îlots ? quels parcours sont « critiques » (filmés) ? |
| 3 | **Suppression d'un périmètre legacy** | Tests 4 couches + caractérisation ; trafic basculé (ou dark) | Timing (pic d'activité ? fenêtre de maintenance) ? procédure de rollback ? |
| 4 | **Suppression / reversion d'une migration en prod** | Analyse d'impact données ; la migration n'affecte aucun périmètre migré | Reverser maintenant ou attendre ? données perdues ? qui assume ? |
| 5 | **Passage à l'architecture engagée** (phase 4) | Diagnostic des 7 dimensions **re-mesuré, tout vert** | L'architecture est-elle engagée ? dérogations acceptables (ADR) ? |

## Points d'arbitrage — CONCEPTION (portes nouveau & release)

| Point | Preuve / analyse | Traitement |
|---|---|---|
| **Choix d'archétype** | `bmad/archetypes.md` : inféré du brief (état persisté + écran → full-stack ; etc.) | **Défaut auto-tranché** par l'agent, annoncé en une phrase (`defaults.md`). Pas une question au PO non-dev. Ne remonte que si le **cadrage métier** est ambigu, et alors en langage clair (« une seule liste ou des comptes ? ») |
| **Découpage de release** | Backlog de stories « Agent IA Ready » + chiffrage `../skills/abaque-cout-capacite.md` | Question **métier** au PO : quel périmètre / quel ordre (pas de jargon) |
| **Report du frontend D2** | Mesure de dérive de rendu (rendu serveur ? SPA ? code mort ?) | **Auto-tranché** : si pas de dérive, report sur ADR — sinon migration D2. Pas de question technique au PO |

## Séquençage (arbitrage modal, pas destination)

L'IA **produit l'ordre optimal** des périmètres (priorité par dérive mesurée, puis dépendances) ;
l'humain peut l'**infléchir** pour raison opérationnelle (urgence, équipe, calendrier), mais
part de la proposition de l'IA. À tracer au registre.
