# Personas Phase 2-4 — qui tient le cercle, à quel grain

*Axe rôle/grain de la primitive (`../Boucle-de-retroaction.md`). Chacun **compose** des skills (`../skills/`) ; aucun ne les duplique. L'**architecte solution** n'a pas de fichier ici : c'est l'agent du `../Manifeste-Foyer.md`, qui tient la **méta-boucle ADR/ADM** (et qui, en conception, est l'Architecte de BMAD).*

## Invariants au grain (un persona, qui scale)
- [Chef de projet](chef-de-projet.md) — pilotage : WBS → Gantt → coût → cadre
- [CSI engineer](csi-engineer.md) — process & estimation (dogfooding)
- [Support engineer](support-engineer.md) — usage & doléances (RACE/RICE)
- [Estimateur de capacité & coût](estimateur-capacite-cout.md) — anticipation TCO+ROI+empreinte (FinOps)

## Conditionnels au barreau (activés selon l'échelle, décidée au Gantt)
- **Scrum** : [Scrum Master](scrum-master.md) · [Lead developer](lead-developer.md)
- **Runtime/ITIL** : [Platform engineer](platform-engineer.md)
- **Nexus** : [Nexus Integration Team](nexus-integration-team.md)
- **SAFe** : [RTE](rte.md)

*Le barreau monte avec le parallélisme ; les invariants montent avec lui, les conditionnels s'activent. Tous : registre guidance — l'enforcement reste aux hooks/gates.*
