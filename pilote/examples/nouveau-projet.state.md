<!-- EXEMPLE (minimal) — registre d'un NOUVEAU projet en sortie de conception BMAD.
     Illustre la porte greenfield : conception faite, on entre en bootstrap du kit. -->
# État Foyer — acme-notes (nouveau projet)

- **Porte active** : `nouveau`
- **Parcours** : `pilote/journeys/nouveau-projet.md`
- **Archétype** : api-first  <!-- décidé par l'architecte BMAD ; fixe les gates conditionnels -->
- **Démarré le** : 2026-09-07
- **Dernière mise à jour** : 2026-09-07 (par : agent)

## Position courante
- **Phase / étape** : Phase B · geste 4 (premier domaine `Note`) après conception BMAD validée.
- **Prochaine action attendue** : extraire le domaine `Note` (Domaine pur, tests Unit ROUGE d'abord).
- **Rôle à jouer** : `pilote/roles/extracteur-couche.md`.

## Gates (dernier statut)
| Gate | Statut | Quand | Commande |
|---|---|---|---|
| plancher (secrets/migrations) | 🟢 | 2026-09-07 | `php scripts/verify.php` |
| verify structurel | 🟢 | 2026-09-07 | `php scripts/verify.php` (kit vérifié à vide) |
| contrat | ⚪ | — | `php bin/console app:gate:contract` (après couche Contrat) |
| unit / bdd / integration | ⚪ | — | à venir avec le 1er domaine |
| e2e | ⚪ | — | avec le frontend D1 |
| doc vivante | ⚪ | — | avec la 1re story (non bloquant) |

## Backlog (stories « Agent IA Ready »)
| Story | État | Couches vertes | Commit / ADR |
|---|---|---|---|
| Créer/lister une note (CRUD) | en cours | — | — |
| Rechercher une note | à faire | — | — |

## Arbitrages
### 🔴 En attente
- (aucun)
### ✅ Tranchés
| Point | Décision (modalité) | Par | Le | ADR |
|---|---|---|---|---|
| choix d'archétype | api-first | humain | 2026-09-07 | ADR-archetype |

## Journal
- 2026-09-07 — conception BMAD validée (product-brief, PRD, architecture, backlog « Agent IA Ready »).
- 2026-09-07 — bootstrap kit : reproductibilité + gates verts à vide ; entame du domaine `Note`.
