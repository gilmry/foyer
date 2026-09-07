# Rôle : gate-runner (invoquer et lire les gates)

> Le contrat des commandes vit dans [`../gates/README.md`](../gates/README.md) (nom → commande
> → exit code → sens). Ce rôle **exécute** les gates au bon moment et **interprète** le résultat.

## Mission
Faire passer les gates de l'étape courante, lire leur **exit code**, et mettre à jour le registre.
**Un gate rouge = stop** : on remonte la cause, on ne force pas, on ne passe pas à l'étape suivante.

## Principe (portable, DRY)
Chaque gate a une **CLI stable** et un **exit code** (0 = 🟢, ≠0 = 🔴). Les mêmes commandes tournent
en local et en CI. L'agent n'interprète jamais un gate « à l'œil » : il lit le code de sortie.

## Ordre d'exécution (du plancher vers le sommet)
1. **Plancher** (bloquant, toujours) : secrets, migrations réversibles.
2. **Structurel** : `verify` (pureté des couches, artefacts, invariants).
3. **Contrat** (anti-drift) : spec OpenAPI ↔ client généré ↔ routes.
4. **Pyramide** : Unit (domaine) → BDD (cas d'usage) → Intégration (contrat HTTP).
5. **E2E** (correctness, bloquant) sur le parcours de référence.
6. **Caractérisation** (rétrofit) : comportement externe inchangé.
7. **Régression visuelle** (si bascule D2) : goldens, tolérance définie.
8. **Doc vivante** (preuve de valeur, **non bloquant**).

## Lecture des résultats → registre
- Écrire pour chaque gate : 🟢/🔴 + horodatage + commande.
- 🔴 → n'avance pas ; décrire la cause probable et la remettre au rôle propriétaire de l'étape.
- Ne jamais éditer à la main les artefacts générés (`openapi.json`, `frontend/src/generated/`) :
  un gate contrat rouge se corrige en **régénérant** (spec puis client) et en committant.

## Où trouver les commandes exactes
Elles dépendent du projet et sont listées dans **l'`AGENTS.md` du projet** et
[`../gates/README.md`](../gates/README.md). Exemples de référence (kit & dogfood stagesmed) :
`php scripts/verify.php`, `php bin/console app:gate:contract`,
`php bin/phpunit --testsuite Unit|Integration`, `php bin/behat`, `npm run e2e`,
et côté harnais rétrofit `bash harness/ci.sh`, `bash harness/run-*.sh`, `bash harness/run-demo.sh`.
