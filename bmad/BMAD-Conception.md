# BMAD — Pipeline de conception (Phase 1)

*Orchestrateur. Cinq personas de conception transforment une vision en backlog prêt pour la fabrication. Hérite de la primitive `../Boucle-de-retroaction.md` : BMAD est le **premier tour du cercle, au grain projet**.*

---

## Ce qu'est BMAD

BMAD traduit la vision stratégique (TOGAF) en backlog structuré : par où commencer, dans quel ordre. Il décompose **épopées → capacités → fonctionnalités → user stories**, en garantissant que rien n'entre en sprint sans alignement à la vision.

**Règle d'or : un agent = un rôle = un livrable.** Chaque persona génère ; le superviseur valide avant le suivant. Un livrable non relu par l'humain est une faute au sens *répondre-de*.

## Le pipeline

| Phase TOGAF | Persona | Livrable |
|---|---|---|
| A — Vision | [Analyste](personas/01-analyste.md) | [Product Brief](livrables/product-brief.template.md) |
| B-C — Business + SI | [Product Manager](personas/02-product-manager.md) | [PRD](livrables/prd.template.md) |
| C-D — SI + Technique | [Architecte](personas/03-architecte.md) | [Architecture (7 couches, ADR)](livrables/architecture.template.md) |
| E — Solutions | [Scrum Master](personas/04-scrum-master.md) | [Epics & Stories](livrables/epics-stories.template.md) |
| F — Migration | [Validateur](personas/05-validateur.md) | [Rapport de validation](livrables/validation.template.md) |

**Usage** : charge un persona à la fois dans le contexte de l'agent (une conversation = un rôle), fais-lui remplir son template, valide, passe au suivant.

## Étape 0 — Configuration projet (pré-requis)

Le superviseur fixe les paramètres injectés dans chaque persona :

- **Nom** et **domaine métier**
- **Stack backend** : Python LTS, hexagonale (DDD au centre), FastAPI dans les adapters ; SQLAlchemy **ou** CQRS SQL pur sur PostgreSQL (tracé en ADR)
- **Stack frontend** : pages Astro statiques + îlots Svelte 5 (runes) + APIs TS
- **Contraintes** : RGPD, ISO 27001, NIS2 · souveraineté/hébergement · multilingue
- **Échelle visée** : Scrum / Nexus / SAFe (réévaluable au Gantt)
- **Archétype du composant** : état (*stateless* / *stateful*) × surface (*API-first* / *full-stack*) — voir [archetypes.md](archetypes.md). Il conditionne les couches en scope et les sections de chaque délivrable.

## La condition de sortie

BMAD est un cercle : on reboucle vers le persona concerné **tant que le Validateur réfute**, on sort **au verdict PASS**. La sortie validée = le **déclencheur du chef de projet** (Phase 2 : WBS → Gantt → coût). La *roadmap par capacité* produite ici est la matière de son pilotage. Passage = décision engageante → **le superviseur valide**.

---

*Personas et templates : registre *guidance*. Les garde-fous déterministes restent dans les hooks/permissions. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
