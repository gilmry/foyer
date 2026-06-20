# Skill — Arbitrage des choix hybrides (la grille de souveraineté)

*Skill transversal du dispositif. La même machinerie de décision que l'agent applique à ses propres choix gouverne **tous les choix technologiques hybrides** de l'organisation — l'IA souveraine / API tierce n'en est qu'**une surface**. Hérite de `../Boucle-de-retroaction.md` (un choix s'évalue par un test = une boucle). Lignée : la doctrine de souveraineté du Manifeste Maury.*

> **Thèse.** Cloud/on-premise, propriétaire/open source, avec/sans support, IA souveraine/tierce ne sont pas quatre décisions séparées : c'est **la même question sous quatre surfaces**. La traiter une fois, bien, et la réappliquer.

---

## 1. Les axes hybrides — une seule décision, plusieurs surfaces

| Axe | Pôle « réversible / souverain » | Pôle « exposé » |
|---|---|---|
| **Substrat** | on-premise | cloud |
| **Origine** | open source | propriétaire |
| **Support** | auto-maintenu (maîtrise interne) | avec support (dépendance fournisseur) |
| **IA** | modèle souverain | API tierce |

Chaque axe a ses compromis ; aucun pôle n'est « bon » en soi. Ce qui compte n'est pas le pôle, c'est **de pouvoir en répondre**.

## 2. Les trois étages de souveraineté (à appliquer sur chaque axe)

- **Résidence** — *où* ça tourne (territoire, datacenter). Résider quelque part n'est *pas* en être souverain.
- **Souveraineté des données** — *qui peut contraindre l'accès* (juridiction, clés, lois extraterritoriales). Une donnée chez soi mais sous clé étrangère n'est pas souveraine.
- **Souveraineté de capacité** — *puis-je inverser, substituer, reprendre la main* (réversibilité, alternatives, compétence interne). C'est l'étage le plus souvent oublié.

## 3. Le test de réversibilité

**Louer le réversible, posséder l'irréversible ; au doute, traiter comme irréversible.** Un SaaS propriétaire sans porte de sortie = réversibilité faible ; un OSS auto-hébergé = forte ; un OSS supporté = intermédiaire ; un on-premise mono-fournisseur = résidence forte mais capacité faible. Le pôle ne dit rien seul ; c'est la **sortie possible** qui qualifie.

## 4. Dépendances héritées vs assumées

Une dépendance **subie** (héritée d'un choix amont, d'un standard, d'un écosystème) se **fait remonter**. Une dépendance **assumée** (le SaaS qu'on a choisi, le cloud qu'on a retenu, l'OSS qu'on a décidé de ne pas supporter) est **pleinement imputable**. Le *choix d'exposition* est toujours imputable — on en répond.

## 5. La hiérarchie de veto (lexicographique, pas un score)

**altérité → réversibilité → érosion → coût.** On tranche dans l'ordre ; un étage ne se rachète jamais par le suivant.

- **Altérité** — un tiers non consentant est affecté (RGPD, patient, usager, donnée d'autrui). C'est une **contrainte**, pas une vertu : elle prime tout.
- **Réversibilité** — peut-on défaire ?
- **Érosion** — est-ce qu'on glisse vers « assez fiable pour qu'on cesse de vérifier » ?
- **Coût** — en dernier, jamais en premier.

Exemple : un outil propriétaire moins cher qui expose des données patient à une juridiction étrangère **perd sur l'altérité** — le coût n'est même pas examiné.

## 6. Le danger commun à toutes les surfaces

*« Assez fiable pour qu'on cesse de vérifier. »* Vrai d'un modèle IA comme d'un fournisseur SaaS qu'on n'audite plus, d'un OSS qu'on ne relit plus, d'un cloud dont on a oublié la porte de sortie. La vérification doit rester un **réflexe**, sur chaque axe.

## 7. Ce qui se trace en ADR

Tout choix hybride non trivial (cloud vs on-prem, proprio vs OSS, support vs auto-maintenu, IA souveraine vs tierce) **déplace la souveraineté et la réversibilité** → ADR. Les choix **irréversibles** : validation humaine **et** enforcement au substrat (`enforcement.md`), jamais dans l'agent seul.

---

*La même grille pour l'agent et pour l'organisation. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
