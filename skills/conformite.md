# Skill — Conformité réglementaire

*Skill **transversal** enfant de la primitive `../Boucle-de-retroaction.md`. L'outil qui **objective** ici n'est ni un test ni un état, mais la **correspondance entre un mécanisme Foyer et un contrôle exigé par un standard**. Il s'appuie sur `gates.md` (où les contrôles s'exécutent) et `enforcement.md` (où ils contraignent vraiment).*

> **Registre.** Ce skill **cartographie** (guidance) : il montre quels mécanismes Foyer répondent à quelles exigences, et **où les angles morts demeurent**. Il ne **certifie** rien et ne remplace ni une évaluation de conformité, ni un système de management documenté (ISO 42001 / 27001). Foyer fournit la **couche des contrôles** — pas le tampon. *« Assez conforme pour qu'on cesse de vérifier »* est le danger surveillé.

---

## 1. Principe — conforme par construction, pas par déclaration

Foyer n'est pas un cadre de conformité, c'est une **pratique d'ingénierie**. Mais le cœur que les standards exigent — **supervision humaine, secure-SDLC, traçabilité, enforcement architectural** — est précisément ce que la méthode opérationnalise au grain du craft quotidien. La conformité n'est donc pas un livrable ajouté à la fin : elle **tombe** des mécanismes déjà en place. Ce skill rend cette correspondance explicite et auditable.

## 2. Les trois cercles → mécanisme Foyer

### Mondial (standards volontaires, certifiables)

| Exigence | Mécanisme Foyer |
|---|---|
| **ISO/IEC 42001** (AIMS) · **NIST AI RMF** *Govern* — responsabilité, gouvernance IA | Le **répondre-de** (`../Manifeste-Foyer.md` §5), « génère / l'humain valide », ADR/RFC comme traces de gouvernance |
| **ISO/IEC 27001:2022** (SMSI, Annexe A) — accès, dépendances, secrets | **Security gate** : SAST, SCA, secrets, licences (`gates.md`) |
| **NIST SSDF** (SP 800-218) — secure-SDLC | Boucle de craft `cycle-dev.md` + gates en local **et** en CI (DRY) |
| **OWASP Top 10 LLM** — *excessive agency* (#6), supply chain (#3) | Anneau 1 permissions `deny`/`ask` + sandbox (`enforcement.md`) ; SCA/licences |
| **SLSA / SBOM** — provenance de la chaîne de build | **SBOM** ✓ au plancher de `gates.md` (CycloneDX, `../tools/gates/`) ; **provenance SLSA** ⚠️ **angle mort** — voir §5 |

### Européen (droit contraignant)

| Texte | Exigence clé | Mécanisme Foyer |
|---|---|---|
| **EU AI Act** (Rgt 2024/1689) | Supervision humaine (Art. 14), journalisation (Art. 12) | **Répondre-de** + registre **TRACE** (`enforcement.md`, `tool.execute.after`) |
| **NIS2** (Dir. 2022/2555) | Gestion des risques cyber, responsabilité direction | Security gate + 3 anneaux d'enforcement ; gate review par jalon |
| **Cyber Resilience Act** | *Security-by-design*, SBOM, gestion des vulnérabilités | Distroless (`convergence-iac.md`), SCA ✓, **SBOM** ✓ au plancher de `gates.md` ; **provenance + reporting** ⚠️ §5 |
| **RGPD** | Art. 22 — pas de décision *entièrement* automatisée | Le répondre-de **est** l'intervention humaine garantie |
| **DORA** | Résilience opérationnelle (finance) | Rollback, restauration testée (`convergence-iac.md`) |

### Belge (transposition)

| Référentiel | Mécanisme Foyer |
|---|---|
| **Loi NIS2 du 26 avril 2024** + AR · autorité **CCB** / CSIRT | Mesures de gestion des risques objectivées par la security gate ; **reporting d'incident** ⚠️ §5 |
| **CyberFundamentals (CyFun®) 2025** — construit sur le **NIST CSF 2.0**, niveaux cumulatifs Small/Basic/Important/Essential ; coexiste avec CyFun 2023 jusqu'au 18 avril 2027 | L'ancrage ISO 27001 de `gates.md` couvre l'ossature ; le niveau CyFun visé (défaut : §2bis) fixe le **seuil de l'exigence de jalon** |
| **APD / GBA** (RGPD) | cf. RGPD ci-dessus |

## 2bis. Niveau CyFun visé — partir de la menace

**Défaut : Essential** pour tout produit qui conserve des données de ses utilisateurs (`../pilote/defaults.md`). Ce n'est pas une obligation réglementaire : un porteur seul n'est en général pas soumis à NIS2. C'est un choix **par la menace**. Les attaques réalistes contre un produit riche en données (vol d'identifiants, abus de privilèges, rançongiciel, exfiltration, faille applicative) appellent des mesures qui n'existent qu'aux niveaux Important et Essential. S'arrêter à Basic, c'est se protéger de l'attaque opportuniste, pas de celle qui vise les données.

