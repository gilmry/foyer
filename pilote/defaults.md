# defaults.md — défauts automatiques (parcours sans friction pour un vibe codeur)

> **Règle d'or du pilote pour un PO non-développeur.**
> L'agent **tranche seul** tout choix technique **réversible**, avec le défaut ci-dessous, et
> l'**annonce en une phrase** — il ne le met pas au vote. Le PO ne répond **qu'à des questions
> métier, en langage clair**. « ORM ou SQL pur ? », « ApiPlatform ou vanilla ? », « SQLite ou
> MySQL ? » ne sont **jamais** posées au PO : ce sont des défauts, pas des arbitrages.

## Ce que l'agent décide seul (et annonce, sans demander)

| Décision | Défaut automatique | Pourquoi réversible |
|---|---|---|
| **Archétype** | Inféré du brief : état persisté + interface → `stateful full-stack` ; API sans écran → `api-first` ; transform pur → `stateless` | Fixe les gates, mais se change en re-cadrant le brief |
| **Niveau CyFun® visé** | Inféré du brief : le produit **conserve des données de ses utilisateurs** (comptes, données personnelles, financières, décisions) → **Essential** ; sinon → **Basic**. Cf. [`../skills/conformite.md`](../skills/conformite.md) §2bis | Ne fixe que le seuil vérifié en gate review, pas le plancher. **Le relever** est un défaut ; **l'abaisser sous Essential** pour un produit qui conserve des données d'utilisateurs se trace en ADR |
| **Pile / kit** | Le kit résolu par [`journeys`](journeys/nouveau-projet.md) B0 (seed local, sinon scaffold). Pas de techno imposée au PO | On peut re-seeder tant qu'aucune story n'est livrée |
| **Persistance** | Le mécanisme du kit (souvent SQL simple + migrations réversibles). Pas d'ORM sauf besoin réel | Migrations `up/down` réversibles |
| **Substrat d'exécution** | Runtime local s'il existe, **sinon conteneur** (Docker) — cf. `parcours.md` étape 0bis | N'affecte pas le produit |
| **Base de dev** | La plus légère qui tourne sans installation (conteneur éphémère) | Éphémère |
| **Nommage, arborescence, IDs** | Conventions du kit | Refactorable |

## Ce qui remonte VRAIMENT au PO (et comment le formuler)

Uniquement les points **irréversibles ET compréhensibles sans être dev**, en langage métier :

- **Destination métier** : « Ton app doit-elle gérer *plusieurs utilisateurs avec comptes*, ou
  *une seule liste* ? » (≠ « mono-tenant ou multi-tenant ? »).
- **Valeur des données** : « Ton app va-t-elle garder des *informations sur tes utilisateurs*
  (noms, adresses, paiements, votes…) ? » (≠ « quel niveau CyFun ? »). La réponse fixe le
  niveau CyFun visé ci-dessus.
- **Points de non-retour métier** : « On **supprime définitivement** les tâches faites, ou on les
  **archive** ? » (≠ « hard delete ou soft delete ? »).
- **Mise en ligne** : « On publie *maintenant* pour de vrais utilisateurs, ou ça reste un test ? »

> Test de formulation : si la question contient un mot que le PO devrait googler, **c'est un défaut,
> pas une question**. L'agent tranche, annonce, avance.

## Annonce type (au lieu d'une question)

> « J'ai choisi *[défaut]* parce que *[raison métier en une ligne]*. C'est réversible ; dis-moi si
> tu préfères autre chose, sinon je continue. » — puis **l'agent continue sans attendre**.
