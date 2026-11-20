# Déployer `kit-fastapi` sur un hébergement infogéré (alwaysdata)

Ce guide amène le kit sur un hébergement **que l'on n'administre pas** : l'hébergeur tient le
système, la base et le frontal ; il reste au porteur l'application, sa configuration et ses
données. Le pourquoi et les règles générales sont dans
[`skills/deploiement-heberge-infogere.md`](../../../skills/deploiement-heberge-infogere.md) ; ce
guide ne donne que les gestes propres au kit.

Dans tout le guide, `<compte>` est le nom du compte chez l'hébergeur, `<instance>` le nom que vous
donnez à cette instance du kit, `<adresse>` l'adresse publique du site.

> **État des preuves.** Ce qui suit a été joué en **répétition locale** (gate `deploiement`,
> `bash harness/repeter-deploiement.sh`) contre une cible jetable qui imite l'hébergeur, à trois
> exceptions près, listées en fin de guide (la création d'un site du montage B par le script, la
> désignation du site par `ALWAYSDATA_SITE`, l'attente du certificat d'un site neuf). Les faits
> sur l'hébergeur viennent de sondes en lecture seule du 2026-11-18. **Un déploiement réel a été
> fait le 2026-11-18**, dans les deux montages, sur un site et une base d'essai : les huit
> combinaisons y ont passé le smoke contre l'adresse publique (voir « Combinaisons prouvées »).
> Ce qui reste à montrer est marqué « non prouvé chez l'hébergeur ». C'est le cas de la création
> de la base, de son utilisateur et du site **par le script**, et du retour arrière par
> `revenir.sh` : prouvés en répétition locale seulement, contre un faux serveur d'API.

## Quel montage choisir

FastAPI et Starlette parlent **ASGI**. L'hébergeur propose deux types de site qui peuvent les servir.

| | **A — programme utilisateur** | **B — site Python (uWSGI)** |
|---|---|---|
| Ce que lance l'hébergeur | `lancer.sh`, qui se remplace par **uvicorn** | **uWSGI**, qui charge `wsgi.py` |
| Protocole | ASGI natif, le même qu'en local et dans les gates | WSGI, par le pont **`a2wsgi`** (ASGI→WSGI) |
| Cycle de vie ASGI (`lifespan`), tâches de fond | oui | **non** (voir les limites) |
| WebSocket | oui | **non** |
| Réponses en flux | oui | oui |
| Processus | un | plusieurs, gérés par uWSGI |
| Migrations au déploiement | `lancer.sh`, avant uvicorn | `wsgi.py`, au chargement |
| Ce qu'il faut régler chez l'hébergeur | une commande | l'application, la version de Python, les fils de uWSGI |

