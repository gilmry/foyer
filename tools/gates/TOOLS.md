# Justification des choix d'outils — grille Foyer

Hiérarchie de veto (lexicographique, pas un score) : altérité → réversibilité
→ érosion → coût. Un outil n'est comparé sur le coût que s'il a passé les
trois filtres précédents. Voir `../../skills/arbitrage-hybride.md` §5 pour la
grille, et `ADR-outillage.md` pour la liste consolidée qui en résulte.

## Épinglage — pourquoi aucun tag mobile dans ces templates

Toutes les actions sont référencées par **SHA de commit**, avec le tag en
commentaire de lisibilité ; toutes les images par **version explicite**.
Aucun `@main`, aucun `:latest`.

Ce n'est pas du zèle : un tag mobile est un trou de réversibilité. Un
pipeline qui référence `@main` ne peut pas rejouer un build passé à
l'identique, et la nomenclature qu'il produit ne décrit pas ce qui a
réellement tourné — ce qui vide le gate SBOM de sa fonction. Un dossier dont
la doctrine repose sur la reproductibilité ne peut pas dépendre d'une
référence que quelqu'un d'autre peut redéfinir sans préavis.

**Une exception, assumée et unique** : `dtolnay/rust-toolchain@stable`. Chez
cette action, la ref n'est pas un numéro de version mais le *sélecteur de
toolchain* (`stable` / `beta` / `nightly`) — l'épingler par SHA ne
l'immobiliserait pas, ça lui ferait perdre son sens. L'exception est
commentée à chacune de ses occurrences dans `github/workflows/rust.yml.example`.

Corollaire d'entretien : des SHA épinglés se périment. Leur mise à jour
relève du cercle de réexamen décrit dans `ADR-outillage.md` — au même titre
que les quatre signaux d'érosion, et pas plus souvent.

## Secrets — Gitleaks (pre-commit) + TruffleHog (CI)

- **Gitleaks** : MIT, binaire Go unique, aucun appel réseau, fonctionne
  hors-ligne. Sortie SARIF native. Choix par défaut pour le poste de
  développeur — rapide (< 1s), ne fuite rien vers un tiers pour détecter un
  pattern.
- **TruffleHog** : AGPL-3.0. La clause réseau de l'AGPL ne s'applique pas ici
  — l'outil scanne, il n'est pas modifié puis republié comme service. Utilisé
  uniquement en CI, en mode `--results=verified`, pour confirmer qu'un secret
  détecté est réellement actif (appel à l'API du fournisseur du secret, pas à
  un tiers extérieur à la relation).
- **Écarté : GitGuardian.** SaaS propriétaire — le code ou ses empreintes
  transitent par un tiers commercial. Veto altérité. À reconsidérer
  uniquement si un besoin de dashboard de gouvernance à grande échelle
  apparaît, et alors comme complément, jamais comme gate bloquant.

## SBOM — générateurs CycloneDX par écosystème + Syft

Pas d'outil unique multi-langage mature à ce jour ; l'écosystème CycloneDX est
volontairement distribué par écosystème (cdxgen existe en alternative
multi-langage si un seul outil est préféré, avec analyse de reachability, mais
introduit une dépendance à un projet moins établi que les plugins officiels
par écosystème).

| Écosystème | Outil | Licence |
|---|---|---|
| Next.js / npm | `@cyclonedx/cyclonedx-npm` | Apache-2.0 |
| Java / Maven | `cyclonedx-maven-plugin` | Apache-2.0 |
| Python | `cyclonedx-bom` (cyclonedx-py) | Apache-2.0 |
| Image Docker | Syft (Anchore) → format CycloneDX | Apache-2.0 |

Tous produisent du CycloneDX 1.6+, réversible par construction : format
ouvert, consommable par n'importe quel agrégateur, y compris
Dependency-Track (voir annexe « Agrégateur » en fin de document).

## Vulnérabilités conteneur — Trivy en gate, Docker Scout en option non bloquante

- **Trivy** (Aqua Security, Apache-2.0) : fonctionne hors-ligne après
  téléchargement de la base, ne nécessite aucune authentification, couvre
  image, filesystem, IaC, secrets et licences en un seul binaire. Choisi comme
  **gate bloquant** parce qu'il ne dépend d'aucun compte tiers pour
  fonctionner — altérité et réversibilité au maximum.
