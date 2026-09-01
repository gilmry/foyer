# ADR — Outillage DevSecOps : la liste consolidée

*Décision d'outillage tenue au grain méthode. Applique la hiérarchie de veto de `../../skills/arbitrage-hybride.md` §5 au terrain DevSecOps. Le registre (ce qui bloque vs ce qui remonte au jugement) est fixé par `../../skills/gates.md`.*

**Statut** — retenu, sauf l'agrégateur (§5, atelier dédié à tenir).

---

## Contexte

Un projet qui met en place ses gates fait, sans toujours s'en rendre compte, une trentaine de choix d'outils. Chacun engage une licence, une gouvernance, une dépendance réseau, parfois un compte chez un tiers. Pris un par un, ils ont l'air anodins ; pris ensemble, ils dessinent la surface de dépendance réelle de la fabrication.

Le réflexe habituel est de choisir par notoriété ou par confort d'intégration. La grille Foyer impose l'ordre inverse : **altérité → réversibilité → érosion → coût**, tranché dans cet ordre, un étage ne se rachetant jamais par le suivant. Cet ADR applique cette grille, outil par outil, et consolide le résultat en une liste unique qu'on peut mettre en place.

Il existe une raison supplémentaire de l'écrire : un choix d'outil **se périme**. L'érosion est le seul des quatre axes qui dépende du temps — un outil qui passait le veto l'an dernier peut le manquer aujourd'hui sans que rien dans le code n'ait bougé. Une liste d'outils non révisée est une photo qui vieillit. D'où le cercle de réexamen en §6, qui fait partie de la décision et pas de son commentaire.

---

## Décision

### 1. Ce qui est imposé, c'est le format — jamais l'outil

C'est le seul engagement de fond de cet ADR ; tout le reste en découle.

| Objet | Format imposé |
|---|---|
| Findings (SAST, lint, scanners) | **SARIF** |
| Nomenclature logicielle | **CycloneDX 1.6+** |

Deux raisons, elles aussi lexicographiquement ordonnées :

1. **Réversibilité** — un outil qui exporte un format ouvert reste substituable sans réécrire le pipeline. Le veto porte alors sur une ligne de configuration, pas sur une migration.
2. **Autonomie du grain** — imposer un outil à une équipe qui n'en répond pas revient à découpler le choix de qui en assume les conséquences. Cet ADR fixe le plancher ; chaque grain (voir `../../personas/`) choisit l'outil qui le remplit.

**Cette règle a été testée une fois, en vrai.** En décembre 2024, Semgrep a restreint la licence des règles proposées à la communauté tout en gardant le moteur en LGPL — une érosion au sens strict. Opengrep, fork gouverné par un consortium de plus de dix éditeurs, a restauré les fonctionnalités retirées en restant compatible avec le format de règles Semgrep et en produisant du SARIF nativement. **La substitution s'est faite sans modification des jobs CI**, précisément parce que le contrat portait sur le format de sortie et non sur le produit. Ce n'est donc pas un principe de précaution : c'est une règle qui a déjà encaissé un incident réel, à coût nul. Elle vaut d'être maintenue pour cette raison-là.

### 2. La liste consolidée

Colonne « registre » au sens de `gates.md` : **plancher** = la CI bloque, sans exception ; **jalon** = produit un rapport, l'humain tranche en gate review.

