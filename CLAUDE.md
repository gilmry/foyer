# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Nature du dépôt

Ce dépôt n'est **pas une application** : c'est le **cadre méthodologique Foyer**, un ensemble de fichiers Markdown (contenu intellectuel de Gilles Maury) et de scripts qui les assemblent en un site MkDocs. Le contenu est en **français** — rédige commentaires, docs et commits en français.

`AGENTS.md` est le fichier de référence agent (OpenCode/Codex/Aider) et le champ `instructions` d'`opencode.json` liste explicitement l'ordre de chargement en contexte. **Garder `CLAUDE.md`, `AGENTS.md` et `opencode.json` cohérents** : ajouter un skill/persona/livrable implique de le référencer dans `opencode.json`.

## Commandes

Développement (aperçu du site avec hot reload) :

```bash
./go                    # installe les deps si besoin, lance mkdocs serve → http://localhost:8000
./go.ps1                # équivalent Windows
```

- Port/hôte : `FOYER_PORT`, `FOYER_HOST`.
- `./go` **ne fait pas `mkdocs build` directement** : il crée `.build/docs/`, puis sert. Le contenu de `.build/docs/` est assemblé au build par un hook (voir ci-dessous), pas édité à la main.

Build et génération :

```bash
mkdocs build            # rend le site (déclenche mkdocs_sync via le hook mkdocs)
python scripts/gen_supports.py    # (re)génère la galerie de supports depuis notebooklm/
python scripts/gen_gates.py       # (re)génère la page des templates de gates depuis tools/gates/
```

Dépendances docs : `pip install -r requirements-docs.txt`.

## Chaîne de build de la documentation (non évident)

`mkdocs.yml` pointe `docs_dir: .build/docs` — un répertoire **non versionné** (voir `.gitignore`). Le contenu réel vit à la **racine** et dans `skills/`, `personas/`, `bmad/`, `tools/`, `notebooklm/`. Au build, `scripts/mkdocs_sync.py` **copie** ces sources dans `.build/docs/` (avec des renommages, ex. `README.md` → `carte.md`). Deux pages sont **générées** car MkDocs ne rendrait pas leurs sources : `supports.md` (`gen_supports.py`) et `gates-templates.md` (`gen_gates.py`, les templates sont des `.yml.example`).

Conséquence : **ne jamais éditer `.build/docs/`** — c'est une sortie. Éditer les sources à la racine. Le déploiement se fait via GitHub Actions (`.github/workflows/docs.yml`) sur push `main` → GitHub Pages.

## Architecture conceptuelle

Tout hérite d'une **primitive unique**, la boucle de rétroaction (`Boucle-de-retroaction.md`) : Conception → Construction → Résultat → Évaluation → Amélioration, où un **outil externe objective** le résultat et où l'humain garde la responsabilité (*« pourrai-je en répondre, et devant qui ? »* = principe **répondre-de**).

Le cadre se lit selon trois axes, matérialisés par trois familles de fichiers :

- **`Manifeste-Foyer.md`** — qui est l'agent (valeurs, identité « Architecte Solution »).
- **`skills/`** — les 4 outils d'objectivation (enfants de la primitive) : `cycle-dev` (tests rouge/vert/bleu), `gates` (analyseurs qualité+sécurité), `convergence-iac` (état observé), `adoption` (usage réel), plus estimation, arbitrage hybride, conformité, enforcement.
- **`personas/`** et **`bmad/personas/`** — qui tient le cercle et à quel grain (chef-de-projet, lead-developer, scrum-master, etc.).

Flux de bout en bout : **`bmad/`** (Conception, pipeline TOGAF A–F → backlog validé « Agent IA Ready ») → Pilotage → Fabrication (`cycle-dev` + `gates`) → Production (`convergence-iac`) → Pilotage continu (`adoption`).

### `pilote/` — le driver agentique (rend la méthode exécutable)

`pilote/` ne réinvente rien : il **séquence** `skills/`, `personas/` et `bmad/` en trois parcours pilotables par des agents hétérogènes.

- Point d'entrée : **`pilote/BOOTSTRAP.md`** (à donner à l'agent) → pose **Q0** (nouveau projet / rétrofit / release) et crée un **registre d'état partagé**.
- Dispatcher : `pilote/parcours.md` ; parcours : `pilote/journeys/` ; rôles exécutables : `pilote/roles/`.
- **Registre d'état** (`pilote/state.template.md`) = source de vérité **commitée**, partagée entre dev (Claude Code) et PO (ChatGPT/Qwen). Portable multiagent : un cœur ouvert (Markdown + scripts) + de fins adaptateurs par outil dans `pilote/adapters/{claude,generic,opencode}/`.
- Arbitrage des points irréversibles : `pilote/arbitrage.md` (on arbitre la **modalité**, jamais la destination).
- **Contrat de gates** (`pilote/gates/README.md`) : un gate = **une commande CLI stable** avec exit code (0 = 🟢, ≠0 = 🔴), mêmes commandes en local et en CI. Les commandes exactes vivent dans l'`AGENTS.md` du **projet cible**, pas ici.

Adaptateur Claude Code (`pilote/adapters/claude/`) : commandes `.claude/commands/` (`/foyer-demarrer`, `/foyer-status`, `/foyer-next`, `/foyer-bascule`) et sous-agents `.claude/agents/` (un par rôle). Ces commandes ne sont qu'une **porte d'entrée** ; le comportement est défini par le cœur, identique quel que soit le runtime.

## `tools/` vs `skills/`

`skills/` = le **pourquoi** (objectivation) ; `tools/gates/` = le **comment exécutable**. `tools/gates/{github,gitlab}/` contient des templates CI par stack **suffixés `.example`** : ce sont des exemples à réinstancier dans le projet consommateur — ils **ne s'exécutent jamais sur ce dépôt**.

## Conventions

- **Ne pas committer** : `*.zip` déposés à la racine (« drops » à réconcilier puis jeter), `.build/`, `/site/`.
- Toute décision structurante se trace en **ADR** ; la « méta-boucle ADR/ADM » est tenue par l'Architecte Solution (l'agent du Manifeste).