- **Docker Scout** : outil propriétaire de Docker Inc., nécessite une
  connectivité API et une authentification pour l'usage complet. Base de
  vulnérabilités différente de Trivy — capte parfois des CVE que Trivy rate
  (ex. CVE applicatives sur l'interpréteur Python) et inversement. **Recommandé
  en usage complémentaire, jamais en gate unique** : dépendance à un compte
  et une plateforme d'un éditeur unique (risque d'érosion), et échange avec
  un service tiers à documenter si des images contiennent du code non public.
- Pratique recommandée : faire tourner les deux en CI, Trivy bloquant,
  Docker Scout en rapport informatif — deux bases de données différentes
  couvrent plus qu'une seule.
- Les deux vivent dans des workflows séparés : Trivy dans
  `gate-container.yml` (bloquant), Docker Scout dans
  `guidance-docker-scout.yml` (manuel). Un job sauté dans le workflow d'une
  gate compterait rouge pour Sluis, qui lit tous les check-runs
  `sluis/scan-conteneur / …`.

## SAST — Opengrep plutôt que Semgrep CE

Semgrep a restreint en décembre 2024 la licence de ses règles proposées à la
communauté (Semgrep Rules License) tout en gardant le moteur en LGPL — un cas
concret d'érosion au sens Foyer. Opengrep, fork gouverné par un consortium de
plus de dix éditeurs, restaure les fonctionnalités retirées de la Community
Edition, reste compatible avec le format de règles Semgrep et produit du
SARIF nativement — aucune réécriture de pipeline nécessaire pour migrer.

Limite honnête à documenter : la couverture Java/Spring d'Opengrep est bonne
sur les patterns OWASP standards, mais n'atteint pas la profondeur d'analyse
inter-framework des règles Pro propriétaires de Semgrep. Complété ici par
SpotBugs (LGPL) pour les défauts structurels Java, sans dépendre d'un éditeur
unique.

## SBOM — Rust

`cargo-cyclonedx` (projet OWASP CycloneDX, Apache-2.0) source à la fois
`Cargo.lock` et `cargo metadata`, ce qui permet de produire un SBOM par
crate ou par binaire et de respecter la combinaison de features activée à
la compilation — un simple parseur de lockfile ne le permet pas. Retenu
plutôt que `cargo-sbom` (moins établi) ou `cargo-auditable` (embarque les
dépendances dans le binaire compilé — complémentaire, pas substituable,
utile en particulier pour du code embarqué où le binaire circule sans son
dépôt source).

**cargo-audit vs Trivy pour Rust** : la couverture de l'écosystème Cargo
par Trivy est plus tardive que celle de RustSec, la base spécifique à
l'écosystème Rust sur laquelle s'appuie `cargo-audit`. D'où le maintien de
`cargo-audit` en guidance complémentaire au gate conteneur Trivy, plutôt
qu'un remplacement.

## Migrations PostgreSQL — vérification de réversibilité plutôt qu'un outil de migration imposé

Aucun outil de migration n'est imposé (node-pg-migrate, sqlx, diesel,
Flyway, Sqitch — au choix de l'équipe), en cohérence avec le principe de
ne jamais imposer d'outil au-delà du contrat de gate. Le gate porte sur une
convention de nommage (`*.up.sql` / `*.down.sql`) transposable à la
plupart de ces outils, pas sur un outil particulier.

Ce gate a un statut particulier dans ce dossier : c'est le seul qui ne
protège pas un artefact logiciel (secret, dépendance, image) mais un état
de base de données. Il est néanmoins bloquant parce qu'il satisfait
exactement le même critère que les trois gates de code — objectivable
(le fichier existe ou non) et irréversible (une migration sans retour,
jouée en production, ne se défait pas). Le dry-run réel sur instance
éphémère (`sqlfluff`, application effective up/down) reste en guidance :
un échec y est coûteux à corriger avant merge, mais rien n'est perdu si on
ne bloque pas dessus — à la différence de l'absence du fichier de retour
lui-même.

## SBOM — PHP (Symfony, Drupal)

`cyclonedx/cyclonedx-php-composer` (Apache-2.0), plugin Composer officiel du
projet CycloneDX. Fonctionne identiquement pour Symfony et Drupal puisque
les deux s'appuient sur Composer — seule la couche de guidance diffère
(standard de code, vérification de dépréciation).