| Gate | Outil retenu | Licence | Registre | Ce qui l'a fait passer |
|---|---|---|---|---|
| Secrets — poste | **Gitleaks** | MIT | plancher | Binaire unique, **aucun appel réseau**, hors-ligne, < 1 s, SARIF natif. Rien ne sort du poste pour détecter un motif. |
| Secrets — CI vérifié | **TruffleHog** `--results=verified` | AGPL-3.0 | plancher | Confirme qu'un secret détecté est réellement actif. Clause réseau AGPL sans effet ici : l'outil scanne, il n'est pas modifié puis republié comme service. |
| Vulnérabilités conteneur | **Trivy** | Apache-2.0 | plancher | Hors-ligne après téléchargement de la base, **aucune authentification**, couvre image + fs + IaC + secrets + licences en un binaire. Ne dépend d'aucun compte tiers. |
| SBOM — npm | `@cyclonedx/cyclonedx-npm` | Apache-2.0 | plancher | Générateur officiel de l'écosystème CycloneDX. |
| SBOM — Maven | `cyclonedx-maven-plugin` | Apache-2.0 | plancher | Idem ; `makeAggregateBom` pour le multi-modules. |
| SBOM — Python | `cyclonedx-bom` (`cyclonedx-py`) | Apache-2.0 | plancher | Idem. |
| SBOM — Rust | `cargo-cyclonedx` | Apache-2.0 | plancher | Source `Cargo.lock` **et** `cargo metadata` : respecte la combinaison de features activée à la compilation, ce qu'un simple parseur de lockfile ne permet pas. |
| SBOM — PHP | `cyclonedx-php-composer` | Apache-2.0 | plancher | Plugin Composer officiel ; identique Symfony et Drupal. |
| SBOM — .NET | `dotnet-CycloneDX` | Apache-2.0 | plancher | Même organisation OWASP CycloneDX que les précédents. |
| SBOM — image | **Syft** → CycloneDX | Apache-2.0 | plancher | Complète les SBOM applicatifs par la couche système de l'image. |
| Migrations PostgreSQL | *aucun outil* — convention `*.up.sql` / `*.down.sql` | — | plancher | Voir §4. Le gate porte sur une convention transposable, pas sur un outil de migration. |
| SAST | **Opengrep** | LGPL | jalon | Fork sous gouvernance de consortium, compatible format de règles Semgrep, SARIF natif. |
| SAST — complément Java | **SpotBugs** | LGPL | jalon | Défauts structurels que la couverture Java d'Opengrep n'atteint pas (voir §5, limite documentée). |
| SCA — Rust | `cargo-audit` | — | jalon | S'appuie sur RustSec, dont la couverture Cargo est plus précoce que celle de Trivy. Complément, pas substitut. |
| SCA — PHP | `composer audit` | — | jalon | Natif depuis Composer 2.4, base FriendsOfPHP, code de sortie non nul. |
| SCA — .NET | `dotnet list package --vulnerable` | — | jalon | Natif au SDK (≥ 5.0.200), GitHub Advisory Database. **Ne retourne pas de code de sortie non nul** — ne peut pas bloquer nativement, et on n'ajoutera pas de parsing fragile pour le lui faire faire. |
| Lint / format | clippy · ruff · ESLint · **PSScriptAnalyzer** (MIT) · `drupal/coder` (GPL-2.0) | — | jalon | Analyseurs officiels de chaque écosystème. PSScriptAnalyzer porte plusieurs règles directement sécuritaires (`PSAvoidUsingPlainTextForPassword`, `PSAvoidUsingInvokeExpression`). `drupal/coder` et `drupal-check` conditionnés à la présence de `drupal/core`. |
| Refactor PHP (migration de code pur) | **Rector** | MIT | jalon | Règles déclaratives (upgrade de version PHP, patterns) appliquées **sous le vert** des tests : la mécanique (rename, signature, dépréciations) est à l'outil ; la sémantique métier reste à l'agent + aux tests. Produit un diff, jamais un build cassé — l'humain valide en revue (`migration-projet-existant.md` phase 2). |
| Migrations — dry-run | `sqlfluff` + application up/down sur instance éphémère | — | jalon | Un échec est coûteux à corriger avant merge, mais rien n'est perdu si on ne bloque pas dessus. |
| Vulns conteneur — 2ᵉ base | **Docker Scout** | propriétaire | jalon, **jamais seul** | Base de vulnérabilités différente de Trivy : capte des CVE que Trivy rate, et inversement. Deux bases couvrent plus qu'une. Retenu en rapport informatif uniquement — voir §5. |
| Provenance IA | *aucun outil possible* — checklist de mise en service | — | jalon | Voir §4. |
| Agrégation | **non tranché** — DefectDojo / Dependency-Track | BSD-3 / Apache | atelier dédié | Voir §5 et l'annexe de `TOOLS.md`. |

Le détail par écosystème, avec les arbitrages fins, reste dans **`TOOLS.md`** — cet ADR consolide, il ne remplace pas.

### 3. Le coût n'a tranché aucune de ces lignes

C'est le contrôle qui valide que la grille a bien été appliquée dans l'ordre. Aucun outil de cette liste n'a été retenu ni écarté sur un motif de coût : les décisions se sont toutes jouées sur les trois axes supérieurs, et pour la plupart sur les deux premiers. Là où le coût aurait pu peser — un SaaS d'agrégation clé en main contre un DefectDojo à héberger soi-même — l'altérité tranche avant qu'on ait à l'examiner.

Formulé autrement : *un outil propriétaire moins cher qui expose le code à un tiers perd sur l'altérité, et son prix n'est même pas regardé* (`arbitrage-hybride.md` §43).

