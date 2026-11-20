# ADR-001 — Authentification et cloisonnement par propriétaire

- **Statut** : proposé, **à valider par le superviseur**. Le cadrage est le sien (2026-11-18 : cookie et jeton porteur, jetons opaques hachés, Argon2id, inscription pilotée, aucun compte par migration) ; les amendements et le détail tranchés ici ne le sont pas encore : empreinte HMAC avec clé d'instance au lieu de SHA-256 nu, préfixe `__Host-`, paramètres d'Argon2, todos antérieurs sans propriétaire, limite d'essais par courriel
- **Date** : 2026-11-18
- **Issues** : #33 (cette pile), #31 (issue sœur PHP, mêmes cinq scénarios)
- **Couches touchées** : Domaine, Application, Adapter (persistance ×2, hachage, aléa), Http (FastAPI et Starlette), contrat OpenAPI, harnais

## Contexte

Le kit n'avait ni compte, ni identité, ni propriétaire : tout todo était visible de tout appelant.
Quiconque partait du kit pour une application métier devait écrire en premier la couche la plus
risquée, sans modèle ni gate.

Contraintes qui pèsent sur la décision :

- le front îlots est servi **par l'application, depuis la même origine que l'API** ;
- l'API est aussi appelée par des **clients qui ne sont pas des navigateurs** (le smoke e2e, un
  script, une autre application) ;
