# CSI rétroactif — la télémétrie reconstituée depuis Git

*Outil d'objectivation de la boucle CSI (`../../Boucle-de-retroaction.md`). Il remplace des priors `[caler]` de l'abaque (`../../skills/abaque-cout-capacite.md`) par du mesuré, quand la télémétrie du registre d'état (`../../pilote/state.template.md`) n'a pas été relevée en temps réel.*

Chaque commit est horodaté, attribué (humain, agent, bot) et décrit. L'historique est donc une télémétrie déjà enregistrée. `csi_retro.py` la relit, de façon déterministe : il ne fait aucune estimation à la main et n'accède pas au réseau.

## Lancer

```bash
python3 tools/csi/csi_retro.py ~/depots --out csi_out          # tous les dépôts clonés sous ~/depots
python3 tools/csi/csi_retro.py ~/depots --gap 60 --lead 15     # sensibilité aux priors [caler]
python3 -m unittest tools/csi/test_csi_retro.py                # gate : 0 = vert
```

Le script n'utilise que la bibliothèque standard de Python, avec Git en lecture seule. L'historique complet est requis : faire un `git fetch --unshallow` si le clone est superficiel.

## Sorties

| Fichier | Contenu |
| --- | --- |
| `depots.csv` | Une ligne par dépôt : durée, jours actifs, commits, part IA, sessions, heures, taille HEAD (code, test, doc), ratios, réécriture, commits conventionnels, ratio fix/feat, scénarios BDD, tests déclarés, stories |
| `jalons.csv` | Date d'apparition des pratiques (CI, tests, BDD, ADR, conteneur, déploiement, garde-fous IA, supply chain, test d'architecture), en jours depuis le début |
| `semaines.csv` | Activité par semaine ISO et par dépôt, qui sert à mesurer le parallélisme réel (ratio de supervision) |
| `sessions.csv` | Les sessions de travail reconstituées, qui servent de base au wall-clock |
| `statuts.csv` | L'étiquette de lucidité de chaque colonne |

## Discipline de lucidité (abaque §9)

Chaque colonne porte un statut, et un test échoue si une colonne en est dépourvue.

- **MESURÉ** : lu tel quel dans Git (dates, auteurs, trailers `Co-Authored-By`, lignes présentes à HEAD).
- **DÉRIVÉ** : calcul déterministe sur du mesuré (ratios, réécriture).
- **SUPPOSÉ** : dépend d'un prior `[caler]` explicite.

| Prior `[caler]` | Défaut | Effet |
| --- | --- | --- |
| `--gap` | 120 min | Au-delà de cet écart entre deux commits, une nouvelle session commence |
| `--lead` | 30 min | Travail compté avant le premier commit d'une session |
| stories | scénarios BDD ÷ 4 | Règle de `cycle-dev` (`@happy @negative @edge @security`) |

## Limites connues

- **Heures sous-estimées pour les longs runs d'agent.** Un run de plus de `--gap` sans commit est coupé.
- **Part IA = part déclarée.** Elle repose sur l'auteur, le trailer ou une branche d'agent fusionnée. Un commit assisté non déclaré compte comme humain.
- **Lignes ajoutées ≠ valeur.** La taille HEAD et le taux de réécriture sont plus parlants que le volume brut.
- **Pas d'inférence causale.** Une comparaison avant/après ne prouve pas l'effet de la méthode : les modèles et l'expérience progressent aussi.

## Métriques à instrumenter ensuite (relevé continu, pas rétroactif)

1. **Délai idée → production** : du brief au premier `apply` Tier 1, horodaté par le journal d'audit Sluis.
2. **Écart estimé / réel par capacité** : heures du devis contre heures des sessions, mesuré par le MAPE (erreur moyenne en %).
3. **Tours par story** : runs CI rouges avant le vert, par pull request (API GitHub Actions).
4. **Taux de réfutation par gate** : quelle gate bloque, et à quelle fréquence.
5. **Taux de reprise humaine** : pull requests d'agent modifiées ou renvoyées (colonne « diff ouvert » du registre).
6. **Tokens et coût modèle par story** : journaux d'usage de Claude Code, agrégés localement.
7. **Taux d'échappement** : `fix` qui corrigent un `feat` fusionné depuis moins de 14 jours.
8. **DORA** : fréquence de déploiement, taux d'échec de changement, temps de restauration, délai de livraison.
9. **Taux d'affirmations étayées** : chaque chiffre d'un README est produit par un artefact de CI, et une gate échoue s'il diverge.

---

*Registre trace. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
