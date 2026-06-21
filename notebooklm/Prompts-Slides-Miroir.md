# Prompts présentations par slides — en miroir de la série Foyer

*Un deck par épisode de la série DSI : **V1–V8** miroir de la playlist vidéo, **DD1–DD3** miroir des deep dives. Chaque prompt fournit un squelette de slides (une idée par slide, peu de texte, un visuel par concept, une slide « à retenir »).*

## Réglages & usage

- Utilisables dans **NotebookLM** (fonction présentation / rapport, export **PPTX** possible) ou comme brief pour tout générateur de slides (Gemini, Claude…).
- **Langue** : Français. **Source** : le dépôt `gilmry/foyer` (resynchroniser après mise à jour).
- Principe transversal à rappeler dans chaque deck : **une idée par slide, ≤ 5 lignes de texte, un schéma quand c'est un concept, une slide de synthèse finale.**

---

# A — Decks miroir de la PLAYLIST VIDÉO

## S-V1 · Le problème et la promesse
> Crée une présentation pour un service informatique et son encadrement, une idée par slide, peu de texte, un visuel par slide. Structure : (1) Titre — « Foyer : livrer avec l'IA sans rompre la responsabilité » ; (2) Le constat — un service IT délègue à des agents IA et compose des choix hybrides (cloud/on-premise, propriétaire/open source, avec/sans support) ; (3) Le risque transversal — « assez fiable pour qu'on cesse de vérifier », la chaîne de responsabilité se rompt sans qu'on le voie ; (4) La promesse — préserver le répondre-de, rendre les choix traçables et défendables ; (5) L'idée unique — un même principe, la boucle de rétroaction, du code jusqu'à l'achat sur étagère ; (6) Ce qu'un service IT y gagne ; (7) À retenir. Appuie-toi sur le README et Manifeste-Foyer.

## S-V2 · La primitive : tout est une boucle
> Présentation pour un public technique d'un service informatique, une idée par slide, un schéma par concept. Structure : (1) Titre — « La primitive : tout est une boucle » ; (2) Le cercle — Conception → Construction → Résultat → Évaluation → Amélioration (schéma) ; (3) L'objectivation — un outil externe juge le résultat (test, gate, convergence d'infrastructure) ; (4) L'humain garde la sortie — « pourrai-je en répondre, et devant qui ? » ; (5) Auto-similarité — une story, un sprint, un projet, un achat : le même cercle ; (6) Condition de sortie — on referme tant que l'évaluation réfute ; sur l'irréversible, l'humain valide ; (7) À retenir. Source : Boucle-de-retroaction.

## S-V3 · Les principes : répondre-de, registres, souveraineté
> Présentation pour architectes et responsables techniques, une idée par slide. Structure : (1) Titre ; (2) Le répondre-de — la compréhension est la condition de la responsabilité, pas son but ; (3) Le danger — « assez fiable pour qu'on cesse de vérifier » ; (4) Trois registres — guidance / enforcement / trace ; (5) Grille de souveraineté — trois étages : résidence, données, capacité (résider n'est pas être souverain) ; (6) Réversibilité — louer le réversible, posséder l'irréversible ; (7) Veto lexicographique — altérité → réversibilité → érosion → coût, avec l'exemple des données d'un tiers ; (8) À retenir. Sources : Manifeste-Foyer, skills/arbitrage-hybride.

## S-V4 · Le flux de bout en bout
> Présentation pour les ingénieurs d'un service informatique, une idée par slide, un diagramme de flux. Structure : (1) Titre ; (2) Conception BMAD — cinq rôles → backlog « Agent IA Ready » ; (3) Pilotage — découpage en tâches, planning en passes d'agent, coût à deux axes (tokens, temps superviseur) ; (4) Fabrication — cycle-dev rouge/vert/bleu + gates qualité et sécurité ; (5) Production — convergence par infrastructure-as-code ; (6) Pilotage continu — CSI (estimation) + support (adoption) ; (7) Les trois axes + le ratio de supervision comme plafond du répondre-de ; (8) À retenir. Sources : Methode-Foyer, bmad/, skills/.

