# Contrat de gates — CLI stable, agnostique du runtime

> Un gate = **une commande à CLI stable** avec un **exit code** (0 = 🟢, ≠0 = 🔴). Les mêmes
> commandes tournent en local et en CI (DRY). Le rôle [`../roles/gate-runner.md`](../roles/gate-runner.md)
> les invoque dans l'ordre et lit l'exit code — jamais « à l'œil ».

Les commandes exactes vivent dans **l'`AGENTS.md` du projet cible**. Les tableaux ci-dessous sont
les **références** (kit Foyer + dogfood rétrofit stagesmed) à recopier/adapter.

## Registre générique (nom → moment → bloquant)

| Gate | Moment | Bloquant | Sens |
|---|---|---|---|
| `plancher` | phase 1 / avant tout code | **oui** | secrets hors dépôt+historique ; migrations réversibles (`down.sql`) |
| `verify` | à chaque étape | **oui** | invariants structurels (pureté des couches, artefacts) |
| `contrat` | après couche Contrat | **oui** | spec OpenAPI ↔ client généré ↔ routes en phase (anti-drift) |
| `unit` | couche Domaine | **oui** | domaine pur |
| `integration` | couche Adaptateurs | **oui** | contrat HTTP (statuts, désérialisation stricte) |
| `bdd` | couche Application | **oui** | cas d'usage en langage métier |
| `e2e` | frontend D1 | **oui** | correctness du parcours de référence |
| `caracterisation` | rétrofit, chaque bascule | **oui** | comportement externe inchangé |
| `visuel` | bascule D2 | **oui à la bascule** | régression visuelle (goldens, tolérance) |
| `doc-vivante` | avec la fonctionnalité | non | preuve de valeur (galerie + vidéo) |

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
```

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