---

## Ce que cette liste ne prétend pas être

À lire avant la section suivante : sans cette mise au point, « écarté » se lit comme un verdict de qualité, ce qu'il n'est pas.

**Un plancher, pas un palmarès.** Cette liste ne désigne pas les meilleurs outils du marché. Elle désigne ceux qui remplissent le contrat *sans enfermer*. Ce sont deux questions distinctes, et seule la seconde est tranchée ici. Plusieurs outils écartés sont objectivement plus aboutis que ceux retenus — les règles Pro de Semgrep vont plus loin qu'Opengrep sur Java, c'est documenté plus haut. Ce coût est accepté en connaissance de cause, il n'est pas ignoré.

**Le critère n'est pas le camp, c'est la porte de sortie.** Rien ici ne pose « open source bien, propriétaire mal ». Aucun pôle n'est bon en soi (`../../skills/arbitrage-hybride.md` §1) : ce qui qualifie un choix, c'est la **sortie possible**. Un OSS auto-hébergé qu'une équipe ne sait pas exploiter est moins réversible qu'une solution commerciale dont elle maîtrise l'export. La grille ne défend pas une famille de licences, elle défend une **capacité** — celle de partir. C'est structurel, pas tribal.

Ce n'est pas pour autant neutre : l'altérité prime sur tout, et c'est un choix assumé. Ce qui est refusé, ce n'est pas un camp — c'est l'exposition non examinée.

**Choisir une solution commerciale reste recevable.** La distinction qui décide n'est pas propriétaire / libre mais **subi / assumé** (`arbitrage-hybride.md` §4). Une dépendance héritée sans avoir été examinée se fait remonter. Une dépendance choisie, tracée, dont le prix de sortie est connu, est pleinement imputable — et c'est tout ce qui est exigé. Le choix d'exposition est toujours imputable ; ce qui ne l'est pas, c'est un choix qui n'a jamais été posé comme un choix.

**Le budget départage, il ne rachète pas.** Si un projet a les moyens d'un outil plus abouti, rien ne s'y oppose : le coût est bien un critère de la grille. Mais il vient en dernier, et un étage ne se rachète jamais par le suivant. Le budget tranche entre des options qui ont passé les filtres supérieurs ; il ne les leur fait pas passer. Un outil moins cher qui expose des données à un tiers non consentant perd sur l'altérité — et un outil plus cher qui les expose aussi perd exactement de la même façon.

**Ce que ce socle produit, même sans être optimal.** Sa valeur n'est pas d'être le meilleur outillage possible, mais de rendre l'écosystème **lisible** : chaque équipe sait ce qu'elle bloque, pourquoi, ce qu'elle expose, et ce que coûterait d'en changer. Cette maturité se gagne au moment où le plancher est posé, pas au moment où l'outil parfait est trouvé — et elle reste acquise, quel que soit l'outil qu'on décide ensuite de mettre par-dessus.

---

## Alternatives écartées

| Écarté | Axe qui tranche | Motif |
|---|---|---|
| **GitGuardian** | **altérité** | SaaS propriétaire : le code ou ses empreintes transitent par un tiers commercial. À reconsidérer seulement comme complément de gouvernance à grande échelle, **jamais comme gate bloquant**. |
| **Semgrep CE** | **érosion** | Restriction de la licence des règles communautaires en décembre 2024, moteur maintenu en LGPL. Cas d'école : l'outil n'a pas cessé de fonctionner, ses conditions d'accès ont changé. |
| **Docker Scout comme gate unique** | **érosion** | Dépendance à un compte et à la plateforme d'un éditeur unique. Conservé en complément non bloquant, où cette dépendance ne conditionne pas la capacité à livrer. |
| **Symfony Security Checker**, `local-php-security-checker` | **érosion** | Dépendaient d'un service tiers désormais retiré. Obsolètes, remplacés par `composer audit`. |
| `cargo-sbom` | maturité *(après les 3 filtres)* | Passe les trois premiers axes ; moins établi que `cargo-cyclonedx`. |
| `cdxgen` | maturité *(après les 3 filtres)* | Alternative multi-langage crédible, avec analyse de *reachability*, mais dépendance à un projet moins établi que les plugins officiels par écosystème. Réexaminable. |
| `cargo-auditable` | *sans objet* | Non substituable : embarque les dépendances dans le binaire compilé. Complémentaire, utile quand le binaire circule sans son dépôt source. |

---

## Ce que la liste ne couvre pas