## S-V5 · L'enforcement en trois anneaux
> Présentation pour l'équipe sécurité et exploitation, une idée par slide, un schéma en couches concentriques. Structure : (1) Titre ; (2) Guidance vs enforcement ; (3) Anneau 1 — permissions déclaratives (autoriser/demander/refuser) ; (4) Anneau 2 — plugin programmatique qui bloque ; (5) Anneau 3 — substrat : hooks git, CI, protection de branche, sandbox ; (6) Le point décisif — les anneaux 1-2 sont contournables (sous-agents), le substrat seul fait foi ; (7) Règle — tout point irréversible au substrat ; (8) À retenir — « la parade est l'architecture, pas le contrat ». Source : skills/enforcement.

## S-V6 · La délivrabilité : git clone + agent
> Présentation pour un public technique, une idée par slide. Structure : (1) Titre ; (2) La cible — un git clone + une commande d'agent reconstruit tout ; (3) Les quatre environnements + les postes superviseur ; (4) Les six couches déclarées dans le dépôt ; (5) Idempotence — re-lancer donne le même état ; (6) Reproductibilité = imputabilité (on ne répond que de ce qu'on sait reconstruire) ; (7) À retenir. Source : skills/bootstrap-delivrabilite.

## S-V7 · Les bénéfices en graphiques
> Présentation pour l'encadrement et les architectes, un graphique par slide. Structure : (1) Titre ; (2) Validation — le modèle reproduit des coûts réels à moins de 1 % ; (3) La marche de scaling de l'infrastructure (graphique) ; (4) Le croisement coût/valeur cumulés ; (5) L'enveloppe de ROI selon trois scénarios + leurs creux de trésorerie ; (6) Le tornado de sensibilité — le support par utilisateur domine, les tokens IA sont négligeables ; (7) Le mur mémoire — il sature quand le schéma grossit dans le temps ; (8) À retenir — où porter le budget et l'attention. Source : Simulateur-Synthese.

## S-V8 · Adapter à votre service & calibrer les métriques
> Présentation pour l'équipe qui adopte la méthode, une idée par slide. Structure : (1) Titre ; (2) Du kit agnostique à votre instance ; (3) Choisir l'archétype (stateless/stateful, API-first/full-stack) et le tier ; (4) Remplir les priors « à caler » (stories, ratio de supervision, accumulation des données, empreintes) ; (5) Le point 0 — des fourchettes larges au départ ; (6) La boucle de calibration — la télémétrie réelle remplace le prior, story après story ; (7) Votre abaque calé sur votre stack ; (8) À retenir — le système apprend de votre terrain. Sources : skills/abaque-cout-capacite, personas/csi-engineer, personas/estimateur-capacite-cout.

---

# B — Decks miroir des DEEP DIVES (synthèse)

## S-DD1 · La grande synthèse — une seule idée
> Présentation de synthèse pour tout un service informatique, une idée par slide. Structure : (1) Titre — « Une seule idée » ; (2) Le fil unique — la boucle de rétroaction + le répondre-de ; (3) De la philosophie au coût — tout en découle ; (4) Le danger transversal — il traverse l'IA, le cloud, les logiciels achetés ; (5) La carte du dépôt en une slide (Manifeste, méthode, skills, personas, simulateur) ; (6) À retenir — un tout cohérent, pas un tas de parties. Sources : README, Manifeste-Foyer, Boucle-de-retroaction.

## S-DD2 · Une seule décision sous plusieurs surfaces
> Présentation pour architectes et décideurs, une idée par slide. Structure : (1) Titre ; (2) Les quatre axes côte à côte — IA souveraine/tierce, cloud/on-premise, propriétaire/open source, avec/sans support ; (3) Une seule grille de décision ; (4) Le veto altérité → réversibilité → érosion → coût (exemple concret) ; (5) L'IA n'est qu'un cas particulier d'une théorie générale de l'arbitrage ; (6) À retenir. Sources : skills/arbitrage-hybride, Manifeste-Foyer.

## S-DD3 · Du prior au mesuré — le système apprend de votre terrain
> Présentation pour l'équipe qui adopte la méthode, une idée par slide. Structure : (1) Titre ; (2) Agnostique au départ — des priors en fourchettes ; (3) Le point 0 devient du mesuré, story après story ; (4) Les acteurs — l'ingénieur CSI, l'estimateur, la story de délivrabilité ; (5) La méthode s'applique à elle-même — l'estimation est une boucle ; (6) À retenir — le cadre devient votre instrument. Sources : skills/abaque-cout-capacite, Simulateur-Synthese, personas/csi-engineer, personas/estimateur-capacite-cout.

---

*Decks en miroir de la série DSI, à utiliser avec le dépôt `gilmry/foyer`. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
