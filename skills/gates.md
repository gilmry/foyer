# Skill — Gates qualité & sécurité

*Skill enfant **transversal** de la primitive `../Boucle-de-retroaction.md`. C'est l'outil qui **objective** le code et les artefacts. Invoqué par `cycle-dev.md` (phase bleue) et par `convergence-iac.md`. Lit l'archétype (`../bmad/archetypes.md`).*

> **Registre.** Ce skill **transmet le critère** (guidance). Le **blocage mécanique** appartient aux hooks Git et à la CI (enforcement). Même jeu de vérifications en local et en CI (DRY) : c'est cette redondance qui fait la boucle de rétroaction serrée — un signal d'outil, pas un avis. Pour du code généré par IA, ce retour automatique rapproche la fiabilité d'un langage compilé.

---

## Deux registres, à ne jamais confondre

Toutes les vérifications ne se valent pas, et les traiter pareil abîme les deux. Un blocage posé sur un critère discutable se fait contourner en `--no-verify` et emporte avec lui la crédibilité de ceux qui ne se discutent pas. Inversement, un contrôle qui ne bloque jamais alors qu'il capte de l'information irrécupérable ne protège rien.

| | **Plancher mécanique** | **Exigence de jalon** |
|---|---|---|
| Qui tranche | la CI, sans exception | l'humain, en gate review |
| Critère d'entrée | objectivable **∧** irréversible | tout le reste |
| Ce que ça produit | un build rouge | un rapport à trier |
| Reboucle par | correction puis relance | le jugement |

Ce n'est pas une nouveauté de ce skill : c'est la distinction guidance/enforcement d'`enforcement.md` appliquée au terrain code, et la gate review de `../Methode-Foyer.md` §3 pour l'autre moitié.

## Le plancher — le critère, vérifié dans cet ordre

1. **Objectivable** — la machine tranche sans jugement. Le fichier existe ou non ; le secret matche un motif ou non.
2. **Irréversible** — ne pas vérifier maintenant rend l'information **perdue** plus tard, pas seulement plus coûteuse à corriger.

Les deux, pas l'un des deux. C'est exigeant à dessein : le plancher tire sa force d'être court.

| Gate | Ce qui est vérifié | Pourquoi c'est irréversible |
|---|---|---|
| **Secrets** | aucun secret dans le diff ni l'historique | un secret poussé est fuité ; la rotation ne défait pas la fuite |
| **SBOM** | nomenclature produite à chaque build (CycloneDX) | l'arbre de dépendances d'un build passé ne se reconstitue pas après coup |
| **Vulnérabilités conteneur** | image scannée avant push registre | même logique, à l'échelle de l'artefact déployé |

S'y ajoute, pour l'archétype **stateful**, le **fichier de retour de migration** (`*.down.sql`) : seul gate qui protège un état de base plutôt qu'un artefact logiciel, mais qui satisfait exactement le même double critère — le fichier existe ou non, et une migration sans retour jouée en production ne se défait pas.

**La provenance IA n'est pas au plancher**, malgré une irréversibilité réelle (une inférence passée ne se journalise pas rétroactivement). Elle échoue sur l'objectivabilité : vérifier une dérogation art. 6§3 est un jugement sur la finalité, pas un fait détectable dans un diff. Un gate qui prétendrait la contrôler ne vérifierait qu'un substitut — présence d'un fichier, d'un label — et passerait au vert pendant que l'exigence resterait non tenue. Une assurance fausse est pire qu'une absence de gate.

## L'exigence de jalon — ce qui remonte au jugement

Produit un rapport, jamais un build cassé. Le **seuil** se fixe sur le niveau **CyFun®** visé (Small / Basic / Important / Essential) ; il est vérifié en **gate review**, pas à chaque commit.

- **Qualité interne** — format · lint · types (`mypy --strict`, `tsc --noEmit`, `svelte-check`) · complexité cyclomatique · code mort · couverture par couche, la plus haute sur le Domain.
- **Sécurité** — SAST · SCA (vulnérabilités connues des dépendances) · licences (cohérence AGPL / permissives) · DAST sur l'environnement E2E · injection de prompt (OWASP LLM #1) si le produit livré embarque un LLM.
- **Provenance IA** — checklist de mise en service : version de modèle et endpoint consignés dans la configuration versionnée · juridiction d'hébergement documentée · accès au journal d'interactions restreint et finalité déclarée · évaluation art. 6§3 documentée si la fonction touche l'annexe III.
- **Provenance SLSA** — attestation de la chaîne de build. Exigible sous **CRA** (obligations pleines déc. 2027). *Angle mort — voir `conformite.md` §5.*