- la cible de déploiement est un **hébergement mutualisé** (1 CPU, 1 Go, un seul processus arrêté
  après 30 minutes d'inactivité, plusieurs processus sous uWSGI) : rien ne peut vivre en mémoire
  du processus, et le hachage ne doit pas saturer la machine ;
- le domaine et l'application restent **purs** (gate H1) ;
- les deux adaptateurs HTTP et les deux adaptateurs de persistance doivent être protégés de la
  même façon.

## Décision

### 1. Deux mécanismes d'identité, un par usage

| | Session par **cookie** | **Jeton porteur** |
|---|---|---|
| Pour qui | le front îlots, dans un navigateur | les clients d'API |
| Obtention | `POST /api/auth/login` | `POST /api/auth/token` |
| Transport | cookie `__Host-todo_session` : `HttpOnly`, `Secure`, `SameSite=Strict`, `Path=/`, sans `Domain` | en-tête `Authorization: Bearer <jeton>` |
| Durée (réglable) | 12 heures (`TODO_SESSION_TTL`) | 30 jours (`TODO_BEARER_TTL`) |
| Fin | `POST /api/auth/logout`, ou échéance | idem |

Un cookie est une identité **ambiante** : le navigateur le joint sans que la page le demande.
Trois barrières contre la requête forgée depuis un autre site : `SameSite=Strict` ; le contrôle
de l'en-tête **`Origin`** sur toute méthode non sûre (`POST`, `PUT`, `PATCH`, `DELETE`)
authentifiée par cookie — absent ou étranger, la requête est refusée (403) ; aucune écriture par
`GET`. L'origine attendue est `TODO_PUBLIC_URL`, schéma compris ; elle ne se déduit pas du schéma
vu par l'application, qui est faux derrière le frontal de l'hébergeur. Hors développement, la
variable est **exigée** : sans elle l'application refuse de démarrer, plutôt que de se replier
sur une comparaison à l'hôte de la requête, qui ignore le schéma. Le jeton porteur, lui, n'est pas
ambiant : il n'est pas soumis à ce contrôle.

Le préfixe `__Host-` interdit à un autre site du même domaine parent (le cas d'une adresse
`<compte>.<hébergeur>`) de poser un cookie de session à notre place. En développement
(`TODO_ENV=development`, http), le cookie s'appelle `todo_session` et n'a pas l'attribut `Secure`.

Les deux types ne sont **pas interchangeables** : la valeur d'un cookie présentée comme jeton
porteur est refusée, et inversement.

### 2. Jetons opaques, hachés en base, plutôt qu'un JWT

Session et jeton porteur sont la même chose : **32 octets tirés du générateur du système**
(`secrets.token_urlsafe`), remis une fois à l'appelant, dont seule l'**empreinte** est conservée,
dans une table unique `auth_tokens` (colonne `kind` : `session` ou `bearer`), avec son échéance.

- **Révocable tout de suite** : la déconnexion supprime la ligne. Un JWT reste valide jusqu'à son
  échéance, sauf à tenir une liste de révocation — c'est-à-dire la même table, en plus compliqué.
- **Rien à signer, rien à valider** : pas d'algorithme à choisir, pas de confusion d'algorithme,
  pas de clé de signature dont la fuite permettrait de fabriquer n'importe quelle identité.
- **Coût** : une lecture indexée par requête. Le kit ouvre déjà une connexion par requête.

L'empreinte est un **HMAC-SHA-256** avec la clé de l'instance (`TODO_SECRET_KEY`), là où la
proposition de départ disait SHA-256 nu. Amendement et raison : un jeton de 256 bits n'a pas
besoin d'un hachage lent, et SHA-256 suffirait pour lui ; mais la même empreinte sert aux
**essais de connexion** (point 4), dont le sujet est un courriel, donc devinable. Avec la clé,
une copie de la base ne permet ni de retrouver quels courriels ont été essayés, ni de fabriquer
une empreinte valide. Changer la clé révoque d'un coup tous les jetons : c'est le geste
d'urgence. Hors développement, l'application **refuse de démarrer** sans une clé de 32
caractères au moins. La recherche se fait par l'empreinte (clé primaire) : la valeur claire
n'est jamais comparée en base, il n'y a donc pas de comparaison à durée variable à protéger.

### 3. Mots de passe : Argon2id

Bibliothèque **`argon2-cffi` 25.1.0** — licence MIT, liaison de l'implémentation de référence
d'Argon2 ; relevé sur PyPI le 2026-11-18 : 18 versions, la dernière le 2025-06-03 ; sa dépendance
`argon2-cffi-bindings` fournit des roues binaires pour Python 3.12 sur glibc 2.36 (vérifié dans
l'image de la cible et dans la répétition du déploiement).

- Paramètres : **m = 19 Mio, t = 2, p = 1**, le plancher recommandé par l'OWASP. Le profil par
  défaut de la bibliothèque (64 Mio, 4 fils) est plus dur, mais quelques connexions simultanées
  satureraient une offre à 1 CPU et 1 Go. Le hachage porte ses paramètres : on peut les durcir
  sans casser les comptes existants.
- Vérification en **temps constant** (celle de la bibliothèque).
- Mot de passe : 12 à 128 caractères. La borne haute évite de faire hacher un texte démesuré.
- Le clair n'existe que le temps de la requête : jamais stocké, jamais journalisé, jamais
  renvoyé — y compris dans une erreur de validation, que l'adaptateur FastAPI réécrit pour que
  Pydantic ne recopie pas la valeur fautive.

### 4. Ne pas renseigner un attaquant

- « Compte inconnu » et « mauvais mot de passe » : **même code (401), même corps**, et **même
  travail** — un compte inconnu coûte un hachage factice, pour ne pas se trahir par la durée.
- **Limite d'essais** : 5 échecs en 15 minutes pour un même courriel ; au-delà, 429, bon mot de
  passe compris, jusqu'à ce que la fenêtre glisse. Une connexion réussie remet le compteur à
  zéro. Les essais sont **en base** (`login_attempts`), pas en mémoire : la limite tient avec
  plusieurs processus et survit à l'arrêt du site.
- **La limite tient sous des requêtes simultanées.** Chaque essai est **réservé avant toute
  vérification** : enregistré et compté dans une seule transaction, sérialisée par sujet (verrou
  consultatif de transaction), il reçoit son rang ; au-delà du seuil il est refusé sans hachage
  et retiré, pour ne pas prolonger le verrouillage. La première écriture comptait, hachait, puis
  enregistrait l'échec : N connexions lancées ensemble lisaient toutes un compteur à zéro
  (relecture de sécurité du 2026-11-18). Le gate `integration` lance douze essais ensemble :
  cinq vérifications, sept refus, sur CQRS et sur l'ORM.
- **Bornes avant tout travail.** À la connexion, un courriel ou un mot de passe trop long ou non
  stockable (octet NUL, demi-codet isolé) reçoit le 401 habituel **sans hachage ni accès à la
  base**. Un corps de plus de 16 Kio est refusé (413) et un corps sans longueur annoncée aussi
  (411), avant toute lecture, par l'enveloppe commune aux deux adaptateurs. Un corps n'est
  accepté qu'annoncé en `application/json`.
- **L'identité d'abord.** Sur une route protégée, un appelant sans identité reçoit 401 quel que
  soit son corps (JSON mal formé compris), sur les deux adaptateurs.
- Un todo d'autrui et un identifiant inexistant : **même 404, même corps**.
- Une erreur interne (base injoignable) : **500 générique**, sans trace ni message du pilote.

### 5. Création de compte

- Route `POST /api/auth/register`, pilotée par `TODO_REGISTRATION=open|closed`. **`closed` par
  défaut**, et dans le `.env` qu'écrit `deployer.sh` : une instance n'ouvre pas l'inscription
  sans que son porteur l'ait décidé.
- Commande `python -m app.accounts create <courriel>` : mot de passe lu sur l'entrée standard,
  ou tiré et affiché une seule fois. Elle passe par le **même cas d'usage** que la route.
- Commande `python -m app.accounts revoke <courriel>` : révoque toutes les sessions et tous les
  jetons d'un compte (appareil perdu, jeton divulgué).
- **Aucun compte posé par migration** (le gate `verify` le vérifie) : un compte de démonstration
  à mot de passe connu finit en production.

### 6. Architecture

```
Domaine      identity/ : CurrentUser (objet-valeur), Account, AccessToken, règles, exceptions,
             ports AccountRepository, PasswordHasher, TokenGenerator, TokenRepository, LoginAttempts
             todo/     : Todo porte owner_id ; TodoRepository prend owner_id à CHAQUE opération
Application  identity/ : RegisterAccount, LogIn, ResolveIdentity, LogOut, GetAccount
             todo/     : CreateTodo, ListTodos, GetTodo, ToggleTodo, DeleteTodo — execute(current_user, …)
Adapter      identity/ : Argon2PasswordHasher, RandomTokenGenerator, magasins CQRS et ORM
             todo/     : CqrsTodoRepository, OrmTodoRepository (chaque requête filtre le propriétaire)
Http         common.py : résolution de l'identité, contrôle d'origine, cookie, erreurs → codes
             api.py (FastAPI) et starlette_app.py (Starlette) : mêmes routes, même protection
             hardening.py : en-têtes de sécurité et erreur 500 générique, autour des deux
```

- **Le port d'identité est `CurrentUser`** (`app/domain/identity/current_user.py`), le même nom
  que dans kit-php (#31). Différence de forme, assumée : ici c'est un objet-valeur déjà résolu,
  que l'adaptateur HTTP établit puis passe aux cas d'usage en premier argument (`id()` ne lève
  jamais) ; dans kit-php c'est une interface implémentée par l'adaptateur, dont `id()` lève quand
  aucune identité n'est établie. Aucun `Depends` ni `Security` ne descend dans l'application.
- **Le cloisonnement est dans le port de persistance**, pas seulement dans la couche HTTP :
  `find(owner_id, id)`, `find_all(owner_id)`, `save(owner_id, todo)`, `delete(owner_id, id)`.
  Un adaptateur ne sait pas lire, modifier ni supprimer le todo d'un autre compte ; `save` ne
  réattribue jamais un identifiant existant. Le gate `integration` appelle le port directement,
  sans cas d'usage, pour le prouver sur CQRS et sur l'ORM.
- **Le propriétaire ne vient jamais de la requête** : aucun schéma d'entrée ne le porte, et la
  désérialisation est stricte (champ inconnu → 422).
- **Migration réversible** `0002_accounts_and_owner` : tables `accounts`, `auth_tokens`,
  `login_attempts`, colonne `todos.owner_id`. La migration `0001` n'est pas modifiée (sa somme
  de contrôle est tracée).
- **Contrat** : `openapi/todos.openapi.json` décrit `bearerAuth` et `sessionCookie`, et les
  exige sur chaque opération des todos ; le client généré `api.ts` les porte
  (`securitySchemes`, `operationSecurity`) et applique le jeton porteur quand on lui en donne un.

### 7. Todos antérieurs à la migration

Un todo créé avant `0002` n'a pas de propriétaire. La colonne `owner_id` est donc **nullable en
base**, et ces todos restent là, **visibles de personne**. `python -m app.accounts adopt
<courriel>` les rattache à un compte. L'application, elle, n'écrit jamais de todo sans
propriétaire : c'est un invariant du domaine (`Todo` refuse un `owner_id` vide). Supprimer ces
lignes dans la migration aurait détruit des données sans retour ; les attribuer d'office au
premier compte créé aurait donné les données de tous à un seul.

## Ce qui est écarté

| Option | Pourquoi non |
|---|---|
| **JWT** (signé, sans état) | Non révocable sans liste de révocation ; clé de signature à protéger ; algorithmes à verrouiller. Le « sans état » ne rapporte rien ici : la base est déjà lue à chaque requête. |
| **Cookie seul** | Un client d'API devrait imiter un navigateur (cookie, `Origin`). |
| **Jeton porteur seul**, gardé par le front dans `localStorage` | Lisible par tout script de la page : une seule faille XSS livre le jeton. Le cookie `HttpOnly` ne l'est pas. |
| **Jeton anti-CSRF** (double envoi, jeton synchronisé) | `SameSite=Strict` et le contrôle d'`Origin` couvrent le besoin d'une application servie depuis une seule origine, sans état de plus à tenir. À revoir si le front passe sur un autre site que l'API. |
| **bcrypt, scrypt, PBKDF2** | Argon2id est la recommandation actuelle (OWASP, RFC 9106) et résiste mieux aux attaques matérielles ; bcrypt tronque à 72 octets. |
| **`passlib`** | Plus de version depuis le 2020-10-08 (relevé sur PyPI le 2026-11-18). |
| **Sessions en mémoire** du processus | Perdues à chaque arrêt du site (30 minutes d'inactivité chez l'hébergeur), et fausses avec plusieurs processus (uWSGI). |
| **Signature de cookie** (`itsdangerous`, `SessionMiddleware`) | Une session signée côté client ne se révoque pas. |
| **Comptes de démonstration par migration** | Mot de passe connu, en production le jour où la migration y passe. |
| **Limite d'essais par adresse IP** | Derrière le frontal d'un hébergeur, l'adresse vue est celle du frontal ou un en-tête falsifiable. |

## Conséquences

- **Une lecture de plus par requête** (le jeton), sur la connexion déjà ouverte.
- **Deux nouvelles dépendances d'exécution** : `argon2-cffi` (MIT), et ses liaisons compilées, à
  livrer pour la bonne version de Python — `deploiement/alwaysdata/construire.sh` s'en charge.
- **Un secret d'instance** (`TODO_SECRET_KEY`), tiré sur le serveur par `deployer.sh`.
- **La limite d'essais est par courriel** : elle arrête la recherche du mot de passe d'un compte,
  pas l'essai d'un même mot de passe sur beaucoup de comptes, et elle permet à un tiers de
  verrouiller un compte un quart d'heure. Un projet exposé ajoutera une limite au niveau du
  frontal ou un délai progressif. Non traité ici.
- **L'inscription ouverte révèle l'existence d'un courriel** (409 « déjà utilisé »). C'est le
  prix d'une inscription sans confirmation par courriel ; elle est fermée par défaut.
- **Non traité** : confirmation du courriel, mot de passe oublié, changement de mot de passe,
  second facteur, liste des sessions, rôles. Les ports sont là pour les accueillir.
- **Rupture de contrat** : toutes les routes des todos exigent une identité ; le contrat passe en
  version 2.0.0. Le front affiche un formulaire de connexion quand l'API répond 401.

## Preuves

| Scénario de #33 | Gate |
|---|---|
| Un utilisateur ne voit que ses todos | `e2e` (FastAPI et Starlette), `integration` (CQRS et ORM), `unit` |
| Un appel sans authentification est refusé, aucun cas d'usage exécuté | `e2e` ; `unit` (`tests/http`, compteur d'accès aux todos) |
| Le todo d'autrui ne révèle pas son existence (404 identique) | `e2e`, `integration`, `unit` |
| Le propriétaire ne vient jamais de la requête (422) | `e2e`, `unit` |
| Mots de passe ni stockés ni journalisés en clair | `e2e` (table et journal du serveur), `integration` |