**Choisissez A.** C'est le montage le plus fidèle au local : même serveur, même protocole, aucune
pièce de plus entre la plateforme et l'application, et rien de ce que l'application sait faire
n'est perdu. Le montage B est **prouvé et utilisable pour le kit tel qu'il est** (des requêtes et
des réponses, rien d'autre), mais il ajoute un pont dont dépend chaque requête et retire le cycle
de vie ASGI et les WebSocket. Ne prenez B que si vous tenez à ce que l'hébergeur gère lui-même
les processus Python (plusieurs processus, rechargement), et seulement tant que votre application
n'a besoin de rien de ce que le pont ne transmet pas.

## Ce que l'hébergeur impose, et ce que le kit en fait

| Constat (sondes du 2026-11-18, offre mutualisée) | Réponse du kit |
|---|---|
| Un site « programme utilisateur » lance une commande qui doit écouter sur l'adresse et le port fournis (`IP` ou `HOST`, `PORT` ; adresse IPv6 possible) | `lancer.sh` les traduit pour uvicorn, crochets d'une adresse IPv6 retirés, puis `exec` |
| Debian 12 (glibc 2.36). Le Python du shell est en 3.13 ; l'hébergeur fournit aussi un Python **3.12** à un chemin fixe | Les dépendances sont préparées pour 3.12 ; `lancer.sh` appelle ce Python par son chemin, jamais celui du shell |
| Les règles du serveur SSH interdisent builds, installations lourdes et processus longs | **Le serveur n'installe ni ne compile rien** : `construire.sh` installe les dépendances sur le poste, dans une image Debian 12 + Python 3.12, depuis le verrou `requirements.lock` (versions et empreintes) ; elles partent dans l'archive |
| PostgreSQL géré : login **sans privilège** (ni superutilisateur, ni `BYPASSRLS`, ni création de rôle), noms préfixés par le compte, connexion directe sur le port 5432 | Tous les gates du kit se jouent avec un tel login ; `integration` échoue s'il est privilégié |
| Le site est arrêté après 30 minutes sans requête, relancé à la suivante ; une seule instance | Le kit n'a ni tâche de fond ni état en mémoire : sessions, jetons et limite d'essais sont en base |
| Aucun frontal n'ajoute d'en-tête de sécurité | L'application les émet elle-même sur toutes ses réponses (`app/http/hardening.py`) |
| uWSGI 2.0.x est fourni pour les sites Python | `wsgi.py` et le pont `a2wsgi` (montage B) |

## Avant le premier déploiement (une fois)

Dans tous les cas, il faut déjà un accès SSH au compte et une adresse `<adresse>` qui mène chez
l'hébergeur : le script ne touche ni au DNS ni aux clés SSH. Pour le reste, deux voies.

### Avec le jeton d'API : rien à créer dans l'administration

Rangez le jeton d'API de l'hébergeur dans le fichier `.env` **du kit, sur votre poste** (ignoré par
git), sous le nom `ALWAYSDATA_TOKEN`, ou passez-le par la variable d'environnement du même nom (elle
passe avant le fichier). Le script ne l'affiche pas et ne le passe jamais en argument.

À son étape 0, avant tout envoi, le script lit alors l'état du compte chez l'hébergeur et **crée ce
qui manque, après l'avoir annoncé** dans sa sortie :

- **l'utilisateur de base `<compte>_<instance>`.** Son mot de passe est tiré **sur le serveur**
  (48 chiffres hexadécimaux) et rangé dans `~/<instance>/.pgpass.gen`. Il rejoint l'API par un
  tube, de la sortie de `ssh` à l'entrée de l'appel : il traverse donc le poste, mais n'y est ni
  affiché, ni écrit dans un fichier, ni passé en argument d'une commande ;
- **la base PostgreSQL du même nom**, avec tous les droits pour ce seul utilisateur ;
- **le site**, nommé `<instance>`, pour `<adresse>`, HTTPS forcé. Son type suit `KIT_MONTAGE` :
  - `KIT_MONTAGE=A` (défaut) — « programme utilisateur », commande
    `/home/<compte>/<instance>/lancer.sh`, répertoire de travail le dossier de l'instance ;
  - `KIT_MONTAGE=B` — « Python » (uWSGI), application `wsgi.py` du dossier de l'instance, même
    répertoire de travail, Python 3.12, réglage supplémentaire de uWSGI `enable-threads = true`.

`KIT_MONTAGE` ne sert qu'à cette création : il ne change pas le type d'un site qui existe déjà.

La base et son utilisateur sont reconnus à leur nom, le site à son **adresse publique**, quel que
soit son nom (il a pu être créé à la main). Le script **ne modifie ni ne supprime jamais** une
base, un utilisateur ou un site existants ; rejoué, il les retrouve et ne recrée rien. Ce qu'il
crée porte l'annotation « créé par deployer.sh pour `<instance>` ».

Deux cas où il s'arrête plutôt que de deviner, toujours avant tout envoi :

- l'utilisateur de base existe chez l'hébergeur, mais ni son mot de passe (`.pgpass.gen`) ni le
  `.env` de l'instance ne sont sur le serveur : le script ne change pas un mot de passe qu'il n'a
  pas posé. Rangez-le dans `~/<instance>/.pgpass.gen` (droits 600), puis rejouez ;
- le `.env` de l'instance est sur le serveur, mais l'utilisateur de base n'existe pas chez
  l'hébergeur : vérifiez le compte et le nom de l'instance.