Une liste qui prétend tout couvrir n'est pas défendable. Trois trous, assumés et nommés :

**SBOM PowerShell.** Aucun générateur CycloneDX dédié à la PowerShell Gallery n'est aujourd'hui assez mature ou adopté — contrairement à npm, Maven, pip, Cargo, Composer et NuGet. Produire un SBOM de façade (fichier techniquement présent, informativement vide) serait pire que de ne rien produire : ça éteindrait le signal. Les gates SBOM et conteneur sont donc **conditionnés à la présence d'un `Dockerfile`** ; beaucoup de dépôts PowerShell (scripts d'administration exécutés sur un hôte) n'en ont pas, et la question ne se pose alors pas. Point ouvert : documenter les `RequiredModules` d'un `.psd1` comme inventaire minimal, si le volume le justifie.

**Provenance IA.** Aucun outil de pipeline ne peut vérifier automatiquement qu'un système respecte une dérogation art. 6§3 de l'AI Act ou n'effectue pas de profilage — c'est un jugement sur la finalité et sur l'accès aux données, pas un fait détectable dans un diff. La gate est donc une **checklist de mise en service**, pas un job CI : version de modèle et endpoint consignés dans la configuration versionnée · juridiction d'hébergement documentée · accès au journal d'interactions restreint et finalité déclarée par écrit · évaluation art. 6§3 documentée si la fonction touche l'annexe III. À porter comme point de contrôle en revue de merge request sur tout chemin `**/ai/**` ou `**/llm/**`.

**Provenance SLSA.** Le SBOM est couvert, l'attestation de provenance ne l'est pas. Reste un angle mort de `../../skills/conformite.md` §5, exigible sous CRA (obligations pleines décembre 2027).

**Limite documentée d'Opengrep.** Sa couverture Java/Spring est bonne sur les patterns OWASP standards mais n'atteint pas la profondeur d'analyse inter-framework des règles Pro propriétaires de Semgrep. C'est le prix payé pour ne pas dépendre d'un éditeur unique ; il est compensé — partiellement, pas intégralement — par SpotBugs.

---

## L'agrégateur — le seul choix laissé ouvert, et pourquoi

Tous les autres outils de cette liste sont substituables sans dommage : leur contrat de sortie (SARIF, CycloneDX) garantit qu'un remplacement ne coûte qu'une ligne de configuration. **L'agrégateur ne partage pas cette propriété, et c'est structurel.**

Il accumule trois choses qu'aucun format d'échange ne capture :

1. **L'historique de triage** — chaque finding marqué faux positif, accepté comme risque ou lié à un ticket porte un raisonnement humain. CycloneDX et SARIF décrivent l'état d'un scan, pas la décision prise dessus.
2. **La déduplication apprise** — la fusion des doublons entre scanners différents (le même CVE remonté par Trivy et par un SCA applicatif) suit des règles qui s'affinent avec l'usage. Ce savoir ne s'exporte pas proprement.
3. **Le graphe produit ↔ composant ↔ vulnérabilité dans le temps** — la valeur d'un agrégateur est cumulative, pas instantanée.

Changer d'agrégateur après plusieurs mois ne se fait donc pas en remplaçant une ligne de pipeline : ça se fait en acceptant de perdre l'historique de triage, ou en migrant à la main. **C'est la définition Foyer d'un choix irréversible** — d'où le veto complet, quand tous les autres outils de cette liste en sont dispensés, et d'où l'atelier de sélection que les autres ne méritent pas.

**DefectDojo** (BSD-3-Clause, projet phare OWASP, auto-hébergeable, plus de 200 formats de scanners en entrée) et **Dependency-Track** (OWASP également, spécialisé SBOM/VEX, consomme nativement le CycloneDX déjà produit par tous les gates de cette liste) passent tous deux les trois premiers filtres. Aucun n'est présenté ici comme *le* choix : seulement comme les deux candidats survivants, ce qui justifie l'atelier. Le choix définitif — l'un, l'autre, ou les deux en tandem (DefectDojo pour les findings de code, Dependency-Track pour la supply chain) — se documente séparément, **avec les personnes qui en répondront une fois déployé**.

Tant qu'il n'est pas tranché, chaque rapport produit reste un artefact CI isolé : consultable, non centralisé. **Ce n'est pas bloquant pour démarrer** — les gates protègent dès leur activation, indépendamment de l'agrégation. Seule la vision transversale (« quel produit est le plus exposé cette semaine, tous scanners confondus ») manque.

---

