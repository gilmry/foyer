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
4. **Facultatif : le redémarrage par l'API.** Rangez le jeton d'API de l'hébergeur dans le fichier
   `.env` **du kit, sur votre poste** (ignoré par git), sous le nom `ALWAYSDATA_TOKEN`. Le script
   s'en sert pour redémarrer le site ; il ne l'affiche pas et ne le passe jamais en argument.

## Déployer, puis redéployer

```sh
bash harness/repeter-deploiement.sh        # d'abord en local : la répétition doit être verte
ALWAYSDATA_SITE=<numéro du site> \
  bash deploiement/alwaysdata/deployer.sh <hôte ssh> <compte> <instance> https://<adresse>
```

Le script fait quatre choses, toujours les mêmes, au premier passage comme aux suivants :

1. construit `server`, `migrate` et le front sur le poste ;
2. les envoie sous un autre nom ;
3. crée `.env` sur le serveur **s'il n'existe pas** (il n'est jamais réécrit), garde la version
   précédente (`server.precedent`, `migrate.precedent`, `public.precedent`), puis remplace les
   fichiers par renommage ;
4. pose le témoin `.migrer` et redémarre le site : le lanceur joue les migrations **manquantes**
   à ce démarrage-là, et à lui seul. Une migration déjà passée n'est jamais rejouée.

Sans `ALWAYSDATA_SITE`, redémarrez le site depuis l'administration après le passage du script.

## Prouver

```sh
E2E_BASE_URL=https://<adresse> bash harness/e2e-smoke.sh
```

Le même smoke qu'en local, contre l'adresse publique : le parcours de référence (créer, lister,
basculer, supprimer), le refus de servir autre chose que `public/` et l'API, et les en-têtes de
sécurité. Il supprime ce qu'il crée.

Pour le second adaptateur de persistance, changez `TODO_PERSISTENCE=orm` dans le `.env` de
l'instance, redémarrez le site, rejouez le smoke.

## Ce qui est prouvé, et où

| Preuve | Répétition locale (gate `deploiement`) | Chez l'hébergeur |
|---|---|---|
| Parcours de référence, persistance `cqrs` | 🟢 2026-11-18 | **non prouvé** |
| Parcours de référence, persistance `orm` | 🟢 2026-11-18 | **non prouvé** |
| Écoute en IPv6 sur `IP` et `PORT` | 🟢 2026-11-18 | **non prouvé** |
| Rejouer le déploiement : aucune migration rejouée, données intactes, `.env` inchangé, version précédente gardée | 🟢 2026-11-18 | **non prouvé** |
| Refus de démarrer sans configuration, message qui nomme `DATABASE_URL` | 🟢 2026-11-18 | **non prouvé** |
| Aucun secret dans le journal du site ni dans les sorties du script | 🟢 2026-11-18 | **non prouvé** |
| Arrêt par `SIGTERM`, relance, données toujours là | 🟢 2026-11-18 | **non prouvé** |
| Panne de la base : 500 générique, sans trace ni identifiant ; le site répond de nouveau quand elle revient | 🟢 2026-11-18 | **non prouvé** |
| Migration déjà passée dont le fichier a changé : refus, le site ne démarre pas, le témoin reste | 🟢 2026-11-18 | **non prouvé** |
| Relance **par une requête** après l'arrêt pour inactivité | sans objet (c'est la plateforme qui relance) | **non prouvé** |

La colonne de droite se remplit par un déploiement réel suivi du smoke ci-dessus. Un projet
consommateur dérivé de ce kit (même framework, même base) tourne ainsi chez cet hébergeur depuis
le 2026-11-17 : c'est un précédent, pas une preuve du kit.

## Retour arrière

Sur le serveur, dans le dossier de l'instance : remettre `server.precedent`, `migrate.precedent`
et `public.precedent` à la place des versions courantes, puis redémarrer le site. Si la version
retirée avait ajouté une migration, l'annuler d'abord avec le binaire **de cette version**
(`./migrate down`, qui annule la dernière), ou restaurer une sauvegarde.

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
