# Skill — Gates qualité & sécurité

*Skill enfant **transversal** de la primitive `../Boucle-de-retroaction.md`. C'est l'outil qui **objective** le code et les artefacts. Invoqué par `cycle-dev.md` (phase bleue) et par `convergence-iac.md`. Lit l'archétype (`../bmad/archetypes.md`).*

> **Registre.** Ce skill **transmet le critère** (guidance). Le **blocage mécanique** appartient aux hooks Git et à la CI (enforcement). Même jeu de vérifications en local et en CI (DRY) : c'est cette redondance qui fait la boucle de rétroaction serrée — un signal d'outil, pas un avis. Pour du code généré par IA, ce retour automatique rapproche la fiabilité d'un langage compilé.

---

## Quality gate (code) — *après le refactor (bleu)*

Objective la **qualité interne**. Bloque tant qu'un seuil n'est pas tenu.

- **Format** — `black` + `isort` (Python) · `prettier` (TS/Svelte)
- **Lint** — `ruff`/`flake8` (Python) · `eslint` (TS)
- **Types** — `mypy --strict` (Python) · `tsc --noEmit` (TS) · `svelte-check`
- **Complexité** — seuil cyclomatique ; refus du code mort
- **Couverture** — seuil minimal par couche (Domain le plus élevé)

## Security gate (code + e2e) — *après E2E + intégration (bleu)*

Objective la **surface d'exposition**. C'est le shift-left : on cherche avant de réparer.

- **SAST** — `bandit` (Python) · règles sécurité `eslint` (TS)
- **Dépendances (SCA)** — `pip-audit` · `npm audit` ; refus des vulnérabilités connues non justifiées
- **Secrets** — `gitleaks`/`trufflehog` ; aucun secret dans l'arbre ni l'historique
- **Licences** — compatibilité des dépendances (cohérence AGPL/permissives)
- **DAST** — sur l'environnement E2E quand applicable

## Conditionnement par archétype

- **stateless** — surtout SCA + secrets ; pas de check de migration.
- **stateful** — SAST injection SQL ; vérif des migrations ; secrets DB.
- **API-first** — `@security` de contrat : autorisation par endpoint, schémas stricts, **pas de rupture de version non déclarée** (point irréversible).
- **full-stack** — CSP/XSS sur les îlots Svelte ; en-têtes de sécurité ; DAST sur les flux E2E critiques.

## Ancrage conformité

La security gate est le point où **ISO 27001 / NIS2** s'objectivent dans la fabrication : chaque contrôle pertinent (gestion des accès, des dépendances, des secrets) a une vérification correspondante. Voir le mapping ISO 27001 → IaC du livrable Architecture.

## Condition de sortie

Une gate qui bloque = **le cercle réfute** → on reboucle (corriger, relancer). Gates vertes = sortie permise. Le passage à un environnement via une **branche GitFlow source de vérité** reste un point irréversible → **l'humain valide**.

## Coût

Les gates ajoutent du **wall-clock** (durée des scans, run CI) → coût superviseur. Peu de tokens. C'est l'asymétrie typique des terrains à validation par exécution.

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0).*