**Volume.** Le modèle est cumulatif : pour Essential, il faut satisfaire environ 230 exigences, dont 29 *key measures* (13 Basic, 9 Important, 7 Essential). Le seuil de maturité est de 3/5 pour chaque *key measure* et chaque catégorie, et de 2,5/5 au global.

**Trois couches, chacune portée une fois et héritée par chaque projet :**

| Couche | Porteur | Contenu |
|---|---|---|
| **Plateforme** | le déployeur (Sluis) | Sauvegardes immuables et testées, journaux hors hôte, séparation production / test, pare-feu, accès à privilèges |
| **Application** | **Foyer** (ce skill, `gates.md`, livrables BMAD) | Voir la table ci-dessous |
| **Organisation** | documents du porteur | Politiques, analyse de risque, plan de réponse aux incidents, fournisseurs, formation |

**Couche application — ce que Foyer doit garantir dans le produit.** ★ = *key measure*, B / I / E = niveau.

| Menace | Exigences CyFun 2025 | Mécanisme Foyer attendu |
|---|---|---|
| Vol d'identifiants | PR.AA-03.2 ★B, PR.AA-01.4 E, PR.AA-02.2 E | MFA dans l'application, identifiant unique par utilisateur et par processus |
| Abus de droits dans le produit | PR.AA-05.3 ★B, PR.AA-05.6 I | Moindre privilège dans le modèle d'autorisation, séparation des rôles métier |
| Faille applicative | ID.RA-08.1 ★I, PR.PS-06.3 E, ID.IM-03.9 E | Plan de gestion des vulnérabilités (dépendances, divulgation coordonnée), secure-SDLC (`cycle-dev.md` + `gates.md`), tests spécialisés |
| Exfiltration | ID.AM-03.3 ★E, PR.DS-02.2 E | Flux de données cartographiés dans le livrable Architecture, chiffrement en transit |
| Données au repos | PR.DS-01.x, GV.PO-01.2 I | Politique de chiffrement applicatif (secrets, champs sensibles) |

Les identifiants sont cités **sans le texte du CCB**, qui diffuse ses documents sous TLP:GREEN. Le texte des exigences se lit dans les livrets officiels (`cyfun.eu`).

**Ce que le niveau ne garantit pas.** Un mapping n'est pas une conformité (§4) : seule une autoévaluation documentée, avec une preuve par réponse, permet de dire « aligné », et seule une évaluation par un organisme accrédité permet de dire « conforme ». Pour un porteur seul, certaines exigences ne passent que par des mesures compensatoires ou des tiers : séparation des tâches (PR.AA-05.6), évaluation indépendante (ID.IM-03.7), audit des fournisseurs (GV.SC-07.3). Elles se **nomment**, elles ne se taisent pas.

## 2ter. Les gates comme producteurs de preuves

Le seuil de maturité 3/5 demande qu'une activité soit **appliquée et documentée**, avec une preuve par réponse de l'autoévaluation. Les gates de `gates.md` produisent déjà ces preuves à chaque build. Il manquait de dire à quelle exigence chacune répond.

