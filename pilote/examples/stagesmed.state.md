<!-- EXEMPLE (dogfood) — registre rempli avec l'état RÉEL du rétrofit stagesmed.
     Sert à valider le format du registre sur un cas concret. Porte : RÉTROFIT. -->
# État Foyer — stagesmed (rétrofit)

- **Porte active** : `rétrofit`
- **Parcours** : `pilote/journeys/retrofit.md`
- **Archétype** : full-stack (stateful)  <!-- MySQL, sessions, CSRF ; îlots Svelte -->
- **Démarré le** : 2026-08 (sandbox `stagesmed-retrofit-test/`, branche `main`, sans remote)
- **Dernière mise à jour** : 2026-09-07 (par : agent)

## Position courante
- **Phase / étape** : Phase 2 · périmètre `medecins` · **étape 2.6 prouvée** (îlots D2, régression
  visuelle verte sur 3 rôles) — reste la **bascule n°2** (montage dans `dashboard.html` + retrait legacy).
- **Prochaine action attendue** : préparer la bascule n°2 `medecins` → arbitrage (point irréversible).
- **Rôle à jouer** : `pilote/roles/frontend-ilots.md` puis protocole `pilote/arbitrage.md`.

## Gates (dernier statut)
| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher (secrets/migrations) | 🟢 | 2026-09 | `docker run … php harness/verify.php` (G1/G2) |
| caractérisation | 🟢 | 2026-09 | `bash harness/ci.sh` (periods/students/medecins/auth/admin/doctor) |
| verify structurel (S1-S6) | 🟢 | 2026-09 | `harness/verify.php` |
| contrat (anti-drift) | 🟢 | 2026-09 | clients générés par périmètre (`harness/codegen-*.php`) |
| tests 4 couches | 🟢 | 2026-09 | Unit + BDD + Intégration + E2E |
| E2E (correctness) | 🟢 | 2026-09 | `harness/visual/` (journeys) |
| régression visuelle (D2) | 🟢 | 2026-09 | `harness/visual/` compare, tolérance 0,5 % (medecins 3 rôles) |
| doc vivante | 🟢 | 2026-09-07 | `bash harness/run-demo.sh` → 12 stories, 20 vidéos, vitrine |

## Périmètres
| Périmètre | État | Couches vertes | Bascule | Commit / ADR |
|---|---|---|---|---|
| periods | migré | D/A/Ad/C/F1/F2 | n°2 ✅ (legacy retiré) | `retrofit(periods): …` |
| students | migré | D/A/Ad/C/F1/F2 | n°2 ✅ (legacy retiré) | `retrofit(students): …` |
| medecins | en cours | D/A/Ad/C/F1/**F2 prouvée** | **n°2 🔴 en attente** | `retrofit(medecins): 2.6 îlot D2 …` |
| auth / admin / doctor | caractérisés | — | — | résidus cross-scope à traiter |

## Arbitrages
### 🔴 En attente
- **Point** : bascule n°2 — frontend D2 périmètre `medecins`.
  - **Preuve jointe** : E2E vert + régression visuelle verte (3 rôles) + doc vivante verte.
  - **Question de modalité** : monte-t-on l'îlot dans `dashboard.html` et retire-t-on le legacy
    maintenant ? quels parcours restent « critiques » ? rollback si l'écran médecins régresse ?
  - **Options** : A) monter + retirer legacy en une passe ; B) monter en coexistence puis retirer
    au prochain jalon ; C) attendre le re-audit sécurité d'abord.

### ✅ Tranchés
| Point | Décision (modalité) | Par | Le | ADR |
|---|---|---|---|---|
| bascule n°2 periods | montage + retrait legacy en une passe | humain | 2026-09 | ADR-retrofit-periods |
| bascule n°2 students | idem | humain | 2026-09 | ADR-retrofit-students |

## Journal
- 2026-09-07 — doc vivante : 12 stories (5 personas + 7 workflows), vitrine verte.
- 2026-09 — medecins 2.1→2.6 (îlot D2 prouvé) ; reste bascule n°2, re-audit sécurité, résidus
  cross-scope (mail modal partagé, export assignments), puis phases 3-4.