**Niveau de preuve.** Ces créations par le script ne sont prouvées qu'en **répétition locale**,
contre un faux serveur d'API écrit pour le kit (`harness/faux-hebergeur.py`), et pour le seul
montage A : **non prouvé chez l'hébergeur**. Le 2026-11-18, les mêmes appels (création de
l'utilisateur, de la base, du site ; redémarrage) ont été faits chez l'hébergeur **à la main**,
avec les mêmes corps, pas par le script.

### Sans jeton : trois gestes à la main

1. **La base.** Dans l'administration de l'hébergeur, créez une base PostgreSQL `<compte>_<instance>`
   et un utilisateur du même nom, avec tous les droits sur cette base et sur elle seule.
2. **Son mot de passe, sur le serveur.** Connecté en SSH, tirez-le et rangez-le là où le script
   l'attend, puis reportez cette valeur dans le formulaire de l'utilisateur de la base :

   ```sh
   umask 077 && mkdir -p ~/<instance> && openssl rand -hex 24 > ~/<instance>/.pgpass.gen
   ```

   Le script lit ce fichier une seule fois, écrit `.env`, puis le supprime. Le mot de passe ne
   doit contenir que des lettres, des chiffres et `_ . ~ + / = -`.
3. **Le site**, selon le montage :
   - **A** — type « programme utilisateur » : commande `/home/<compte>/<instance>/lancer.sh`,
     répertoire de travail `/home/<compte>/<instance>`.
   - **B** — type « Python » : application `/home/<compte>/<instance>/wsgi.py`, répertoire de
     travail `/home/<compte>/<instance>`, Python **3.12**, **sans environnement virtuel** (les
     dépendances arrivent préparées, `wsgi.py` les ajoute au chemin), et dans les réglages
     supplémentaires de uWSGI : `enable-threads = true`.

Sans jeton, sur une instance **jamais préparée** (ni `.env` ni `.pgpass.gen` dans son dossier, sur
le serveur), le script **s'arrête avant tout envoi** et rappelle ces trois gestes. Dès que l'un de
ces deux fichiers est là, il livre sans rien créer : il suppose la base et le site créés à la
main, sans le vérifier. Le redémarrage vous revient alors (voir plus bas).

Les deux voies se combinent : une base et un site créés à la main sont retrouvés tels quels par le
script muni du jeton, qui s'en sert alors pour redémarrer le site.

## Déployer, puis redéployer

```sh
bash harness/repeter-deploiement.sh        # d'abord en local : la répétition doit être verte
bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> https://<adresse>
```

Pour que le script crée un site du montage B, ajoutez `KIT_MONTAGE=B` devant la commande.

Le script fait cinq choses, toujours les mêmes, au premier passage comme aux suivants :

0. **s'assure que la base, son utilisateur et le site existent** chez l'hébergeur : avec le jeton
   d'API il crée ce qui manque après l'avoir annoncé, sans jeton il s'arrête si l'instance n'a
   jamais été préparée (voir « Avant le premier déploiement »). Rien n'est envoyé avant ;
