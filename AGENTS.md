# Foyer Framework

This is a framework for AI agents in software development, derived from Gilles Maury's work on sustainable, responsible software development.

## Key Files

- `Manifeste-Foyer.md`: Identity and values of the agent (Architect Solution)
- `Methode-Foyer.md`: Operational method for agent work
- `Boucle-de-retroaction.md`: Core feedback loop
- `skills/`: Tools for objective evaluation (cycle-dev, gates, convergence-iac, adoption, etc.)
- `personas/`: Roles that hold the feedback loop (chef-de-projet, scrum-master, lead-developer, etc.)
- `pilote/`: **Agentic driver** — makes the method executable by agents across heterogeneous tools.

## Pilote — driving the method with agents (start here)

To run a project with agents: **clone this repo, then hand `pilote/BOOTSTRAP.md` to an AI agent.**
It bootstraps, asks what you want to do — **Q0: new project / retrofit / release** — creates a
shared **state register**, and drives the journey. Portable *multiagent*: one open core (Markdown +
scripts), thin per-tool adapters. Devs run it on Claude Code, POs on ChatGPT/Qwen, both on the
**same committed state register**.

- Launcher: `pilote/BOOTSTRAP.md` · Dispatcher: `pilote/parcours.md`
- Shared state (PO↔dev source of truth): `pilote/state.template.md`
- Irreversible-point arbitration (modality, never destination): `pilote/arbitrage.md`
- Gate CLI contract (stable names, exit codes): `pilote/gates/README.md`
- Adapters: `pilote/adapters/{claude,generic,opencode}/`

The pilote does not reinvent anything: it **sequences** the existing `skills/`, `personas/` and
`bmad/` into three journeys with a state register and arbitration gates. See `pilote/README.md`.

## Workflow

1. **Conception (BMAD)** - Create backlog with validated "Agent IA Ready" stories
2. **Pilotage** - Project manager coordinates timeline, costs, and choice of methodology
3. **Fabrication** - Lead developer and scrum master execute cycle-dev with gates
4. **Production** - Platform engineer manages convergence-iac
5. **Pilotage continu** - CSI engineer refines estimates; Support engineer evaluates adoption

## Agent Instructions

The framework encourages AI agents to:
- Generate code, but have humans validate
- Work in pairs or mobs to avoid single points of failure
- Focus on sobriety, durability, and transmissibility
- Emphasize the "répondre-de" principle: "Pourrai-je en répondre, et devant qui?"

## Core Principles

- All decisions should be traceable via ADRs (Architectural Decision Records)
- Gate reviews ensure architectural foundations remain solid
- Capacity-based milestones (not arbitrary dates)
- All choices should be justified and presented to humans
- Balance between efficiency and human responsibility

## Cost Considerations

- Tokens: 0.85 €/Mtok in, 2.55 €/Mtok out
- Wall-clock: S=0.5 j / M=0.75 j / L=1 j

## Repository Structure

This is a methodology repository for the Foyer framework. Key directories:
- `kit-php/` - **Kit de référence exécutable** (PHP hexagonal + îlots, gates sur images Docker
  publiques). « Clone → `bash docker/build.sh` → `bash harness/ci.sh` » passe au vert. Famille de
  kits (autres stacks à venir) : voir `KITS.md`.
- `bmad/` - Conception phase (TOGAF pipeline)
- `skills/` - Objective evaluation tools (cycle-dev, gates, convergence-iac, adoption)
- `tools/` - Executable counterpart to the skills. Currently `tools/gates/`:
  the consolidated tool list (`ADR-outillage.md`) plus CI templates per stack.
  **Templates carry a `.example` suffix and never run on this repository** —
  they are examples to draw from, reinstantiated per consuming project.
- `personas/` - Roles that hold the feedback loop
- `docs/` - Generated documentation site
- `notebooklm/` - Media assets for educational materials
- `scripts/` - Generation scripts for documentation

## Commands

- Build documentation: `mkdocs build`
- Serve documentation locally: `mkdocs serve`
- Generate supports page: `python scripts/gen_supports.py`
- Generate gates templates page: `python scripts/gen_gates.py`

## Special Notes

- The framework is designed to be portable across agent platforms (OpenCode, Claude, etc.)
- All decisions should be made with human oversight ("répondre-de" principle)
- The core feedback loop follows: Conception → Construction → Result → Evaluation → Improvement
- Documentation is built with MkDocs Material and deployed via GitHub Actions