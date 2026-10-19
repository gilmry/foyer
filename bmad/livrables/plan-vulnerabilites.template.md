# Plan de gestion des vulnérabilités — [PROJET]

*Livrable de l'Architecte, rattaché à la couche 7 (Monitoring & Sécurité) de l'Architecture. Répond à **ID.RA-08.1 ★I** de CyFun® 2025 ; s'appuie sur **ID.RA-01.3 I** (processus documenté) et **ID.RA-06.1 I** (réponses priorisées et suivies). Identifiants cités sans le texte du CCB (TLP:GREEN), voir `../../skills/conformite.md` §2bis.*

> **Pourquoi un document, et pas seulement des scans.** Les gates *exécutent* la détection et leurs rapports en sont la preuve (`conformite.md` §2ter). Ce plan dit **qui décide quoi, dans quel délai, et comment on le dit** : c'est lui que l'autoévaluation demande, et aucun rapport ne le remplace.

## 1. Périmètre

- **Composants couverts** : [code applicatif, dépendances, image de conteneur, configuration d'infrastructure portée par le projet]
- **Hors périmètre, porté ailleurs** : [plateforme d'hébergement → couche plateforme (ex. Sluis) ; poste de travail → documents d'organisation]
- **Responsable** : [nom]. Seul porteur : le dire, et nommer le suppléant ou la mesure compensatoire (PR.AA-05.6, `conformite.md` §2bis).

## 2. Identifier — d'où viennent les vulnérabilités

| Source | Mécanisme | Fréquence |
|---|---|---|
| Dépendances | SCA de `../../skills/gates.md` + bot de montée de version | à chaque build + [hebdomadaire] planifié |
| Image de conteneur | gate vulnérabilités conteneur (plancher) | à chaque build |
| Code | SAST (exigence de jalon) | à chaque PR |
| Secrets | gate secrets (plancher) | à chaque push |
| Signalement externe | §6 (CVD) | à réception |

Une source planifiée compte : un projet sans commit pendant un mois ne déclenche aucun build, alors que de nouveaux avis tombent.

## 3. Analyser et évaluer — trier un finding

Chaque finding reçoit une **sévérité retenue**, qui n'est pas forcément celle de l'outil :

1. **Atteignable ?** Le code vulnérable est-il appelé dans *ce* produit (fonctionnalité utilisée, chemin exposé) ?
2. **Exposé ?** Depuis Internet, depuis un utilisateur authentifié, ou seulement en local ?
3. **Exploité ?** Un exploit public ou une exploitation active connue relève la sévérité d'un cran.

La décision est **tracée** là où l'équipe la retrouve : issue pour une correction, ADR pour une acceptation. Un finding sans décision écrite n'est pas trié.

## 4. Atténuer — délais cibles

*Défaut annoncé, à ajuster une fois et à tracer en ADR s'il est abaissé.*

| Sévérité retenue | Délai de correction ou de mitigation |
|---|---|
| Critique, ou exploitée activement | [7 jours] |
| Haute | [30 jours] |
| Moyenne | [90 jours] ou prochaine gate review |
| Basse | backlog, revue en gate review |

**Quatre réponses possibles** (ID.RA-06.1) : corriger · mitiger (configuration, désactivation de la fonction) · accepter (ADR avec date de réexamen) · éviter (retirer le composant). Accepter n'est pas ignorer : l'ADR porte la raison et la date à laquelle on reposera la question.

## 5. Communiquer

- **En interne** : la gate review reprend les findings ouverts, les acceptations à réexaminer et les délais dépassés.
- **Aux utilisateurs** : une correction de sécurité publiée le dit dans les notes de version, avec l'identifiant de l'avis.
- **Obligation légale** : si le produit est mis sur le marché dans le cadre d'une activité commerciale, le **CRA** impose de notifier une vulnérabilité activement exploitée (`conformite.md` §3 et angle mort n°2 de §5). [Applicable : oui / non, et pourquoi]

## 6. Divulgation coordonnée (CVD)

La partie publique de ce plan. Elle se publie à la racine du dépôt dans un `SECURITY.md` :

- **Canal** : [adresse dédiée, ou signalement privé de la forge]. Jamais une issue publique.
- **Accusé de réception** : sous [5 jours ouvrés].
- **Engagement** : tenir le rapporteur informé, corriger dans les délais du §4, le créditer s'il le souhaite.
- **Divulgation** : publique après correction, ou à [90 jours] au plus tard, d'un commun accord.
- **Recours** : en Belgique, le **CCB** coordonne la CVD au niveau national ; un chercheur peut s'adresser à lui si le porteur ne répond pas.

## 7. Automatiser *(Essential : ID.RA-08.2 E)*

À Essential, la collecte, le suivi et le reporting des corrections sont **automatisés** : bot de montée de version qui ouvre les PR, findings remontés en issues étiquetées, tableau des délais dépassés. Un plan tenu à la main reste valable à Important.

## 8. Exemple

> Sluis, octobre 2026. rustls 0.23.43 : quatre avis RUSTSEC remontés par le SCA de la CI (§2). **Atteignable** : oui, c'est le TLS du client HTTP qui appelle les API de la forge et de l'hébergeur. **Exposé** : côté client seulement, aucune surface entrante ; un attaquant doit se placer sur le chemin réseau. **Exploité** : non connu. Mais ce client porte les jetons d'API de déploiement, et l'un des avis concerne la fuite de secrets dans les traces → **haute** (§3). Réponse : corriger, montée à 0.23.46, seul le fichier de verrouillage change (§4). Corrigé dans la journée. Preuve : la PR de correction, le rapport SCA vert qui suit, et la fusion (ID.AM-08.2 ★B, `conformite.md` §2ter).

---

*Dérivé du Manifeste Maury (CC BY-SA 4.0).*
