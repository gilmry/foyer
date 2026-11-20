# Déployer `kit-actix` sur un hébergement infogéré (alwaysdata)

Ce guide amène le kit sur un hébergement **que l'on n'administre pas** : l'hébergeur tient le
système, la base et le frontal ; il reste au porteur l'application, sa configuration et ses
données. Le pourquoi et les règles générales sont dans
[`skills/deploiement-heberge-infogere.md`](../../../skills/deploiement-heberge-infogere.md) ; ce
guide ne donne que les gestes propres au kit.

Dans tout le guide, `<compte>` est le nom du compte chez l'hébergeur, `<instance>` le nom que vous
donnez à cette instance du kit, `<adresse>` l'adresse publique du site.

## Ce que l'hébergeur impose, et ce que le kit en fait

| Constat (relevé le 2026-11-18 sur une offre mutualisée) | Réponse du kit |
|---|---|
| Un site « programme utilisateur » lance une commande qui doit écouter sur l'adresse et le port fournis (`IP` ou `HOST`, `PORT`, adresse IPv6 possible). Aucun framework n'est exigé | `lancer.sh` traduit vers `HTTP_HOST` et `HTTP_PORT`, puis `exec ./server` |
| Le serveur est en Debian 12 (glibc 2.36) et **ne compile rien** : sa chaîne Rust est plus ancienne que celle du kit, et les règles du serveur SSH interdisent builds et processus longs | `construire.sh` compile sur le poste, dans l'image du kit (Debian 12, Rust figé par `rust-toolchain.toml`) ; `deployer.sh` vérifie par `ldd` qu'aucune bibliothèque ne manque |
| PostgreSQL géré : un login **sans privilège** (ni superutilisateur, ni création de rôle), noms préfixés par le compte | Les gates du kit se jouent déjà avec un tel login ; le gate `integration` échoue s'il est privilégié |
| Le site est arrêté après 30 minutes sans requête, puis relancé à la suivante ; une seule instance | Le kit n'a pas de tâche de fond : rien à régler. Si vous en ajoutez, mettez le délai d'inactivité à 0 |
| Aucun frontal n'ajoute d'en-tête de sécurité | Le serveur les émet lui-même sur toutes ses réponses |

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
- **le site**, nommé `<instance>`, pour `<adresse>`, HTTPS forcé : type « programme utilisateur »,
  commande `/home/<compte>/<instance>/lancer.sh`, répertoire de travail le dossier de l'instance.

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
contre un faux serveur d'API écrit pour le kit (`harness/faux-hebergeur.py`) : **non prouvé chez
l'hébergeur**. Le 2026-11-18, les mêmes appels (création de l'utilisateur, de la base, du site ;
redémarrage) ont été faits chez l'hébergeur **à la main**, avec les mêmes corps, pas par le script.

### Sans jeton : trois gestes à la main

1. **La base.** Dans l'administration de l'hébergeur, créez une base PostgreSQL `<compte>_<instance>`
   et un utilisateur du même nom, avec tous les droits sur cette base et sur elle seule.
2. **Son mot de passe, sur le serveur.** Connecté en SSH, tirez-le et rangez-le là où le script
   l'attend. Reportez ensuite cette valeur dans le formulaire de l'utilisateur de la base
   (elle ne doit contenir que des chiffres et des lettres : elle entre dans une adresse) :

   ```sh
   umask 077 && mkdir -p ~/<instance> && openssl rand -hex 24 > ~/<instance>/.pgpass.gen
   ```

   Le script lit ce fichier une seule fois, écrit `.env`, puis le supprime.
3. **Le site.** Créez un site de type « programme utilisateur » :
   commande `/home/<compte>/<instance>/lancer.sh`, répertoire de travail `/home/<compte>/<instance>`.

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

Le script fait cinq choses, toujours les mêmes, au premier passage comme aux suivants :

0. s'assure que la base, son utilisateur et le site existent chez l'hébergeur : avec le jeton
   d'API il crée ce qui manque après l'avoir annoncé, sans jeton il s'arrête si l'instance n'a
   jamais été préparée (voir « Avant le premier déploiement »). Rien n'est envoyé avant ;
