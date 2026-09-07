<!-- Registre d'état Foyer (pilote) — dérivé de pilote/state.template.md.
     Source de vérité partagée PO ↔ dev. Créé par dogfood du pilote sur l'état réel du dépôt. -->
# État Foyer — stagesmed (rétrofit)

- **Porte active** : `rétrofit`
- **Parcours** : `pilote/journeys/retrofit.md`
- **Archétype** : full-stack (stateful) — PHP/MySQL, sessions/CSRF, îlots Svelte
- **Démarré le** : 2026-08 · sandbox `stagesmed-retrofit-test/` (branche `main`, sans remote)
- **Dernière mise à jour** : 2026-09-07 (par : agent — dogfood pilote)

## Position courante
- **Phase / étape** : **Phase 4 — preuve de convergence** (re-mesurée, proposée).
- **Prochaine action attendue** : **point irréversible n°5** — passage à l'architecture engagée →
  **validation humaine sur la grille de diagnostic** (arbitrage 🔴 en attente ci-dessous).
- **Rôle à jouer** : `pilote/roles/verrouillage-convergence.md` + protocole
  `pilote/arbitrage.md`.

## Gates (dernier statut)
| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher (secrets G1 / migrations G2) | 🟢 | 2026-09 | `php harness/verify.php` |
| stock sécurité (S1-S6) | 🟢 | 2026-09 | `php harness/verify.php` |
| contrat anti-drift (C/D/M) | 🟢 | 2026-09 | `php harness/verify.php` |
| H1 hexagonal (Domain/Application purs) | 🟢 | 2026-09 | `php harness/verify.php` |
| caractérisation (6 périmètres, 423 assertions) | 🟢 | 2026-09 | `bash harness/ci.sh` |
| PHPUnit domaine (251 tests / 655 assert.) | 🟢 | 2026-09 | `bash harness/run-phpunit.sh` |
| E2E / régression visuelle (medecins 3 rôles) | 🟢 | 2026-09 | `harness/visual/` (tolérance 0,5 %) |
| doc vivante (12 stories, 20 vidéos) | 🟢 | 2026-09-07 | `bash harness/run-demo.sh` → `harness/demo/vitrine/` |
| convergence vanilla | 🟢 12/0 | 2026-09 | `php scripts/diagnostic-vanilla.php` |
| convergence idéal Symfony (mesure de résidu) | 🟡 6/9 | 2026-09 | `php scripts/diagnostic-kit.php` |

## Périmètres
| Périmètre | État | Couches vertes | Bascule | Caractérisation |
|---|---|---|---|---|
| periods | migré | D/A/Ad/C/F1/F2 | n°2 ✅ | 35/35 |
| students | migré | D/A/Ad/C/F1/F2 | n°2 ✅ | 93/93 |
| medecins | migré | D/A/Ad/C/F1/F2 (3 vues rôle) | n°2 ✅ (16 routes) | 170/170 |
| auth | migré | D/A/Ad/C | flux navigateur (ADR, hors client généré) | 66/66 |
| admin | migré | D/A/Ad | 9/9 routes | 42/42 |
| registration | migré | D/A/Ad | ✅ | 17/17 |

> `src/Lot1Application.php` : 1986 → ~1779 lignes, 69 → ~30 requêtes SQL — réduit à
> l'adaptateur HTTP (routing + auth-de-requête + rate-limit + audit + CSRF + cookies). H1 vert.

## Arbitrages
### 🔴 En attente
- **Point n°5 — passage à l'architecture engagée** (phase 4, irréversible).
  - **Preuve jointe** : `bash harness/ci.sh` tout vert ; `diagnostic-vanilla.php` **12/0 CONVERGÉ** ;
    423 assertions de caractérisation (comportement externe inchangé, byte-exact) ; H1 hexagonal vert ;
    doc vivante verte. Détail : `docs/RETROFIT-CONVERGENCE.md`.
  - **Question de modalité** : valide-t-on la convergence vers la **destination vanilla** (kit en
    miroir, imposée par la contrainte webhosting — ADR `RETROFIT-DIAGNOSTIC.md` §5) **avec le
    résidu de stack assumé** (`diagnostic-kit.php` 6/9 : Symfony/ApiPlatform/Doctrine non adoptés) ?
  - **Options** : A) valider la convergence vanilla + consigner le résidu de stack en ADR accepté ;
    B) exiger la bascule stack complète (ApiPlatform/Doctrine/Astro) avant de valider ;
    C) valider par périmètre plutôt que globalement.

### ✅ Tranchés
| Point | Décision (modalité) | Par | Le | ADR |
|---|---|---|---|---|
| bascule n°2 periods/students/medecins | montage îlot + retrait legacy | humain | 2026-09 | commits `retrofit(<p>): bascule n°2` |
| contrat auth hors client généré | flux navigateur documenté | humain | 2026-09 | `retrofit(auth): 2.4 — ADR contrat auth` |
| stack vanilla (miroir kit) | rester PHP/MySQL, gates miroités | humain | 2026-09 | `RETROFIT-DIAGNOSTIC.md` §5 |

## Journal
- 2026-09-07 — doc vivante : 12 stories (5 personas + 7 workflows), 20 vidéos, vitrine (`5771a05`).
- 2026-09-04 — phase 4 : synthèse de convergence (`docs/RETROFIT-CONVERGENCE.md`) — **à valider**.
- 2026-09 — phase 3 : CI + `harness/ci.sh` (la source de vérité quitte la prod).
- 2026-09 — extraction+bascule des 6 périmètres (periods, students, medecins, auth, admin, registration).
