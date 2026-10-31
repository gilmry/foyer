<!-- EXEMPLE (fictif) — registre d'un projet en RÉTROFIT, dérivé de pilote/state.template.md.
     Projet, périmètres, personnes et chiffres sont inventés : l'exemple montre la STRUCTURE
     d'un registre arrivé en phase 4 (preuve de convergence), avec un arbitrage 🔴 en attente.
     À comparer avec nouveau-projet.state.md (porte `nouveau`). -->
# État Foyer — acme-reservations (rétrofit)

- **Porte active** : `rétrofit`
- **Parcours** : `pilote/journeys/retrofit.md`
- **Archétype** : full-stack (stateful) — PHP/MySQL, sessions/CSRF, îlots Svelte
- **Niveau CyFun® visé** : Important  <!-- données personnelles des réservataires ; abaissement sous Essential consigné en ADR -->
- **Substrat d'exécution** : conteneur (Docker)
- **Démarré le** : 2026-03-02 · sandbox `acme-reservations-retrofit/` (branche `main`)
- **Dernière mise à jour** : 2026-04-20 (par : agent — gate-runner)

## Répartition des rôles

| Rôle | Qui | Depuis |
|---|---|---|
| **PO** (tranche les modalités, valide sur preuve, signe) | Alex (PO, fictif) | 2026-03-02 |
| **Dev** (exécute, assemble la preuve, ne tranche jamais) | Sam (dev, fictif) + agent | 2026-03-02 |

## Gantt / vagues

- **Gantt** : `docs/gantt-retrofit.md` (signé le 2026-03-04 par Alex)
- **Vague courante** : 3 · **barrière** : point irréversible n°5 (architecture engagée)
- **Branches ouvertes** : `retrofit/admin-bascule-n2`
- **Barreau** : Scrum (ADR-003)

## Position courante

- **Phase / étape** : **Phase 4 — preuve de convergence** (re-mesurée, proposée).
- **Prochaine action attendue** : **point irréversible n°5** — passage à l'architecture engagée →
  validation humaine sur la grille de diagnostic (arbitrage 🔴 en attente ci-dessous).
- **Rôle à jouer** : `pilote/roles/verrouillage-convergence.md` + protocole `pilote/arbitrage.md`.

## Gates (dernier statut)

| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher : secrets (G1) · migrations réversibles (G2) | 🟢 | 2026-04-20 | `php harness/verify.php` |
| plancher : SBOM CycloneDX | 🟢 | 2026-04-20 | `composer CycloneDX:make-sbom` (dans `harness/ci.sh`) |
| plancher : vulnérabilités conteneur | 🟢 0 critique | 2026-04-20 | `bash harness/scan-image.sh` |
| caractérisation (4 périmètres, 180 assertions) | 🟢 | 2026-04-20 | `bash harness/ci.sh` |
| verify structurel (H1 : Domain/Application purs) | 🟢 | 2026-04-20 | `php harness/verify.php` |
| contrat (anti-drift) | 🟢 | 2026-04-18 | `php harness/verify.php` |
| tests 4 couches (PHPUnit domaine : 96 tests / 240 assert.) | 🟢 | 2026-04-20 | `bash harness/run-phpunit.sh` |
| E2E (parcours de référence, 2 rôles) | 🟢 | 2026-04-19 | `npm run e2e` |
| régression visuelle (D2) | 🟢 | 2026-04-19 | `harness/visual/` (tolérance 0,5 %) |
| doc vivante (6 stories, 8 vidéos) | 🟢 | 2026-04-19 | `bash harness/run-demo.sh` → `harness/demo/vitrine/` |
| convergence (diagnostic vanilla) | 🟢 10/0 | 2026-04-20 | `php scripts/diagnostic-vanilla.php` |
| convergence idéal kit (mesure de résidu) | 🟡 5/8 | 2026-04-20 | `php scripts/diagnostic-kit.php` |
| jalon (SAST · SCA · qualité) | 3 findings SCA (moyen), 0 SAST | 2026-04-20 | rapport CI, trié en gate review |