**composer audit vs Symfony Security Checker** : `composer audit` est natif
depuis Composer 2.4, s'appuie sur FriendsOfPHP/security-advisories, et
retourne un code de sortie non nul en cas de vulnérabilité — l'ancien
Symfony Security Checker (dépendant d'un service tiers désormais retiré) et
`local-php-security-checker` sont obsolètes. Retenu en guidance et non en
gate, pour la même raison que `cargo-audit` : une dépendance listée n'est
pas nécessairement atteinte par le code exécuté.

**Cas Drupal** : le standard de code officiel (`drupal/coder`, GPL-2.0,
paquet Composer maintenu par la Drupal Association) et `drupal-check`
(dépréciations d'API core/contrib) sont ajoutés en guidance additionnelle,
actifs uniquement si `composer.json` référence `drupal/core` — un projet
Symfony pur ne déclenche pas ces jobs.

## PowerShell — un stack sans écosystème SBOM établi, à documenter honnêtement

Aucun générateur CycloneDX dédié au PowerShell Gallery n'est aujourd'hui
suffisamment mature ou adopté pour être recommandé comme gate — à la
différence de npm, Maven, pip, Cargo, Composer ou NuGet. Plutôt que de
produire un SBOM de façade (un fichier techniquement présent mais sans
valeur informative), ce dossier :

- traite le gate SBOM et le gate conteneur comme **conditionnels à la
  présence d'un `Dockerfile`** dans le dépôt — beaucoup de dépôts
  PowerShell (scripts d'administration, modules exécutés directement sur
  un hôte) n'en ont pas, et le sujet ne se pose alors pas ;
- retient **PSScriptAnalyzer** (Microsoft, MIT) comme guidance principale
  — c'est l'analyseur statique officiel de l'écosystème, et plusieurs de
  ses règles (`PSAvoidUsingConvertToSecureStringWithPlainText`,
  `PSAvoidUsingPlainTextForPassword`, `PSAvoidUsingInvokeExpression`)
  couvrent des patterns de sécurité directement pertinents.

Point ouvert, à trancher en atelier si le volume de scripts PowerShell le
justifie : documenter manuellement les modules requis (`RequiredModules`
d'un fichier `.psd1`) comme inventaire minimal, à défaut d'outillage
automatisé.

## SBOM — C# / .NET

`dotnet-CycloneDX` (outil global .NET, projet CycloneDX, NuGet), officiel
et maintenu par la même organisation OWASP CycloneDX que les générateurs
npm/Maven/Python déjà retenus.

**`dotnet list package --vulnerable`** est une commande native du SDK
.NET (depuis 5.0.200), sans installation supplémentaire, appuyée sur la
GitHub Advisory Database. Limite documentée de l'outil : elle ne retourne
pas de code de sortie non nul en cas de vulnérabilité trouvée — elle
liste, elle ne bloque pas par elle-même. Ce dossier la garde donc en
guidance pure (rapport informatif), cohérent avec le traitement des autres
audits de dépendances (cargo-audit, composer audit), plutôt que
d'ajouter une logique de parsing fragile pour forcer un comportement
bloquant que l'outil n'a pas été conçu pour offrir nativement.

## Agrégation — DefectDojo + Dependency-Track

C'est le seul choix de cette liste qui mérite une analyse de veto complète
avant sélection définitive : voir l'annexe dédiée en fin de document —
c'est le seul système de référence irréversible parmi tous les outils
listés ici.

## Provenance IA {#ia}

Aucun outil de pipeline générique ne peut aujourd'hui vérifier
automatiquement qu'un système d'IA respecte une dérogation article 6§3 ou
n'effectue pas de profilage — c'est un jugement sur la finalité et l'accès
aux données, pas un fait détectable dans un diff. La gate correspondante est
donc une checklist de mise en service, pas un job CI.

**Elle relève donc du registre « exigence de jalon », pas du plancher
mécanique** (cf. `../../skills/gates.md`). Le point mérite d'être dit
explicitement, parce que l'irréversibilité de la provenance IA est réelle —
une inférence passée ne se journalise pas rétroactivement — et pousse
naturellement à vouloir la faire bloquer. Mais le plancher exige *deux*
propriétés, pas une : irréversible **et** objectivable. Celle-ci échoue sur
la seconde. Un gate qui prétendrait la vérifier ne contrôlerait qu'un
substitut (la présence d'un fichier, d'un label), et le substitut passerait
au vert pendant que l'exigence resterait non tenue — ce qui est pire que
l'absence de gate, puisque ça produit une assurance fausse.

Contenu de la checklist :

- version de modèle et endpoint appelé consignés dans la configuration versionnée ;
- juridiction d'hébergement du modèle documentée ;
- accès au journal d'interactions restreint et sa finalité déclarée par écrit ;
- évaluation art. 6§3 documentée si la fonction touche l'annexe III.

À intégrer comme point de contrôle en revue de code / merge request pour
toute PR touchant un chemin `**/ai/**` ou `**/llm/**` — un exemple de
configuration de label obligatoire est fourni dans `github/workflows/` et
`gitlab/`.

---

## Annexe — l'agrégateur, pourquoi c'est le seul choix qui mérite un atelier dédié

Tous les autres outils de ce document sont substituables sans dommage :
leur contrat de sortie (SARIF, CycloneDX) garantit qu'un remplacement ne
coûte qu'une ligne de configuration. L'agrégateur ne partage pas cette
propriété — c'est structurel, pas un défaut d'implémentation.

### Pourquoi l'agrégateur casse la réversibilité par défaut

Un agrégateur (DefectDojo, Dependency-Track, ou tout ASPM commercial)
accumule trois choses qu'aucun format d'échange standard ne capture
entièrement :

1. **L'historique de triage** — chaque finding marqué faux positif,
   accepté comme risque, ou lié à un ticket porte un raisonnement humain.
   CycloneDX et SARIF décrivent l'état d'un scan, pas la décision prise
   dessus.
2. **La déduplication apprise** — un agrégateur mature fusionne les
   doublons entre scanners différents (le même CVE remonté par Trivy et
   par un SCA applicatif) selon des règles qui s'affinent avec l'usage.
   Ce savoir ne s'exporte pas proprement.
3. **Le graphe produit ↔ composant ↔ vulnérabilité** dans le temps —
   la valeur d'un ASPM est cumulative, pas instantanée.

Changer d'agrégateur après plusieurs mois d'usage ne se fait donc pas en
remplaçant une ligne de pipeline : ça se fait en acceptant de perdre
l'historique de triage, ou en migrant les données à la main. C'est
exactement la définition Foyer d'un choix irréversible — d'où le veto
complet, quand tous les autres outils de ce document en sont dispensés.

### La grille appliquée à l'agrégateur lui-même

| Axe | Question posée | Ce qu'elle élimine |
|---|---|---|
| **Altérité** | Les findings (souvent liés à du code propriétaire) transitent-ils vers un tiers ? | Tout SaaS d'agrégation hébergé par l'éditeur — sauf si le code scanné est déjà public. |
| **Réversibilité** | Les données peuvent-elles être exportées dans un format réutilisable ailleurs ? | Les plateformes qui ne proposent qu'un export propriétaire ou une API fermée. |
| **Érosion** | Qui peut, seul, changer les conditions d'accès demain ? | Un éditeur unique à capital-risque, sans gouvernance partagée. |
| **Coût** | Seulement une fois les trois filtres précédents passés. | — |

### Pourquoi DefectDojo et Dependency-Track passent les trois premiers filtres

- **DefectDojo** — licence BSD-3-Clause, projet phare de l'OWASP (pas un
  projet personnel ni une startup), auto-hébergeable, agrège plus de 200
  formats de scanners en entrée. Le code source complet reste sous
  contrôle de qui l'héberge : pas d'altérité si déployé en interne.
- **Dependency-Track** — également OWASP, spécialisé SBOM/VEX plutôt que
  findings génériques, consomme nativement le CycloneDX déjà produit par
  tous les gates de ce document. Auto-hébergeable de la même façon.

Aucun des deux n'est présenté ici comme *le* choix — seulement comme les
candidats qui survivent aux trois premiers filtres, ce qui justifie de
leur consacrer l'atelier de sélection que les autres outils n'ont pas
besoin de recevoir. Le choix définitif (lequel des deux, ou les deux en
tandem — DefectDojo pour les findings de code, Dependency-Track pour la
supply chain) reste une décision à documenter séparément, avec les
personnes qui en répondront une fois déployé.

### Ce que ça change concrètement dans l'usage des gates

Tant que l'agrégateur n'est pas choisi, chaque rapport produit par les
gates de ce document (SARIF, CycloneDX) reste un artefact CI isolé,
consultable mais non centralisé. Ce n'est pas bloquant pour démarrer —
les gates fonctionnent et protègent dès leur activation, indépendamment
de l'agrégation. C'est seulement la vision transversale (« quel produit
est le plus exposé, cette semaine, tous scanners confondus ») qui manque
tant que ce choix n'est pas tranché.