## Le cercle de réexamen

Cette liste est un artefact comme un autre : elle tourne sur la primitive (`../../Boucle-de-retroaction.md`), sans quoi elle devient la dette textuelle que personne ne maintient.

- **Conception** — le critère est posé d'avance : la grille de veto. Falsifiable : un outil qui échoue à un axe sort, quel que soit son confort d'usage ou le temps déjà investi dedans.
- **Construction** — mise en place dans un projet consommateur (voir §Mise en place).
- **Résultat** — les gates tournent et produisent du SARIF / CycloneDX.
- **Évaluation** — *l'outil qui objective la liste, c'est la veille sur ses quatre signaux d'érosion.* Ils sont objectivables, pas affaire de ressenti :
  1. **changement de licence ou des conditions d'accès** — le signal Semgrep, celui qui a déjà déclenché une substitution ;
  2. **changement de gouvernance** — rachat, passage d'un consortium à un éditeur unique, changement de modèle économique ;
  3. **abandon** — date du dernier commit, réactivité aux CVE, réponse aux issues de sécurité ;
  4. **le format de sortie cesse d'être standard ou complet** — c'est le plus grave : c'est le contrat de réversibilité lui-même qui lâche.
- **Amélioration** — réexamen du veto sur l'outil concerné, substitution si l'axe est manqué, mise à jour de cet ADR.

**Cadence.** Rattachée à la méta-boucle ADR/ADM tenue par l'architecte solution, dont le rythme suit celui des gate reviews du barreau déployé (`Boucle-de-retroaction.md` §La méta-boucle). Aucune échéance calendaire n'est inventée ici : le dispositif a déjà son horloge, on s'y branche. S'y ajoute un déclenchement **événementiel** dès qu'un des quatre signaux se produit — l'érosion n'attend pas la prochaine revue.

**Condition de sortie.** Cette liste ne se referme pas ; ce qui se referme, c'est le réexamen d'un outil donné. Une substitution au **plancher** change ce qui bloque la fabrication → point qui engage → **l'humain valide**.

**Angle mort surveillé.** *« Assez fiable pour qu'on cesse de vérifier »* vise ici deux cibles précises : le SBOM et la provenance IA. Ce sont les gates qu'on est tenté de couper après plusieurs cycles sans rien trouver — et c'est exactement le moment où l'information qu'ils capturent redevient irremplaçable si on les coupe.

---

## Mise en place — une story habilitante

Sans outil pour objectiver, pas d'Évaluation, donc pas de cercle : **mettre en place ces gates est une story**, et elle précède celles qui en dépendent (`Boucle-de-retroaction.md` §Corollaire ; forme aboutie dans `../../skills/bootstrap-delivrabilite.md`). Ordre à respecter :

1. **Le plancher d'abord** — secrets, puis SBOM, puis conteneur. C'est ce qui capture de l'information irrécupérable : un secret poussé est fuité et la rotation ne défait pas la fuite ; l'arbre de dépendances d'un build passé ne se reconstitue pas après coup. Chaque jour sans ces trois gates est une perte sèche, pas un report.
2. **Le registre jalon ensuite** — SAST, lint, SCA, couverture, en rapport, sans blocage. Utile immédiatement, mais rien n'y est perdu pendant qu'on attend.
3. **L'agrégateur en dernier** — et seulement après l'atelier de sélection.

Les templates de `github/`, `gitlab/` et `workstation/` sont des **exemples dont on s'inspire**, à réinstancier selon les stacks réelles du projet — pas un livrable à copier tel quel.

---

## Conséquences

**Ce qu'on gagne.** Une surface de dépendance connue et défendable : pour chaque outil, on sait sur quel axe il a été retenu et ce qu'il faudrait pour l'écarter. Le plancher ferme l'angle mort n°1 de `conformite.md` §5 (SBOM). Le contrat de format rend chaque substitution future bon marché.

**Ce qu'on paie.** Opengrep coûte de la profondeur d'analyse Java face aux règles Pro de Semgrep. L'auto-hébergement de l'agrégateur coûte de l'exploitation là où un SaaS n'en coûterait pas. Refuser Docker Scout comme gate unique impose de faire tourner deux scanners. Ces coûts sont assumés : ils achètent des axes supérieurs au coût.

**Ce qui reste ouvert.** L'agrégateur (atelier). Le SBOM PowerShell (pas d'outil). La provenance SLSA (angle mort `conformite.md`). Ces trois points sont des entrées de backlog, pas des oublis.

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0).*