| Rapport produit | Gate · registre | Format | Preuve pour |
|---|---|---|---|
| Nomenclature des dépendances | SBOM · plancher | CycloneDX | ID.AM-02.1 B, ID.AM-02.2 I (inventaire logiciel tenu à jour) |
| Scan de l'image | vulnérabilités conteneur · plancher | SARIF | ID.RA-01.1 B, ID.RA-01.2 I, ID.RA-01.6 I (vulnérabilités identifiées) |
| Analyse des dépendances | SCA · jalon | JSON de l'outil | ID.RA-01.1 B, ID.RA-01.6 I |
| Montées de version fusionnées après un avis | SCA · jalon (la PR, pas le rapport) | historique Git | ID.AM-08.2 ★B, PR.PS-02.1 I (correctifs installés, logiciel maintenu selon le risque) |
| Détection de secrets | secrets · plancher | SARIF | PR.AA-01.1 ★B (moyens d'authentification des services gérés, jamais dans le code) |
| Analyse statique | SAST · jalon | SARIF | PR.PS-06.1 I, PR.PS-06.3 E (sécurité intégrée au cycle de développement) |
| Gates verts avant fusion | chaîne complète | journal de CI | PR.PS-06.2 I (changements testés avant la production) |

**Trois règles pour qu'un rapport compte comme preuve.**

1. **Rattaché.** Un rapport nomme le commit, la date et la version de l'outil qui l'a produit. Sans ces trois éléments, il prouve qu'un outil a tourné un jour, pas que *ce* logiciel a été vérifié.
2. **Conservé au-delà de la CI.** Les artefacts de CI expirent (90 jours dans les gabarits de `../tools/gates/`), et une gate review peut venir plus tard. À chaque gate review, et à chaque version publiée pour le SBOM, les rapports sont **archivés** avec la version (pièces jointes de la release, ou dossier de preuves versionné) sous un manifeste : commit, date, outil et version, identifiants CyFun couverts.
3. **Un rapport rouge trié est aussi une preuve.** ID.RA-01 demande des vulnérabilités « identifiées, validées et enregistrées » : le finding plus sa décision de triage (issue, ADR, correctif) prouve davantage qu'un rapport vert, qui ne montre que l'absence de résultat d'un outil.

**Ce que les rapports ne prouvent pas.** Le **plan** de gestion des vulnérabilités (ID.RA-08.1 ★I) est un document, pas un rapport : ses scans n'en sont que l'exécution (story 5 de gilmry/foyer#11). Ni l'identification des menaces sur l'architecture (ID.RA-01.1 couvre aussi l'architecture réseau et système, que les scans de code ne voient pas), ni les tests de sécurité spécialisés (ID.IM-03.9 E). Une preuve partielle se déclare partielle dans l'autoévaluation.

## 3. Positionnement open-source (CRA)

Foyer dérive du Manifeste Maury (**CC BY-SA 4.0**) et n'est pas monétisé. Sous le **Cyber Resilience Act**, un tel logiciel relève vraisemblablement de l'**exemption** (OSS non commercial) ou du régime allégé **« open-source software steward »** — sans amendes administratives. *À confirmer projet par projet* : dès qu'un dérivé est **mis sur le marché dans le cadre d'une activité commerciale**, il bascule dans le champ plein du CRA (obligations §5 incluses). C'est un **point de bascule** au sens du répondre-de : à tracer explicitement.

## 4. Le registre, miroir des standards

Foyer distingue **guidance** (oriente) et **enforcement** (contraint) — exactement la distinction des standards entre **volontaire** (ISO, NIST, OWASP) et **contraignant** (AI Act, NIS2, CRA). La méthode l'assume au lieu de la confondre : un beau mapping de conformité **n'est pas** la conformité ; seul l'enforcement substrat (CI, protection de branche, sandbox — `enforcement.md` anneau 3) en **répond**.

## 5. Backlog des angles morts (stories habilitantes)

Trois écarts connus, à traiter comme des stories — pas à masquer :

1. **Provenance (SLSA)** — *angle mort réduit, pas fermé.* Le **SBOM est couvert** : il est passé au **plancher mécanique** de `gates.md` (génération CycloneDX bloquante à chaque build, implémentation dans `../tools/gates/`, choix d'outils justifié dans `../tools/gates/ADR-outillage.md`). Reste découverte l'**attestation de provenance** de la chaîne de build, elle aussi exigible sous CRA (obligations pleines déc. 2027). → *Story : attestation de provenance à la release.*
2. **Reporting d'incident / vulnérabilité** — l'obligation CRA (notification ENISA/CSIRT **sous 24 h**, dès sept. 2026) et NIS2 n'a **aucun mécanisme** dans Foyer. Terrain naturel : la production (`convergence-iac.md`, trigger AlertManager → platform engineer). → *Procédure de notification déclenchée par alerte.*
3. **Injection de prompt (OWASP LLM #1)** — les anneaux limitent l'*agency* de l'agent, pas l'injection via contenu. Pertinent uniquement si le **produit livré** embarque un LLM. → *Check dédié à `gates.md` pour l'archétype concerné.*

Tant qu'un écart n'est pas comblé, on le **nomme** — un angle mort tu, c'est *« assez fiable pour qu'on cesse de vérifier »*.

## 6. Coût

**Peu de tokens, wall-clock modéré** : la conformité s'objective par revue et exécution de gates, pas par génération. Le poste dominant reste le superviseur (qui *répond de* la correspondance). Le mapping se tient idéalement **en binôme** : la transmissibilité de la conformité est elle-même un anti-*bus factor 1* (cf. Manifeste, conviction 8).

---

*Registre guidance ; le blocage (gate, CI, protection de branche) est l'enforcement. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
