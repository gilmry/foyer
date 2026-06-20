# Simulateur TCO-ROI-Empreinte — synthèse des résultats

*Synthèse texte du fichier `Simulateur-TCO-ROI-KoproGo.xlsx` (9 onglets), pour que les chiffres soient lisibles par un agent ou par NotebookLM (qui ne parse pas le tableur binaire). Instance calibrée de l'abaque `skills/abaque-cout-capacite.md`, ancrée sur le projet réel KoproGo. Distinction maintenue : **mesuré** vs **prior à caler**.*

## Ce que le simulateur calcule

La trajectoire prospective, jalon par jalon (J0→J5), du **coût total** (fabrication + évolution + maintenance + exploitation) et de la **valeur** (revenu d'abonnement + coût évité), pilotée par l'**adoption**, l'**IoT** et le **tier d'architecture**. Il fait apparaître le croisement coût/valeur, les marches de scaling, le creux de trésorerie et le mur mémoire.

## Validation — le modèle reproduit le réel

Les coûts d'infrastructure modélisés collent aux **paliers réellement publiés par KoproGo** (prix OVH 2025, performances mesurées), à moins de 1 % :

| Copros | Infra modèle | KoproGo publié |
|---|---|---|
| 100 | 8,2 € | 8 € |
| 500 | 12,5 € | 13 € |
| 1 000 | 17,9 € | 18 € |
| 5 000 | 162,1 € | 163 € |

Le saut 29 € → 163 € entre 2 000 et 5 000 copros est la **marche de scaling** (passage à K8s multi-région : HA + load balancer + storage 3-AZ).

## Fabrication

Coût initial ≈ **17 k€** (scénario neutre). Calibrage des stories : **819 scénarios BDD ÷ 4 tags** (`@happy @negative @edge @security`) = **205 stories**, J0 (fondation, 59 entités) la plus lourde. Le coût est dominé par le **superviseur humain** ; les **tokens IA sont négligeables**.

## ROI — deux seuils à ne pas confondre

- **Surplus mensuel** positif dès **J3** (1 000 copros) — l'exploitation devient rentable.
- **Remboursement cumulé** (amortissant le capex de fabrication) seulement à **J5** (neutre). Base neutre, surplus cumulé J5 = **78 975 €**.

## Enveloppe des trois scénarios d'adoption (cadence propre à chaque)

| Scénario | Surplus cumulé J5 | Croisement | Creux de trésorerie (besoin de financement) |
|---|---|---|---|
| Pessimiste | +6 975 € | J5 (mois 84) | **−36 140 €** (creux à J3, ~3 ans sous l'eau) |
| Neutre | +78 975 € | J4 (mois 36) | −27 715 € |
| Optimiste | +137 750 € | J4 (mois 24) | −26 091 € |

Enseignement : le pessimiste finit par croiser, mais son **creux est plus profond et plus durable** — le vrai risque est la **survie de trésorerie**, pas le ROI. *« C'est la trésorerie, pas le ROI, qui tue un projet. »*

## Analyse de sensibilité (tornado financier, ±25 %, base 78 975 €)

| Levier | Amplitude sur le surplus J5 |
|---|---|
| **Tickets support / copro** | **71 175 €** |
| Ratio de supervision | 31 194 € |
| Coût pair / jour & jours / story | 29 245 € |
| Maintenance % / an | 12 462 € |
| Surcoût K8s | 600 € |
| Tours/story, tokens in/out | < 100 € |

**À l'échelle, c'est le coût récurrent de support par utilisateur qui gouverne la rentabilité — pas la fabrication.** Les tokens IA pèsent < 100 €. Côté **social**, c'est le **coût évité / copro** qui domine (±692 points de ROI social) — miroir du financier : les deux faces se pilotent avec des leviers différents.

## Empreinte mémoire — schéma × copros × temps

Ce qui tient les 287 req/s (P99 < 1 s), c'est le **working set PostgreSQL en RAM** (lignes chaudes + index), pas le disque.

- Lignes/copro : **708 (J0) → 6 060 (J5)** — l'empreinte/copro **quadruple par accumulation** (audit, transactions, votes) sur 36 mois, à copros constant.
- Pression RAM (neutre) : J3 31 % → **J4 127 % (saturé)** → J5 297 %. Le mur arrive parce que le **schéma grossit dans le temps**, pas seulement avec le nombre d'utilisateurs.

## Décomposition de la stack (la « RAM utile DB » est un reste)

`RAM utile DB = RAM nœud − OS(300) − Traefik(70) − Rust(130+8) − marge(100)` = **1,41 Go** sur un VPS 2 Go (valide l'hypothèse). Les **559 endpoints** gonflent surtout l'**image** (~91 Mo : registre, cold-start), peu la RAM résidente.

## Couplage tier — mémoire ET coût

Le choix de tier pèse sur deux fronts simultanés :
- **Mémoire** : K3s ajoute ~700 Mo de control-plane → la RAM PG tombe de **1,41 → 0,79 Go** → le mur avance (pression J4 : 127 % → 226 %).
- **Coût** : forcer K8s trop tôt = **7× de surcoût** (55 € vs 7 € à 20 copros), pour zéro gain ; à 5 000 copros les deux convergent à 163 €.

## IoT — un anti-pattern volumétrique

Un seul équipement IoT (5 capteurs × 4 relevés/h × 12 mois) = **175 200 lignes/copro** — l'équivalent de ~160 ans de données CRUD. À 30 % d'adoption, la pression J5 passe de 297 % à 530 %. **La série temporelle ne doit pas vivre dans PostgreSQL** : destination = TSDB (TimescaleDB) ou objet downsamplé. L'extraction du bounded context IoT (que le DDD permet proprement) est **le levier qui recule le mur** — choix irréversible → ADR.

## Discipline de lucidité

**Mesuré** (réel, sourcé) : les paliers de coût KoproGo, les performances (287 req/s, P99 752 ms, 0,12 g CO₂/req), les prix OVH 2025. **Prior à caler** : nombre de stories, ratio de supervision, taux d'accumulation des lignes, empreintes des composants, fréquence IoT. Tout prior est falsifiable, à remplacer par du mesuré (`pg_stat_user_tables`, `kubectl top`, facture cloud, télémétrie CSI).

---

*Synthèse de l'instance KoproGo de l'abaque. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
