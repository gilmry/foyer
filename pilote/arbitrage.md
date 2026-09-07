# arbitrage.md — points irréversibles & protocole

> Fait autorité : [`../skills/arbitrage-hybride.md`](../skills/arbitrage-hybride.md).
> Ici : la liste opérationnelle des points et le **protocole** que l'agent applique.

## Règle d'or

**L'IA prépare et présente la preuve ; l'humain décide la _modalité_ — jamais la destination.**
La destination (kit hexagonal + contrat matérialisé + îlots-first) est **fixée**. Ce qui se
tranche : *timing, séquençage, mécanique de bascule, rollback, dérogations tracées en ADR*.

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

| Point | Preuve / analyse | Question de modalité |
|---|---|---|
| **Choix d'archétype** | `bmad/archetypes.md` : stateless / stateful / api-first / full-stack + conséquences sur gates | Quel archétype engage-t-on (fixe les gates conditionnels) ? |
| **Découpage de release** | Backlog de stories « Agent IA Ready » + chiffrage `../skills/abaque-cout-capacite.md` | Quel périmètre entre dans la release ? quel ordre ? quelle capacité ? |
| **Report du frontend D2** | Mesure de dérive de rendu (rendu serveur ? SPA ? code mort ?) | Si pas de dérive : report accepté sur ADR — sinon migration D2 exigée |

## Séquençage (arbitrage modal, pas destination)

L'IA **produit l'ordre optimal** des périmètres (priorité par dérive mesurée, puis dépendances) ;
l'humain peut l'**infléchir** pour raison opérationnelle (urgence, équipe, calendrier), mais
part de la proposition de l'IA. À tracer au registre.
