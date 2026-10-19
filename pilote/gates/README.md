# Contrat de gates — CLI stable, agnostique du runtime

> Un gate = **une commande à CLI stable** avec un **exit code** (0 = 🟢, ≠0 = 🔴). Les mêmes
> commandes tournent en local et en CI (DRY). Le rôle [`../roles/gate-runner.md`](../roles/gate-runner.md)
> les invoque dans l'ordre et lit l'exit code — jamais « à l'œil ».

Les commandes exactes vivent dans **l'`AGENTS.md` du projet cible**. Les tableaux ci-dessous sont
les **références** (kit Foyer + dogfood rétrofit stagesmed) à recopier/adapter.

## Registre générique (nom → moment → bloquant)

| Gate | Moment | Bloquant | Sens |
|---|---|---|---|
| `plancher` | phase 1 / avant tout code, puis à chaque build | **oui** | le plancher mécanique de [`../../skills/gates.md`](../../skills/gates.md) §Le plancher, **qui fait foi** : secrets · SBOM CycloneDX · vulnérabilités conteneur (si le projet livre une image) · migration réversible (archétype stateful) |
| `verify` | à chaque étape | **oui** | invariants structurels (pureté des couches, artefacts) |
| `contrat` | après couche Contrat | **oui** | spec OpenAPI ↔ client généré ↔ routes en phase (anti-drift) |
| `unit` | couche Domaine | **oui** | domaine pur |
| `integration` | couche Adaptateurs | **oui** | contrat HTTP (statuts, désérialisation stricte) |
| `bdd` | couche Application | **oui** | cas d'usage en langage métier |
| `e2e` | frontend D1 | **oui** | correctness du parcours de référence |
| `caracterisation` | rétrofit, chaque bascule | **oui** | comportement externe inchangé |
| `visuel` | bascule D2 | **oui à la bascule** | régression visuelle (goldens, tolérance) |
| `doc-vivante` | avec la fonctionnalité | non | preuve de valeur (galerie + vidéo) |
| `promotion` | avant toute promotion de branche (bascule, fusion vers la branche source de vérité, mise en production) | **oui** | la preuve est **complète** : plancher et tests verts sur le head ; quatre classes présentes **et exécutées** ; vitrine présente si la story touche un écran critique. Ne juge pas la valeur, vérifie qu'on peut la juger (`../roles/arbitre-de-promotion.md`) |

> `doc-vivante` reste non bloquant au fil de l'eau ; mais une branche sans vitrine est **inarbitrable**,
> et c'est le gate `promotion` qui le dit, au moment de promouvoir.

> **Une seule définition du plancher**, celle du skill. Ce tableau la référence au lieu de la
> recopier : la prochaine révision du skill ne doit pas rouvrir un écart ici.

## Exigence de jalon (rapport, pas gate)

Le second registre de [`../../skills/gates.md`](../../skills/gates.md). **Pas d'exit code bloquant** :
un rapport produit en CI, trié par l'humain en **gate review**, au seuil fixé par le niveau CyFun®
visé du registre (`../state.template.md`).

| Rapport | Format | Où il remonte |
|---|---|---|
| Qualité interne (lint, types, complexité, couverture) | sortie de l'outil | registre, section Gates, ligne `jalon` |
| SAST | SARIF | idem, findings triés en gate review |
| SCA (dépendances) | JSON de l'outil | idem, triage selon le plan de gestion des vulnérabilités |
| Licences, DAST, injection de prompt (si le produit embarque un LLM) | SARIF ou JSON | idem |

Les tests (`unit`, `bdd`, `integration`, `e2e`, `caracterisation`) **restent bloquants** : ce sont les
preuves du cycle de craft (`../../skills/cycle-dev.md`), pas des analyseurs. Un finding de jalon ne
bloque jamais un commit ; le bloquer le ferait contourner, pas corriger. Les rapports sont aussi des
preuves pour l'autoévaluation CyFun (`../../skills/conformite.md` §2ter et §2quater).

## Référence KIT (`foyer/kit-php/`)

```
plancher/verify   php scripts/verify.php
contrat           php bin/console app:gate:contract
unit              php bin/phpunit --testsuite Unit
integration       php bin/phpunit --testsuite Integration
bdd               php bin/behat
e2e               (cd frontend && npm run e2e)
typecheck         (cd frontend && npm run typecheck)
test-front        (cd frontend && npm run test)
doc-vivante       (cd frontend && npm run docs:living)      # non bloquant
migrations        php bin/console app:migrate                # up/down réversible
sbom              composer CycloneDX:make-sbom --output-format=JSON --output-file=sbom.cdx.json --omit=dev
```

Le scan conteneur et les rapports de jalon vivent en CI : gabarits dans [`../../tools/gates/`](../../tools/gates/).

## Référence DOGFOOD RÉTROFIT (`stagesmed-retrofit-test/harness/`)

```
verify (plancher+stock)   docker run … php harness/verify.php      # G1/G2 + S1-S6 (+ H1 info)
ci (tous les gates)       bash harness/ci.sh
caractérisation           bash harness/run.sh                      # periods
                          bash harness/run-<périmètre>.sh          # students/medecins/auth/admin/doctor
régression visuelle       harness/visual/ (VISUAL_MODE=capture|compare, tolérance 0,5 %)
doc-vivante               bash harness/run-demo.sh [filtre]        # non bloquant → harness/demo/vitrine/
```

> Convention : tout nouveau projet expose ses gates sous ces mêmes **noms** dans son `AGENTS.md`,
> pour que le pilote soit rejouable à l'identique quel que soit le runtime.