1. construit `server`, `migrate` et le front sur le poste ;
2. les envoie sous un autre nom ;
3. crée `.env` sur le serveur **s'il n'existe pas** (il n'est jamais réécrit), garde la version
   précédente (`server.precedent`, `migrate.precedent`, `lancer.sh.precedent`,
   `public.precedent`), puis remplace les fichiers par renommage ;
4. pose le témoin `.migrer` et redémarre le site : le lanceur joue les migrations **manquantes**
   à ce démarrage-là, et à lui seul. Une migration déjà passée n'est jamais rejouée.

Le redémarrage se fait **par l'API de l'hébergeur**, sur le site que le script retrouve par son
adresse (ou qu'il vient de créer) : `ALWAYSDATA_SITE` n'est plus nécessaire. Il reste possible
(`ALWAYSDATA_SITE=<numéro du site>`) pour désigner un autre site que celui qui sert l'adresse ;
dans ce cas le script ne crée aucun site (la base et son utilisateur, eux, sont toujours créés
s'ils manquent). **Sans jeton d'API**, le script ne redémarre rien : redémarrez le site depuis
l'administration après son passage.

Après le redémarrage, le script attend que `https://<adresse>/api/todos` réponde, par des essais
peu nombreux et espacés (trente, à trois secondes d'intervalle) : le frontal de l'hébergeur bloque
une adresse qui le sonde en rafale. Pour un site **qu'il vient de créer**, il laisse d'abord
180 secondes à l'émission du certificat (`KIT_ATTENTE_CERTIFICAT` pour changer), puis fait vingt
essais à quinze secondes d'intervalle. Il vérifie enfin que le témoin `.migrer` a disparu.

## Prouver

```sh
E2E_PROFIL=public E2E_BASE_URL=https://<adresse> bash harness/e2e-smoke.sh
```

Le même smoke qu'en local, contre l'adresse publique : le parcours de référence (créer, lister,
basculer, supprimer), le refus de servir autre chose que `public/` et l'API, et les en-têtes de
sécurité. Il supprime ce qu'il crée.

**Contre l'hébergeur, toujours `E2E_PROFIL=public`, et un seul passage.** Ce profil est allégé et
espacé (une seconde entre deux requêtes, `E2E_PAUSE` pour changer). Le parcours complet envoie en
quelques secondes des dizaines de refus (401, 404, chemins comme `/.env`, essais de connexion
ratés) : le frontal d'un hébergement mutualisé peut y voir une attaque et bloquer l'adresse du
poste, pour tous les sites du compte — c'est arrivé le 2026-11-18 avec un autre kit, après neuf
parcours complets enchaînés. Le parcours complet reste prouvé par la répétition locale, qui joue
les deux profils.

Pour le second adaptateur de persistance, changez `TODO_PERSISTENCE=orm` dans le `.env` de
l'instance, redémarrez le site, rejouez le smoke.

## Ce qui est prouvé, et où

| Preuve | Répétition locale (gate `deploiement`) | Chez l'hébergeur |
|---|---|---|
| Parcours de référence, persistance `cqrs` | 🟢 2026-11-18 | 🟢 2026-11-18 (smoke public) |
| Parcours de référence, persistance `orm` | 🟢 2026-11-18 | 🟢 2026-11-18 (smoke public) |
| Écoute en IPv6 sur `IP` et `PORT` | 🟢 2026-11-18 | 🟢 2026-11-18 (adresse IPv6 et port de la plateforme, lus au journal du site) |
| Rejouer le déploiement : aucune migration rejouée, données intactes, `.env` inchangé, version précédente gardée | 🟢 2026-11-18 | 🟢 2026-11-18 (« 1 appliquée » puis « 0 appliquée » au journal, `.env` identique, `*.precedent` présents ; données intactes non vérifié : la base était vide) |
| Refus de démarrer sans configuration, message qui nomme `DATABASE_URL` | 🟢 2026-11-18 | **non prouvé** |
| Aucun secret (mot de passe de la base, jeton d'API) dans le journal du site, les sorties de `deployer.sh` et de `revenir.sh`, ni le journal du faux serveur d'API | 🟢 2026-11-18 | **non prouvé** |
| Arrêt par `SIGTERM`, relance, données toujours là | 🟢 2026-11-18 | **non prouvé** |
| Panne de la base : 500 générique, sans trace ni identifiant ; le site répond de nouveau quand elle revient | 🟢 2026-11-18 | **non prouvé** |
| Migration déjà passée dont le fichier a changé : refus, le site ne démarre pas, le témoin reste | 🟢 2026-11-18 | **non prouvé** |
| Relance **par une requête** après l'arrêt pour inactivité | sans objet (c'est la plateforme qui relance) | **non prouvé** |
| Sans jeton d'API, instance jamais préparée : arrêt avant tout envoi, aucun appel à l'API, le script dit quoi créer à la main | 🟢 2026-11-18 | **non prouvé** |
| Création par le script de l'utilisateur de base, de la base et du site (trois créations, annoncées avant) ; rejoué, aucune de plus | 🟢 2026-11-18, contre un faux serveur d'API | **non prouvé** par le script (les mêmes appels ont été faits à la main le 2026-11-18, avec les mêmes corps) |
| Redémarrage par l'API, sur le site retrouvé par son adresse, jeton lu dans le `.env` du kit | 🟢 2026-11-18, contre un faux serveur d'API | **non prouvé** par le script (l'appel de redémarrage, lui, a été fait le 2026-11-18 par une commande passée dans `KIT_REDEMARRAGE`) |
| Retour arrière par `revenir.sh` : refus sans version précédente, retour, puis retour du retour, sans rien créer chez l'hébergeur | 🟢 2026-11-18 | **non prouvé** |
| `hebergeur.sh`, `hebergeur.py` et `harness/faux-hebergeur.py` identiques dans les trois kits | 🟢 2026-11-18 | sans objet |

Dans la répétition locale, l'API de l'hébergeur est tenue par un **faux serveur local**
(`harness/faux-hebergeur.py`) : aucun appel ne part vers l'hébergeur réel. Ce faux serveur prouve
que le script tient son contrat ; il ne prouve pas l'hébergeur lui-même. Trois chemins ne sont
**pas joués** par la répétition de ce kit : la désignation du site par `ALWAYSDATA_SITE`,
l'attente du certificat d'un site neuf (la répétition la met à zéro), et le passage sans jeton sur
une instance déjà préparée (ce dernier est joué par la répétition de `kit-fastapi`, avec les mêmes
fichiers communs).

Déploiement réel du 2026-11-18 : un site « programme utilisateur » et une base PostgreSQL d'essai,
le script du kit joué deux fois, le site redémarré par l'API de l'hébergeur (commande passée dans
`KIT_REDEMARRAGE` ; le chemin où le script lit le jeton dans le `.env` du kit, retrouve le site
par son adresse et le redémarre lui-même n'est joué qu'en répétition locale), puis le smoke
public (20 vérifications)
pour chaque persistance, en HTTPS. Ce jour-là, la base, son utilisateur et le site avaient été
créés à la main, par les mêmes appels d'API et les mêmes corps que ceux du script d'aujourd'hui,
pas par le script. Le site d'essai a été supprimé ensuite. Les lignes encore
« non prouvé » ne se voient qu'en provoquant une panne ou en attendant l'arrêt pour inactivité :
elles n'ont pas été jouées chez l'hébergeur.

**Le certificat d'une adresse neuve n'est pas immédiat.** Relevé le 2026-11-18 : pendant les trois
minutes environ qui suivent la création du site, l'hébergeur présente son certificat générique, que le
client refuse ; l'application, elle, répond déjà. Un premier passage du script lancé aussitôt
peut donc échouer à son contrôle final sans que rien soit cassé : attendez, puis rejouez le script.
Le script laisse désormais ce délai de lui-même, mais seulement au site qu'il vient de créer dans
le même passage ; pour un site créé à la main juste avant, ou pour un passage rejoué aussitôt
après un échec, la consigne reste la même. Cette attente n'est jouée ni en répétition locale ni
chez l'hébergeur.

## Retour arrière

```sh
bash deploiement/alwaysdata/revenir.sh <hôte ssh> <compte> <instance> https://<adresse>
```

Le script échange, dans le dossier de l'instance, `server`, `migrate`, `lancer.sh` et `public`
avec leurs versions `*.precedent`, retire le témoin `.migrer`, puis redémarre le site par l'API
(site retrouvé par son adresse, mêmes variables que `deployer.sh`) et attend que
`https://<adresse>/api/todos` réponde. Sans jeton d'API, l'échange est fait et le redémarrage
vous revient, depuis l'administration.

- **La version quittée devient la précédente** : rejouer le script annule le retour. Si le script
  échoue à sa seconde étape (site introuvable, redémarrage, attente), l'échange est déjà fait :
  ne le rejouez pas, redémarrez le site depuis l'administration.
- **Il refuse s'il n'y a pas de version précédente**, et ne change alors rien : c'est le cas après
  un premier déploiement, et tant que l'un des quatre `*.precedent` manque (une instance livrée
  par une version du script qui ne gardait pas `lancer.sh.precedent` demande un redéploiement).
- **Il ne joue ni ne défait aucune migration** : le schéma reste celui de la version quittée.

Si la version retirée avait ajouté une migration, l'annuler d'abord avec le binaire **de cette
version** (`./migrate down`, qui annule la dernière), ou restaurer une sauvegarde. Après un tel
`down`, ne rejouez pas `revenir.sh` pour repartir en avant : il ne pose pas le témoin `.migrer`,
le nouveau code démarrerait sans sa migration. Redéployez.

`revenir.sh` n'est prouvé qu'en répétition locale : **non prouvé chez l'hébergeur**.

En repli, le même geste à la main, sur le serveur, dans le dossier de l'instance : remettre
`server.precedent`, `migrate.precedent`, `lancer.sh.precedent` et `public.precedent` à la place
des versions courantes, puis redémarrer le site.

## Ce qui reste à votre charge

- **Une sauvegarde qui se restaure.** Celles de l'hébergeur sont glissantes (7 jours sur l'offre
  relevée). Gardez une copie hors de l'hébergeur et essayez une restauration dans une base vide.
- **Les mises à jour** du kit et de ses dépendances : un redéploiement.
- **Le contrat et la nature des données.** Avant toute donnée réelle : conditions générales de
  l'hébergeur (sous-traitance au sens du RGPD), mentions légales, registre des traitements. Sans
  certification d'hébergeur de données de santé relevée, jamais de donnée de santé.
- **Jamais de test de charge chez l'hébergeur** : il se mesure en conteneurs bridés aux limites de
  l'offre.
- **Pas d'authentification dans ce kit** : toute personne qui connaît l'adresse lit et modifie les
  tâches. Ne déployez pas l'exemple tel quel avec des données qui comptent.