Un finding SAST est un **jugement de triage**. Le bloquer en CI ne le fait pas corriger, il le fait contourner. C'est le point où l'on demandera pourquoi le SAST ne casse rien : la réponse est le critère ci-dessus, pas une exception qu'on aurait consentie.

## Imposer le format, jamais l'outil

Le gate porte sur un **contrat d'échange** — **SARIF** pour les findings, **CycloneDX 1.6+** pour le SBOM — jamais sur un produit précis. Deux raisons, lexicographiquement ordonnées :

1. **Réversibilité** — un outil qui exporte un format ouvert reste substituable sans réécrire le pipeline.
2. **Autonomie du grain** — imposer un outil à une équipe qui n'en répond pas découple le choix de qui en assume les conséquences. Ce skill fixe le plancher ; chaque grain (`../personas/`) choisit l'outil qui le remplit.

**Cette règle a déjà encaissé un incident réel.** Décembre 2024 : Semgrep restreint la licence de ses règles communautaires — une érosion au sens de `arbitrage-hybride.md` §5. Opengrep, fork sous gouvernance de consortium, prend le relais **sans modification des jobs CI**, précisément parce que le contrat portait sur le format de sortie. Ce n'est donc pas un principe de précaution : c'est une règle testée, à coût nul.

La liste consolidée des outils qui remplissent ce contrat, avec le verdict de veto ligne par ligne et les écartés, vit dans **`../tools/gates/ADR-outillage.md`**.

## Conditionnement par archétype

- **stateless** — surtout SCA + secrets ; pas de check de migration.
- **stateful** — SAST injection SQL ; **fichier de retour de migration au plancher** ; secrets DB.
- **API-first** — `@security` de contrat : autorisation par endpoint, schémas stricts, **pas de rupture de version non déclarée** (point irréversible).
- **full-stack** — CSP/XSS sur les îlots Svelte ; en-têtes de sécurité ; DAST sur les flux E2E critiques ; **régression visuelle** (goldens du parcours partagé, tolérance définie) **bloquante à la bascule de rendu D2** (îlots-first) — c'est la 3e harnais de `documentation-vivante.md`, et la preuve exigée par la bascule n°2 de `migration-projet-existant.md`.

## Ancrage conformité

La security gate est le point où les standards **s'objectivent dans la fabrication** : chaque contrôle pertinent a une vérification correspondante.

- **ISO 27001:2022 / CyFun®** (Belgique) — gestion des accès, des dépendances, des secrets. Le **niveau CyFun visé** fixe le **seuil de l'exigence de jalon** — pas celui du plancher, qui ne se négocie pas.
- **NIS2 · CRA · NIST SSDF** — secure-SDLC, gestion des vulnérabilités, *security-by-design*. Le SBOM exigible sous CRA est désormais **couvert par le plancher**.
- **ISO 42001 / EU AI Act** — la traçabilité (registre TRACE, ADR/RFC) et le répondre-de portent le volet IA, pas la gate code.

Le mapping complet des trois cercles (mondial → européen → belge) et le **backlog des angles morts** vivent dans **`conformite.md`**. Voir aussi le mapping ISO 27001 → IaC du livrable Architecture.

## Mettre les gates en place — une story habilitante

Sans outil pour objectiver, pas d'Évaluation, donc pas de cercle : l'installation des gates **est une story**, et elle **précède** celles qui en dépendent (`../Boucle-de-retroaction.md` §Corollaire ; forme aboutie dans `bootstrap-delivrabilite.md`).

Le plancher d'abord — c'est lui qui capte l'information irrécupérable, et chaque jour sans lui est une perte sèche, pas un report. L'exigence de jalon ensuite. L'agrégateur en dernier, après l'atelier de sélection (`../tools/gates/ADR-outillage.md` §Agrégateur).

## Condition de sortie

**Plancher rouge = le cercle réfute** → on reboucle (corriger, relancer). Plancher vert = sortie permise.

L'exigence de jalon ne referme pas le cercle de la même façon : elle reboucle par le **jugement**, en gate review, et son verdict peut légitimement être « accepté, tracé, reporté ». Le passage à un environnement via une **branche GitFlow source de vérité** reste un point irréversible → **l'humain valide**.

## Angle mort surveillé

*« Assez fiable pour qu'on cesse de vérifier »* vise ici deux cibles précises : le **SBOM** et la **provenance IA**. Ce sont les gates qu'on est tenté de couper après plusieurs cycles sans rien trouver — et c'est exactement le moment où l'information qu'ils capturent redevient irremplaçable si on les coupe.

## Coût

Les gates ajoutent du **wall-clock** (durée des scans, run CI) → coût superviseur. Peu de tokens. C'est l'asymétrie typique des terrains à validation par exécution.

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0).*