**Dernière gate review** : 2026-04-13 · autoévaluation CyFun : seuils atteints oui, 2 écarts documentés (`skills/conformite.md` §2quater)

## Périmètres

| Périmètre | État | Couches vertes | Bascule | Commit / ADR | Tours | Tokens | Wall-clock |
|---|---|---|---|---|---|---|---|
| catalogue | migré | D/A/Ad/C/F1/F2 | n°2 ✅ | `retrofit(catalogue): bascule n°2` | 14 | 310 k | 6 h |
| reservations | migré | D/A/Ad/C/F1/F2 | n°2 ✅ (9 routes) | `retrofit(reservations): bascule n°2` | 22 | 540 k | 11 h |
| comptes | migré | D/A/Ad/C | flux navigateur (ADR-004, hors client généré) | `retrofit(comptes): 2.4 — ADR contrat auth` | 9 | 180 k | 4 h |
| admin | en cours | D/A/Ad | 5/7 routes | — | 6 | 120 k | 3 h |

> `src/LegacyApplication.php` : 1 400 → ~900 lignes, 48 → ~20 requêtes SQL — réduit à
> l'adaptateur HTTP (routing + auth de requête + CSRF + cookies). H1 vert.

## Promotions

| Branche | Preuve complète (gate `promotion`) | Minutes d'arbitrage | Diff ouvert ? (pourquoi) | Décision | Le |
|---|---|---|---|---|---|
| `retrofit/reservations-bascule-n2` | 🟢 | 12 | non | promue | 2026-04-11 |
| `retrofit/comptes-contrat-auth` | 🔴 (vitrine absente) | 25 | oui : écran critique sans vidéo | renvoyée | 2026-04-15 |

## Arbitrages

### 🔴 En attente (l'humain doit trancher une MODALITÉ)

- **Point n°5 — passage à l'architecture engagée** (phase 4, irréversible).
  - **Preuve jointe** : `bash harness/ci.sh` tout vert ; `diagnostic-vanilla.php` **10/0 CONVERGÉ** ;
    180 assertions de caractérisation (comportement externe inchangé, byte-exact) ; H1 vert ;
    doc vivante verte. Détail : `docs/RETROFIT-CONVERGENCE.md`.
  - **Question de modalité** : valide-t-on la convergence vers la **destination vanilla** (kit en
    miroir, imposée par la contrainte d'hébergement mutualisé — ADR-005) **avec le résidu de
    stack assumé** (`diagnostic-kit.php` 5/8 : framework et ORM du kit non adoptés) ?
  - **Options présentées** : A) valider la convergence vanilla + consigner le résidu de stack en
    ADR accepté ; B) exiger la bascule stack complète avant de valider ; C) valider par
    périmètre plutôt que globalement.

### ✅ Tranchés

| Point | Décision (modalité) | Par | Le | ADR |
|---|---|---|---|---|
| bascule n°2 catalogue/reservations | montage îlot + retrait legacy | Alex | 2026-04-11 | commits `retrofit(<p>): bascule n°2` |
| contrat auth hors client généré | flux navigateur documenté | Alex | 2026-04-08 | ADR-004 |
| stack vanilla (miroir kit) | rester PHP/MySQL, gates miroités | Alex | 2026-03-20 | ADR-005 |

## Journal (chronologie courte)

- 2026-04-20 — phase 4 : synthèse de convergence (`docs/RETROFIT-CONVERGENCE.md`) — **à valider** (point n°5).
- 2026-04-19 — doc vivante : 6 stories (3 personas + 3 workflows), 8 vidéos, vitrine (`a1b2c3d`).
- 2026-04-15 — promotion `comptes-contrat-auth` renvoyée : vitrine absente sur un écran critique.
- 2026-04-11 — bascule n°2 reservations promue (preuve complète, 12 min d'arbitrage).
- 2026-03-20 — phase 3 : CI + `harness/ci.sh` (la source de vérité quitte la prod) ; ADR-005 stack vanilla.
- 2026-03-02 — phase 1 : harnais, plancher 🟢, caractérisation des 4 périmètres (bugs figés tels quels).