1. **prépare** la livraison sur le poste (`construire.sh`) : `app/`, `database/`, `public/`,
   `deps/` (dépendances d'exécution verrouillées) et les deux points d'entrée `lancer.sh` et
   `wsgi.py`, dans une archive ;
2. **l'envoie** sous un autre nom ;
3. sur le serveur, par une seule commande courte : déplie la version dans `versions/<date>-<empreinte>/`,
   vérifie que les modules compilés se chargent avec le Python 3.12 du serveur, crée `.env`
   **s'il n'existe pas** (écrit à part puis renommé ; jamais réécrit ensuite), pose le témoin
   `.migrer` **adressé à la nouvelle version**, puis **bascule** — le lien `courant` change de
   cible par renommage atomique, le lien `precedent` garde la version d'avant. `lancer.sh` et
   `wsgi.py` sont des liens vers ceux de la version courante : lanceur, pont, code et dépendances
   changent **ensemble**. Si le site se réveille pendant le déploiement, il lance l'ancienne
   version entière (qui laisse le témoin en place) ou la nouvelle (qui migre d'abord) ;
4. **redémarre le site** : les migrations **manquantes** sont jouées à ce démarrage-là, et à lui
   seul (par `lancer.sh` en A, par `wsgi.py` en B). Une migration déjà passée n'est jamais
   rejouée ; si son fichier a changé depuis, ou si la migration échoue, le témoin reste, le site
   ne démarre pas, et le script le signale.

Si l'adresse passée au script diffère de `TODO_PUBLIC_URL` dans le `.env` du serveur, le script
**prévient** sans réécrire : corrigez la ligne à la main.

Le redémarrage se fait **par l'API de l'hébergeur**, sur le site que le script retrouve par son
adresse (ou qu'il vient de créer) : `ALWAYSDATA_SITE` n'est plus nécessaire. Il reste possible
(`ALWAYSDATA_SITE=<numéro du site>`) pour désigner un autre site que celui qui sert l'adresse ;
dans ce cas le script ne crée aucun site (la base et son utilisateur, eux, sont toujours créés
s'ils manquent). **Sans jeton d'API**, le script ne redémarre rien : redémarrez le site depuis
l'administration après son passage.

Après le redémarrage, le script attend que `https://<adresse>/api/health` réponde, par des essais
peu nombreux et espacés (trente, à trois secondes d'intervalle) : le frontal de l'hébergeur bloque
une adresse qui le sonde en rafale. Pour un site **qu'il vient de créer**, il laisse d'abord
180 secondes à l'émission du certificat (`KIT_ATTENTE_CERTIFICAT` pour changer), puis fait vingt
essais à quinze secondes d'intervalle : pendant les minutes qui suivent la création d'un site,
l'hébergeur présente un certificat générique que le client refuse. Un site créé à la main juste
avant le passage n'a pas ce délai : si le contrôle final échoue, attendez, puis rejouez le script.

Sur le serveur, après un déploiement :

```
/home/<compte>/<instance>/
  lancer.sh -> courant/lancer.sh  wsgi.py -> courant/wsgi.py     points d'entrée (liens)
  .env                            réglages et secrets, droits 600, jamais réécrit
  courant -> versions/<id>        version servie        precedent -> versions/<id d'avant>
  versions/<id>/{app,database,public,deps,lancer.sh,wsgi.py,VERSION}
```

### Le fichier `.env` du serveur

Créé au premier passage, droits 600 ; `lancer.sh` et `wsgi.py` refusent de démarrer s'il est
lisible par d'autres. Il contient la connexion à la base (`DB_HOST`, `DB_PORT`, `DB_NAME`,
`DB_USER`, `DB_PASSWORD`), la clé de l'instance `TODO_SECRET_KEY` (**tirée sur le serveur** par
`openssl rand -hex 32`), `TODO_PUBLIC_URL` (l'adresse publique, qui sert au contrôle d'origine
des requêtes à cookie ; **exigée** : sans elle l'application refuse de démarrer),
`TODO_REGISTRATION='closed'`, et les deux adaptateurs :

```sh
TODO_HTTP='fastapi'        # ou 'starlette'
TODO_PERSISTENCE='cqrs'    # ou 'orm'
```

Pour changer d'adaptateur, modifiez ces deux lignes sur le serveur, puis redémarrez le site.
Si l'adresse publique change, modifiez `TODO_PUBLIC_URL` de la même façon.

### Les comptes

L'inscription est **fermée** sur un déploiement. Les comptes se créent sur le serveur, par une
commande courte ; le mot de passe est lu sur l'entrée standard, ou tiré et affiché une seule fois
si la commande est lancée depuis un terminal :

```sh
~/<instance>/lancer.sh outil app.accounts create <courriel>
~/<instance>/lancer.sh outil app.accounts revoke <courriel>   # révoque ses sessions et ses jetons
```

## Prouver le déploiement

Créez deux comptes pour le smoke (commande ci-dessus), puis, depuis le poste :

```sh
E2E_PROFIL=public E2E_BASE_URL=https://<adresse> \
E2E_EMAIL_A=<courriel A> E2E_PASSWORD_A=<…> E2E_EMAIL_B=<courriel B> E2E_PASSWORD_B=<…> \
  bash harness/e2e-smoke.sh
```

Le smoke ne remet rien à zéro : il supprime les todos qu'il crée et révoque ses jetons. Il joue le
parcours de référence, l'identité et le cloisonnement, la session par cookie, vérifie que quatre
fichiers hors de `public/` ne sont pas servis et que les en-têtes de sécurité sont là.

**Contre l'hébergeur, toujours `E2E_PROFIL=public`, et un seul passage.** Ce profil est allégé
(70 vérifications) et espacé (une seconde entre deux requêtes, `E2E_PAUSE` pour
changer). Le parcours complet envoie en quelques secondes des dizaines de refus : 401, 404, chemins
comme `/.env`, essais de connexion ratés, corps de 20 Ko. Le 2026-11-18, après neuf parcours
complets enchaînés depuis le même poste (1 179 requêtes en moins d'une heure, dont les deux tiers de refus),
le frontal de l'hébergeur a cessé d'accepter les connexions de l'adresse du poste, **pour tous les
sites du compte**. La règle exacte et sa durée ne sont pas connues. Les entrées hostiles, la
limite d'essais et les chemins détournés restent prouvés par la répétition locale, qui joue les
deux profils.

### Combinaisons prouvées

Répétition locale du **2026-11-18** (gate `deploiement`), puis déploiement réel du même jour :
parcours complet du smoke (108 vérifications) contre l'adresse publique, en HTTPS.

| Montage | HTTP | Persistance | Smoke e2e (répétition locale) | Chez l'hébergeur |
|---|---|---|---|---|
| A | fastapi | cqrs | 🟢 | 🟢 2026-11-18 |
| A | fastapi | orm | 🟢 | 🟢 2026-11-18 (au second essai, voir ci-dessous) |
| A | starlette | cqrs | 🟢 | 🟢 2026-11-18 |
| A | starlette | orm | 🟢 | 🟢 2026-11-18 |
| B | fastapi | cqrs | 🟢 | 🟢 2026-11-18 |
| B | fastapi | orm | 🟢 | 🟢 2026-11-18 |
| B | starlette | cqrs | 🟢 | 🟢 2026-11-18 |
| B | starlette | orm | 🟢 | 🟢 2026-11-18 |

Chez l'hébergeur : Python 3.12 du système et dépendances préparées sur le poste (modules compilés
chargés), base PostgreSQL gérée avec un login sans privilège, montage B sous uWSGI 2.0.31. Le
script joué une seconde fois n'a rejoué aucune migration ni réécrit `.env`. Le site et son adresse
d'essai ont été supprimés après le smoke.

**Défaut trouvé par ce déploiement, corrigé depuis.** Un essai sur huit, le refus d'un corps trop
gros (413) n'est jamais arrivé au client : l'application répondait puis fermait la connexion sans
lire le corps, pendant que le frontal l'écrivait encore, et le frontal perdait la réponse. En
local, un client qui envoie le corps après les en-têtes perdait la réponse à chaque fois.
L'application lit maintenant le corps refusé avant de répondre (dans la limite de 1 Mio et de cinq
secondes ; au-delà elle répond sans lire). La correction est prouvée en local (`tests/http`),
**pas encore rejouée chez l'hébergeur**.

Dans la répétition, l'API de l'hébergeur est tenue par un **faux serveur local**
(`harness/faux-hebergeur.py`) ; aucun appel ne part vers l'hébergeur réel. Elle y montre : sans
jeton, sur une instance jamais préparée, l'arrêt avant tout envoi et sans appel à l'API ; au
premier passage, trois créations (utilisateur, base, site du montage A), annoncées avant ; au
second, aucune de plus ; le redémarrage par l'API sur le site retrouvé par son adresse ; sans
jeton, sur une instance déjà préparée, une livraison sans création ni redémarrage ; `revenir.sh`
refusé sans version précédente, puis joué aller et retour ; ni mot de passe de la base, ni jeton
d'API dans les sorties des scripts et le journal du faux serveur ; `hebergeur.sh`, `hebergeur.py`
et `harness/faux-hebergeur.py` identiques dans les trois kits. Ce faux serveur prouve que le
script tient son contrat ; il ne prouve pas l'hébergeur lui-même.

Dans la même répétition : le script est joué **deux fois** (au second passage, aucune migration
rejouée, données intactes, `.env` inchangé, version précédente gardée) ; le site écoute en
**IPv6** sur l'adresse et le port fournis ; le montage B tourne sous uWSGI 2.0.30 avec deux
processus et quatre fils ; le programme est arrêté par `SIGTERM` puis relancé, et le parcours
repasse.

## Montage B : ce que le pont ne transmet pas

Chaque ligne est **essayée** par `harness/pont/essayer.sh`, joué dans la cible par le gate
`deploiement` (uWSGI 2.0.30, `a2wsgi` 1.10.10, Python 3.12) : une application-sonde exerce le
cycle de vie, une tâche de fond, un flux, un WebSocket, et le gate vérifie que ce tableau dit ce
que l'essai montre.

| Sujet | Résultat de l'essai | Conséquence |
|---|---|---|
| **Cycle de vie ASGI** (`lifespan` : démarrage, arrêt) | **Non transmis** : le code de démarrage ne s'exécute jamais | Rien ne doit dépendre du `lifespan`. Le kit n'en a pas ; ce qui doit se faire au démarrage se fait à l'import (`wsgi.py` y joue les migrations) |
| **Tâche de fond** lancée par le `lifespan` | **Ne tourne pas** (elle n'est jamais lancée) | Pas de tâche permanente dans ce montage : passez par les tâches planifiées de l'hébergeur |
| **Tâche après réponse** (`BackgroundTask`) | S'exécute | Utilisable, dans le temps d'une requête |
| **Réponse en flux** | Transmise **au fil de l'eau** (quatre morceaux reçus à 0,5 s d'intervalle) | Utilisable. Le frontal de l'hébergeur peut encore la retenir : non prouvé chez l'hébergeur |
| **WebSocket** | **Refusé** : la demande reçoit un 404, jamais de `101` | Pas de WebSocket dans ce montage : prenez A |
| **Fils de uWSGI** (`enable-threads`) | Dans la répétition, le pont répond et les fils de l'application avancent **avec ou sans** cette option (uWSGI 2.0.30 du paquet `pyuwsgi`). Le uWSGI de l'hébergeur n'a pas été essayé : **non prouvé chez l'hébergeur** | Le pont vit dans un fil : mettez `enable-threads = true` par prudence, c'est le réglage que la documentation de uWSGI demande dès qu'une application lance des fils |
| **Dédoublement des processus** (fork) | Un pont créé à l'import, puis dédoublé, **ne répond plus** (délai dépassé) | `wsgi.py` crée le pont **dans chaque processus**, à sa première requête. Si vous écrivez le vôtre, faites de même ou réglez `lazy-apps` |
| **Arrêt** (`SIGTERM`) | uWSGI s'arrête le plus souvent en une ou deux secondes ; **parfois en 62 s** (relevé deux fois sur une cinquantaine d'arrêts dans les répétitions du 2026-11-18) : un processus de travail ne rend pas la main et uWSGI le tue au bout de son délai de grâce (`reload-mercy`, 60 s par défaut). Cause non établie ; le pont porte un fil et une boucle d'événements par processus | Un redéploiement peut attendre une minute de plus. Abaisser `reload-mercy` et `worker-reload-mercy` dans les réglages de uWSGI devrait borner ce délai : **non essayé**. Le montage A (uvicorn) n'a montré aucun arrêt lent |
| **Migrations avec plusieurs processus** | Jouées une seule fois, que uWSGI charge l'application avant de se dédoubler ou dans chaque processus (`lazy-apps`, essayé avec deux processus) : chaque processus qui voit le témoin passe par l'outil, qui se sérialise par un verrou consultatif en base ; aucun ne sert avant d'avoir constaté une base à jour. Essayé aussi : migration en échec → uWSGI ne sert pas et le témoin reste ; témoin laissé par un processus tué (`.migrer.<pid>`) → repris au démarrage suivant | Rien à faire |

Le pont : **`a2wsgi` 1.10.10**, licence Apache-2.0, sans dépendance. Relevé sur PyPI le 2026-11-18 :
35 versions publiées, la dernière le 2025-06-18, soit dix-sept mois sans publication — c'est le
risque à connaître (nombre de mainteneurs non vérifié). Le pont tient en un fichier de 300 lignes. Il porte une boucle d'événements dans
un fil par processus ; chaque requête y est remise par le fil de uWSGI qui la sert.

**Relevé chez l'hébergeur le 2026-11-18** pour ce montage : uWSGI 2.0.31, quatre processus,
`lazy-apps` et `enable-threads = true` ; le Python 3.12 du système charge l'application et ses
dépendances préparées sans environnement virtuel ; les quatre combinaisons passent le smoke.
**Non prouvé chez l'hébergeur** : la durée de l'arrêt (le cas des 62 s ci-dessus) et le
comportement sous plusieurs requêtes simultanées de longue durée.

## Retour arrière

```sh
bash deploiement/alwaysdata/revenir.sh <hôte ssh> <compte> <instance> https://<adresse>
```

Le script remet le lien `courant` sur la version que désigne `precedent`, retire le témoin
`.migrer`, puis redémarre le site par l'API (site retrouvé par son adresse, mêmes variables que
`deployer.sh`) et attend que `https://<adresse>/api/health` réponde. Sans jeton d'API, la bascule
est faite et le redémarrage vous revient, depuis l'administration. Le lanceur et `wsgi.py`
reviennent avec le code : ce sont des liens vers la version courante.

- **La version quittée devient la précédente** : rejouer le script annule le retour. Si le script
  échoue à sa seconde étape (site introuvable, redémarrage, attente), la bascule est déjà faite :
  ne le rejouez pas, redémarrez le site depuis l'administration.
- **Il refuse s'il n'y a pas de version précédente** (après un premier déploiement), ou si elle
  est déjà en service, et ne change alors rien.
- **Il ne joue ni ne défait aucune migration** : le schéma reste celui de la version quittée.

**Le schéma, lui, ne recule pas tout seul.** Si la version abandonnée a joué une migration que
la précédente ne connaît pas, l'outil de l'ancienne version refusera de continuer (« migration
déjà passée absente du dépôt »). Annulez-la **avant** de revenir en arrière, avec la version qui
la connaît : `~/<instance>/lancer.sh outil app.migrate down` (une migration à la fois, la dernière),
puis `status` pour contrôler. `revenir.sh`, lui, retire le témoin `.migrer` : au démarrage qui
suit, l'outil de migration n'est pas appelé, rien ne refuse, et l'ancien code sert sur le schéma
de la version quittée. Une annulation supprime les données des tables et colonnes qu'elle
retire : au-delà d'un essai, le vrai retour arrière des données est la restauration d'une sauvegarde.
Après un tel `down`, ne rejouez pas `revenir.sh` pour repartir en avant : il ne pose pas le témoin
`.migrer`, le nouveau code démarrerait sans sa migration. Redéployez.

`revenir.sh` n'est prouvé qu'en répétition locale : **non prouvé chez l'hébergeur**.

En repli, le même geste à la main, sur le serveur, puis on redémarre le site :

```sh
cd ~/<instance>
ln -sfn "$(readlink precedent)" courant.nouveau && mv -Tf courant.nouveau courant
```

## Ce qui reste à la charge du porteur

- **Créer la base, son utilisateur et le site** dans l'administration, si vous déployez sans jeton
  d'API ; avec le jeton, le script les crée s'ils manquent. Dans les deux cas, l'adresse qui mène
  chez l'hébergeur et l'accès SSH restent à vous.
- **Une sauvegarde restaurée.** L'hébergeur sauvegarde chaque jour et garde sept jours sur
  l'offre sondée. Une copie hors de l'hébergeur et **une restauration essayée** restent au projet.
- **L'inactivité à 0** s'il y a des tâches de fond : par défaut, un site sans requête est arrêté
  après 30 minutes. Le kit n'en a pas ; si vous en ajoutez (montage A seulement), réglez le délai
  à 0 et faites appeler `/api/health` chaque minute par une tâche planifiée.
- **La clé de l'instance** (`TODO_SECRET_KEY`) vit dans `.env`, sur le serveur seulement. La
  perdre ou la changer révoque toutes les sessions et tous les jetons ; les comptes restent.
- **Les limites du kit en matière d'identité** (ADR-001) : limite d'essais par courriel et non
  par adresse, pas de confirmation de courriel ni de mot de passe oublié.
- **La conformité** : lire les conditions de l'hébergeur avant toute donnée réelle
  (`skills/conformite.md`) ; sans certification relevée pour les données de santé, jamais de
  donnée de santé.
- **La bascule du nom de domaine** : par l'humain, jamais par un script.

## Pièges rencontrés chez l'hébergeur

- **Le port voisin.** L'hébergeur attribue les ports des sites d'un compte à la suite. Si un
  autre programme du compte écoute de lui-même sur « son port + 1 » (un service annexe lancé par
  le lanceur d'un autre site, par exemple), le site suivant reçoit ce port : son adresse publique
  mène alors à ce service, et son propre programme n'est jamais lancé. Symptôme : une réponse
  immédiate qui n'est pas celle du kit (404 ou 401), et aucun démarrage dans le journal du site.
  Remède : aucun programme du compte ne choisit un port dans la plage que l'hébergeur attribue
  (8100 et suivants) ; un service annexe prend un port fixe loin de cette plage.
- **Retirer toutes les adresses d'un site ne le ferme pas** : la modification est sans effet.
  Pour fermer un site d'essai, on le supprime.
- **Un sous-domaine du nom de compte n'existe pas** (`<quelque-chose>.<compte>.<hébergeur>`) :
  ni le DNS ni l'API ne l'acceptent. Pour une adresse d'essai, prenez un sous-domaine d'un domaine
  qui pointe déjà vers l'hébergeur ; le certificat est fourni.
- **Le blocage d'adresse par le frontal** : voir « Prouver le déploiement ».

## Ce qui n'est pas prouvé chez l'hébergeur

- La correction du refus 413 (corps lu avant la réponse) : prouvée en local seulement.
- Le redémarrage par le script : l'appel à l'API de redémarrage est prouvé (le site a été
  redémarré ainsi à chaque passage du 2026-11-18, par une commande passée dans
  `KIT_REDEMARRAGE`), mais le chemin où le script lit le jeton dans le `.env` du kit, retrouve le
  site par son adresse et le redémarre lui-même n'est joué qu'en répétition locale, contre un faux
  serveur d'API. La désignation du site par `ALWAYSDATA_SITE` n'est jouée nulle part, pas même en
  répétition. Le temps pendant lequel le site ne répond pas n'est pas mesuré.
- La création par le script de l'utilisateur de base, de la base et du site : prouvée en
  répétition locale seulement, contre un faux serveur d'API. Le 2026-11-18, les mêmes appels ont
  été faits chez l'hébergeur à la main, avec les mêmes corps, pas par le script. La création d'un
  site du montage B (`KIT_MONTAGE=B`) n'est pas jouée, pas même en répétition : la répétition
  crée le site du montage A et lance elle-même uWSGI pour le montage B.
- L'attente du certificat d'un site neuf (180 secondes) : la répétition la met à zéro.
- Le retour arrière par `revenir.sh` : prouvé en répétition locale seulement.
- Le profil public du smoke : prouvé en local seulement ; les preuves du 2026-11-18 ont été
  faites avec le parcours complet.
- Le dossier du compte est sur **NFS v4** (relevé en lecture seule le 2026-11-18). Rien dans le kit
  ne repose sur un verrou de fichier : l'exclusion des migrations est un verrou consultatif en
  base, le témoin `.migrer` n'est que lu puis effacé. La bascule, elle, est un renommage de lien
  (`mv -T`), atomique côté serveur NFS ; mais un client NFS peut garder quelques instants
  l'ancienne cible en cache, et la répétition tourne sur un disque local : le délai réel après
  lequel un démarrage voit la nouvelle version n'est pas mesuré. C'est sans effet sur
  l'intégrité (chaque version est entière, le témoin lui est adressé), et le contrôle final du
  script échoue si le site redémarre sur l'ancienne.
- Le comportement derrière le frontal pour le flux, le délai d'inactivité et la relance après
  arrêt. (Les en-têtes de sécurité et le cookie `__Host-` arrivent bien au client : le smoke les
  vérifie.)
- La règle du frontal qui bloque une adresse après une rafale de refus, et sa durée.
- Le front statique servi par un site statique de l'hébergeur plutôt que par l'application :
  possible, non essayé — le kit le sert lui-même, ce qui garde les en-têtes de sécurité et une
  seule origine pour le cookie de session.
