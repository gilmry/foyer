# Skill — Adoption (usage réel)

*Skill enfant de la primitive `../Boucle-de-retroaction.md`. L'outil qui **objective** est l'**usage réel** : les doléances remontées par les issues + les signaux **RACE**. C'est l'étage qui **referme le cercle** sur une nouvelle capacité. Tenu par le persona support engineer (à venir).*

---

## Le cercle pour l'usage

- **Conception** — tu définis l'**hypothèse d'adoption** : ce que « adopté » veut dire pour cette capacité, de façon mesurable (pas une intention de vente — une adoption réelle).
- **Construction** — tu **instrumentes** les signaux (mesure du parcours, collecte des issues).
- **Résultat** — l'usage a lieu.
- **Évaluation** — **RACE objective** où le parcours décroche ; les **doléances** qualifient le vécu.
- **Amélioration** — **RICE / WSJF priorise** → alimente le **point 0 de la capacité suivante**.

Ce dernier temps **referme la spirale** : l'usage prioritisé rouvre une conception (BMAD), dont le point 0 est seedé par le CSI, dont la fabrication réalimente la télémétrie.

## Deux instruments

**RACE — objectiver l'usage** (Convert réinterprété en **Adoption**, par honnêteté : on ne « convertit » pas une communauté) :
- **Reach** — l'audience touchée
- **Act** — la première interaction
- **Adopt** — l'usage réel et récurrent *(le cœur honnête de la mesure)*
- **Engage** — la rétention et la profondeur d'usage

**Issues → doléances** : le support recueille, qualifie, et fait remonter le vécu utilisateur. C'est l'autre source d'Évaluation, qualitative.

**RICE / WSJF — prioriser** ce qu'on en fait :
- **RICE** = Reach × Impact × **Confidence** ÷ **Effort** — *Confidence* ← le **CSI** (mesure réelle, pas intuition), *Effort* ← l'**estimation en tours** de la primitive.
- **WSJF** (variante SAFe, au-dessus de la story) = Coût du retard ÷ taille du job.

## Conditionnement par archétype

- **full-stack** — adoption mesurée au parcours UI (Reach→Engage par persona).
- **API-first** — adoption mesurée côté consommateurs (usage des endpoints, intégrations actives), pas UI.
- **stateless / stateful** — facette secondaire ici ; pertinent surtout via la fréquence et la profondeur d'usage.

## Lien TOGAF — la dernière condition de la capacité

Une capacité n'est **« disponible »** que si l'usage réel en valide la pertinence. Ce skill est l'instrument qui mesure cette dernière condition — celle qu'un code « fini » ne prouve pas.

## Point sensible — l'altérité

**Déprécier une capacité déjà adoptée** affecte un tiers non consentant (l'utilisateur). C'est un point où l'**altérité prime** (avant réversibilité, coût) : tu présentes le motif et l'impact usager, **l'humain valide**.

## Coût

Signaux d'adoption = **fort wall-clock** (l'usage réel s'accumule dans le temps), quasi pas de tokens. Asymétrie assumée : le coût est en observation, pas en génération.

---

*Registre guidance / trace. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
