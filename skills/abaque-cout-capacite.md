# Skill — Abaque coût & capacité (estimation prospective)

*Skill d'analyse du dispositif. Hérite de la primitive `../Boucle-de-retroaction.md` : c'est **la boucle appliquée à l'anticipation** — Conception = hypothèse de coût/empreinte, Évaluation = l'abaque (et le modèle de calcul), Amélioration = recalage par la télémétrie CSI. Stack-agnostique, conditionné par l'archétype (`../bmad/archetypes.md`). Instance calibrée : le simulateur TCO-ROI KoproGo.*

> **Statut des nombres.** Les formules sont généralisables ; les **constantes** ci-dessous sont calibrées sur une stack OVH/PostgreSQL réelle et marquées `[caler]`. Tout chiffre `[caler]` est un **prior** à remplacer par du mesuré (`pg_stat_user_tables`, `pg_relation_size`, `docker stats`/`kubectl top`, facture cloud) dès qu'on a tourné un projet.

---

## 1. Coût de fabrication (et d'évolution)

Par capacité/jalon : `coût ≈ stories × tours/story × coût_tour(tokens) + (stories × jours/story ÷ ratio_supervision) × coût_pair_jour`.

- `coût_tour` = `(tokens_in × prix_in + tokens_out × prix_out)`. **Négligeable** dans le total.
- **Le poste dominant est le superviseur**, pas le modèle. Optimiser les tokens ne déplace presque rien.
- `ratio_supervision` (agents qu'un pair tient en parallèle) est le **plafond *répondre-de***, pas une variable budgétaire : au-delà, on ne peut plus *répondre de* ce qui est produit. Quand il faut plus de parallélisme, on ajoute un *pair* (coût en marche d'escalier), pas seulement des agents.
- Calibrage stories : `total ≈ scénarios BDD ÷ 4` (les 4 tags `@happy @negative @edge @security` de `cycle-dev`), réparti par jalon (fondation la plus lourde).

## 2. Coût récurrent — l'heuristique qui renverse l'intuition

`opex/mois = infra + maintenance_code + support`, avec `maintenance ≈ %_annuel × cumul_fabriqué` et `support ≈ copros × tickets/copro/an ÷ 12 × coût_ticket`.

**À l'échelle, le récurrent (support + maintenance) gouverne la rentabilité — pas le coût de fabrication.** Le build est un one-off ; le support par utilisateur, multiplié par la base, le pulvérise. Conséquence : pour la viabilité, agir sur les **tickets/copro** (self-service, doc vivante, boucle adoption) rend plus que tout le reste.

## 3. ROI & financement — deux seuils à ne pas confondre

- **Surplus mensuel positif** (revenu/mois > opex/mois) ≠ **payback**. Le cumulé doit encore amortir le capex de fabrication.
- **Creux de trésorerie** = point le plus bas du surplus cumulé = **besoin de financement** : le capital à tenir avant le croisement. C'est souvent la contrainte qui tue un projet, pas le ROI. Un scénario lent croise quand même *plus tard*, mais avec un creux **plus profond et plus durable** → risque de survie.
- ROI **financier** (revenu − coût) et ROI **social** (coût évité ÷ coût) ne se pilotent pas avec les mêmes leviers : le premier par le support/supervision, le second par le coût évité/copro (donc desservir plus de copros, y compris non-payants).

## 4. Empreinte runtime — la mémoire, pas le disque

Ce qui tient la perf (req/s, P99) c'est le **working set en RAM** (lignes chaudes + index), pas le storage disque (forfait `[caler ~0,027 €/copro/mois]`, dominé par les blobs).

- `lignes/copro = entités × lignes_statiques/entité + taux_accumulation/copro/mois × mois_écoulés`.
- **L'empreinte/copro croît dans le temps** même à copros constant, car les entités *accumulatives* (audit, transactions, votes) s'empilent. Le schéma qui grossit (roadmap) déplace le mur.
- `working_set = index + fraction_chaude × données` ; `pression = working_set / RAM_utile_DB`.

## 5. Décomposition de la stack — la RAM utile DB est un reste

`RAM_utile_DB = RAM_nœud − OS − orchestration − proxy − app − (S3 self-hosted) − marge`.

Ordres de grandeur `[caler]` : OS+Docker ~300 Mo, proxy (Traefik) ~70 Mo, app (binaire compilé) ~130 Mo + part endpoints modeste (les endpoints gonflent surtout l'**image** : registre, cold-start, déploiement — peu la RAM).

## 6. Les marches de scaling — un escalier, pas une pente

Le scaling se franchit par **paliers d'architecture**, et chaque palier pèse sur **deux fronts** :

| Tier | Effet mémoire | Effet coût |
|---|---|---|
| VPS + compose | plafond = capacité/nœud | nœuds × prix + storage |
| K3s | **control-plane ~700 Mo `[caler]`** → ampute la RAM DB → avance le mur | nœuds plus gros/HA |
| K8s managé | nœuds dimensionnés + multi-AZ | **+ forfait LB/managé + HA ×nœuds + storage 3-AZ** |

Choisir un tier n'est pas neutre : c'est un **arbitrage *répondre-de*** qui déplace *à la fois* le seuil de saturation et la courbe de coût. Le franchir trop tôt = surcoût visible sans gain. → **ADR**.

## 7. Le levier DDD — extraire pour soulager

Une entité **haute-cardinalité / série temporelle** (capteurs IoT, logs massifs) dans la base relationnelle est un **anti-pattern** : elle sature le working set des données métier chaudes. Le DDD permet d'**extraire son bounded context** vers un stockage adapté (TSDB, objet downsamplé). C'est *le* levier qui recule le mur mémoire — et un point **irréversible** (migration de données) → **ADR**.

## 8. Conditionnement par archétype — la forme de la courbe

- **stateless** : runtime quasi linéaire, élastique, bon marché ; pas de centre de coût DB.
- **stateful** : **la DB est le centre de coût** ; scaling en marches (vertical → réplication/sharding).
- **API-first** : versioning/contrat = points irréversibles ; charge côté consommateurs.
- **full-stack** : les sept couches ; empreinte la plus lourde.

## 9. Discipline de lucidité

Tout `[caler]` est un **prior bleu**, falsifiable, à remplacer par du mesuré. Le modèle se valide en se confrontant à des chiffres publiés/réels (ex. paliers infra connus). On distingue toujours **mesuré** (réel, sourcé) de **supposé** (à confirmer). Le tornado de sensibilité dit *où* le calage compte le plus (souvent : tickets/copro, ratio supervision, taux d'accumulation).

---

*Registre guidance/trace. Les inflexions irréversibles (tier, destination d'entité haute-cardinalité) → ADR, validation humaine. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
