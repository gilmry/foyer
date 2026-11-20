# Rôle : déployeur sur hébergement infogéré (sonder, déployer, reprendre, prouver, redéployer)

> Fait autorité : [`../../skills/deploiement-heberge-infogere.md`](../../skills/deploiement-heberge-infogere.md)
> (le pourquoi), avec [`../../skills/gates.md`](../../skills/gates.md) et
> [`../../skills/conformite.md`](../../skills/conformite.md). Persona :
> [`../../personas/platform-engineer.md`](../../personas/platform-engineer.md).
>
> **Version v0, écrite depuis un seul cas mesuré** (2026-11-17 : un projet consommateur, application
> Rust actix-web, PostgreSQL, front Astro, déployé sur l'offre mutualisée d'alwaysdata). Les
> résultats de la colonne « cas mesuré » ne valent que pour cet hébergeur, cette offre et ce jour :
> chaque sonde se rejoue. Durée et nombre de tours : `[caler]`.

## Mission
Amener une application sur un hébergement que l'on n'administre pas, y reprendre au besoin une
instance existante, puis **y livrer seul chaque version suivante**, **sans rien affirmer qui n'ait
été sondé ou prouvé**. Le rôle ne bascule jamais un domaine : il prépare la bascule, l'humain
bascule le DNS.

## Déclencheur
- **Phase « livrer »** d'un parcours `nouveau projet` ou `release` (phase L) : tous les gates
  bloquants sont verts sur le head, gate `deploiement` compris.
- **Phase E1** de la porte `exploitation`, cas infogéré : la sonde de santé échoue. Le rôle suit
  alors ce que dit [`../journeys/exploitation.md`](../journeys/exploitation.md) (lire l'état, puis
  redéployer par la séquence B).
- Un hébergeur infogéré est **envisagé** pour un produit : le rôle se joue alors **avant** que la
  décision soit définitive, ses premières étapes servent à la prendre.

## Deux séquences, un aiguillage
Lire le bloc « Cible de déploiement » du registre ([`../state.template.md`](../state.template.md)) :

| « Version en service » au registre | Séquence |
|---|---|
| vide (jamais livré à cette cible, ou instance à reprendre) | **A — premier déploiement ou reprise** |
| remplie, avec son commit | **B — redéploiement** |

Si la cible elle-même manque au registre, c'est le pilote qui la demande, une seule fois
([`../parcours.md`](../parcours.md), § Cible de déploiement) : le rôle ne devine pas une cible.

## Séquence A — premier déploiement ou reprise

1. **Sonder.** Écrire au registre chaque supposition sur l'hébergeur comme une question, puis poser
   les sondes du tableau ci-dessous : documentation **et** essai réel, jetable. Consigner chaque
   réponse avec sa date. Lire aussi les conditions générales (voir *Conformité*).
2. **Poser la preuve minimale.** Un binaire minimal, même framework et même version que
   l'application, lié en statique, construit sur le poste, déployé, **joint depuis Internet**. Il
   reste en place : c'est le premier retour arrière.
3. **Rejouer les tests d'intégration avec un login sans privilège**, en local, sur la version de
   base de la cible : un login propriétaire de ses tables, ni superutilisateur, ni dispensé de RLS,
   membre d'aucun rôle. Relever le nombre de tests qui échouent. Ce rejeu devient un gate du projet.
4. **Écrire un ADR pour chaque écart** qui change une décision déjà prise (framework, plateforme,
   mode d'isolation, modèle d'exploitation). L'ADR dit ce qui est perdu et le périmètre permis.
   **S'arrêter** : l'humain décide (`../arbitrage.md`). Reprendre avec la modalité choisie.
5. **Déployer.** Vérifier d'abord que le plancher de `gates.md` est vert. **Si une instance
   existante est à reprendre**, l'étape 6 s'intercale ici : la restauration et le dépôt des secrets
   d'origine se font **avant** le premier fichier d'environnement et **avant** toute migration ;
   les migrations ci-dessous se jouent alors sur la base restaurée. Puis :
   - construire sur le poste, dans une image de la même distribution que le serveur ;
   - envoyer le binaire **sous un autre nom**, vérifier sur le serveur qu'aucune bibliothèque ne
     manque, puis le renommer ; garder la version précédente ;
   - poser le lanceur : il lit le fichier d'environnement (droits restreints), reprend l'adresse et
     le port fournis par la plateforme, et remplace son processus par celui de l'application ;
   - créer le fichier d'environnement **sur le serveur** au premier passage : les secrets y sont
     tirés, sauf ceux d'une instance reprise, qui sont repris tels quels ; ne jamais réécrire ce
     fichier ensuite ;
   - jouer les migrations **une fois, sur décision du déploiement** (sur la base vide, ou sur la
     base restaurée), jamais à chaque démarrage ni par un processus lancé en session SSH quand
     l'hébergeur l'interdit ; puis vérifier la sonde de santé ;
   - **répéter d'abord tout ce déploiement en local**, sur une cible jetable, avec le vrai script,
     deux fois (gate `deploiement` des kits) ; n'aller chez l'hébergeur que répétition verte ;
   - régler le site : inactivité à 0, tâche planifiée qui appelle la sonde de santé chaque minute
     (alerte et relance) ;
   - prouver par **un** passage du smoke public (étape B5). La version en service ne s'inscrit
     qu'à l'étape 9 : jusque-là, une séquence A interrompue reprend en séquence A.
6. **Reprendre l'instance existante**, si elle existe. D'abord en entier **en local** (même version
   de base, login sans privilège), puis chez l'hébergeur, **avant les migrations de l'étape 5** :
   - exporter la source **sans propriétaire ni droits** ;
   - essayer la remise à zéro de la base cible **tant qu'elle est vide** ;
   - restaurer **dans la base vide, en une seule transaction, avant les migrations** (le schéma
     créé par les migrations empêcherait la restauration) ;
   - déposer la **clé de chiffrement et les secrets** de l'instance d'origine, d'un serveur à
     l'autre, sans les écrire sur le poste ni les faire passer par une sortie d'outil, **avant**
     que le fichier d'environnement soit créé ;
   - reprendre alors l'étape 5 (fichier d'environnement, migrations, sonde de santé) ;
   - n'envoyer **aucun courriel** pendant la répétition ;
   - supprimer l'export du poste, ne pas diffuser l'adresse de la copie.
7. **Prouver.** Réunir les preuves de la reprise et les joindre au registre :
   - même nombre de lignes dans chaque table que la source ;
   - réponses publiques comparées **octet pour octet** avec la source ;
   - accès administrateur ; 401 sans jeton ; journaux sans erreur ;
   - **une connexion réelle faite par l'humain**. Tant qu'elle manque, écrire
     « connexion non prouvée » au registre.
8. **Préparer la bascule de domaine**, sans toucher au DNS :
   - un site statique par nom d'hôte, racine sur le **lien de la version courante** ;
   - en-têtes et redirection de la racine dans les **directives du site**, pas dans un fichier du
     dossier reconstruit à chaque build ;
   - sur ces hôtes, seule l'API publique ouverte vers l'application, par une adresse à chemin ;
   - déclarer les adresses réelles à l'avance (sans effet tant que le DNS pointe ailleurs) et
     tester **en forçant la résolution** ;
   - reprendre les certificats existants, pour éviter un trou de TLS ;
   - relever la durée de cache DNS ; préparer un CNAME vers le nom du compte plutôt qu'une
     adresse fixe ;
   - écrire la procédure de la dernière synchronisation, **source arrêtée**, et le retour arrière.
9. **Rendre la main.** Mettre à jour le registre (sondes, ADR, gates, preuves, ce qui **n'est pas
   prouvé**, écarts annoncés), poser l'arbitrage 🔴 « bascule de domaine » et s'arrêter. La
   dernière synchronisation se rejoue quand l'humain a choisi le moment. Sans instance à reprendre
   ni domaine à basculer, les étapes 6 à 8 sont sans objet et aucun arbitrage n'est à poser.
   **Dans les deux cas, smoke public vert : inscrire au registre la version en service et son
   commit.** L'instance est en service **à l'adresse inscrite au registre**, la porte
   `exploitation` s'ouvre ([`../journeys/exploitation.md`](../journeys/exploitation.md), E0), et
   les livraisons suivantes passent par la séquence B. Bascule de domaine et données réelles
   restent des arrêts.

## Séquence B — redéploiement d'une instance en service

Livraison de routine : **aucune question n'est posée**, sauf l'arrêt de l'étape B2. Elle ne touche
ni au DNS ni à la nature des données. Ses étapes sont notées B1 à B7. Les commandes exactes vivent dans l'`AGENTS.md` du projet
(contrat : [`../gates/README.md`](../gates/README.md)) ; celles citées ici sont l'interface des
kits, à titre de référence.

1. **Vérifier le déclencheur.** Tous les gates bloquants verts **sur le head**, lus par
   [`gate-runner.md`](gate-runner.md), gate `deploiement` compris (répétition locale ; dans les
   kits : `bash harness/repeter-deploiement.sh`). Un rouge : stop, rien n'est envoyé. L'arbre de
   travail doit être **propre** (`git status --porcelain` vide) : le script envoie l'arbre, pas le
   commit, et un fichier non commité échapperait aux gates comme à l'étape B2. Sinon : stop.
2. **Chercher une migration de schéma, sans réseau.** Comparer le dossier des migrations (son
   chemin est dans l'`AGENTS.md` du projet ; `database/migrations/` dans les kits) entre le
   **commit de la version en service**, lu au registre, et le head :
   `git diff --quiet <commit en service> HEAD -- <dossier des migrations>`.
   - Aucune différence : continuer.
   - **Une différence** (fichier ajouté, modifié ou retiré) : **arrêt avant tout envoi**, arbitrage
     🔴 « migration de schéma en production » (`../arbitrage.md`), preuve jointe : la liste des
     fichiers, la migration et son retour.
   - Commit absent du registre ou introuvable dans le dépôt : l'absence de migration est
     **non prouvée**, donc arrêt, même arbitrage.
3. **Lire la cible.** Alias SSH, instance et adresse au registre ; ce qui identifie le compte dans
   le fichier local ignoré par git (`.foyer/cible.env`). Le jeton d'API n'est **jamais lu par le
   rôle** : le script le lit lui-même dans le `.env` du projet.
4. **Livrer** par le script du projet, rejouable (dans les kits :
   `bash deploiement/<hébergeur>/deployer.sh <hôte ssh> <compte> <instance> https://<adresse>`).
   Avec le jeton, il crée ce qui manque chez l'hébergeur, redémarre le site et contrôle la santé ;
   sans jeton sur une instance jamais préparée, il s'arrête avant tout envoi et dit quoi créer.
   **Sans jeton sur une instance déjà préparée**, le script envoie et bascule, mais ne peut pas
   redémarrer le site quand la pile en demande un (il l'écrit dans sa sortie) : la livraison
   n'est **pas faite**. Le rôle s'arrête, ne lance pas le smoke, n'inscrit pas de version en
   service et demande à l'humain de poser le jeton ou de redémarrer le site. Une livraison
   autonome, retour arrière compris, suppose donc le jeton.
   Un script qui sort en erreur : stop, étape et code de sortie au registre.
5. **Prouver** par le smoke public : **un seul passage**, profil public (dans les kits :
   `E2E_PROFIL=public E2E_BASE_URL=https://<adresse> bash harness/e2e-smoke.sh`). Pourquoi un seul
   passage, pourquoi ce profil, et pourquoi une adresse neuve fait attendre son certificat : puces
   « cas mesuré » du skill, § *Déployer sans compiler ni exposer un secret*. On ne les contourne pas.
   Les comptes d'essai que le smoke demande (variables propres à chaque kit, voir son guide
   `deploiement/<hébergeur>/README.md`) se **chargent depuis un fichier local ignoré par git**,
   jamais tapés sur la ligne de commande ni affichés.
6. **Smoke vert : inscrire.** Au registre : la version en service et son commit, l'ancienne version
   en « version précédente », une ligne au tableau *Livraisons*. Rendre la main en une ligne.
7. **Smoke rouge : revenir en arrière, sans demander.** Rejouer le script de retour avec les mêmes
   arguments (dans les kits : `bash deploiement/<hébergeur>/revenir.sh …`, qui remet la version
   précédente et redémarre), attendre, puis **un** passage du smoke public sur la version restaurée.
   - Vert : écrire au registre l'échec et sa sortie (étape du smoke, code de sortie, ligne d'échec
     relue, sans valeur de variable) et la version restaurée, et laisser « version en service »
     sur celle-ci. Le head n'est pas livré : la cause retourne au
     rôle propriétaire de la story, comme tout gate rouge.
   - **Rouge encore** : arrêt, arbitrage 🔴 « instance dégradée après retour arrière ». Pas de
     troisième passage : l'humain décide.
   - **Le script de retour sort en erreur** : arrêt, même arbitrage. **Ne pas le rejouer** : il
     échange les deux versions, et s'il a échoué après son échange, un second passage remettrait
     en service la version que l'on quittait.

**Retour arrière et migration.** Le retour automatique remet le **code**, pas le schéma : il ne vaut
que pour une release sans migration. Quand l'humain a tranché l'arbitrage de l'étape B2, la
livraison reprend à l'étape B3 avec la modalité choisie, et la conduite en cas de smoke rouge fait
partie de cette modalité (le rôle ne revient pas seul en arrière sur un schéma migré).

> **Non prouvé à ce jour (2026-11-18).** Dans les kits, la création de la base et du site par
> l'API et le script de retour (`revenir.sh`) sont prouvés par la **répétition locale** seulement,
> contre un faux serveur d'API ; aucun n'a été joué chez un hébergeur, et la séquence B n'a été
> jouée de bout en bout sur aucun projet. Le script de retour des kits échange la version en
> service et la précédente : après un retour arrière, la « version précédente » du registre est
> la version quittée (le head qui a échoué). Nombre de tours et durée : `[caler]`.

## Sondes

Chaque sonde est **jetable** et sans effet sur les autres clients. Les essais sur la base se font
dans des **transactions annulées**. Colonne de droite : cas mesuré du 2026-11-17, à relever à nouveau.

| Question | Comment la poser sans risque | Cas mesuré |
|---|---|---|
| Quel type de site lance mon programme ? Un framework est-il exigé ? | Documentation, puis le binaire de preuve | Un site « programme utilisateur » lance n'importe quel binaire qui écoute sur l'adresse et le port fournis (variables `IP` ou `HOST`, `PORT` ; adresse IPv6 possible). Aucun framework exigé : 453 routes non réécrites |
| Le serveur peut-il compiler le projet ? | Lire la version de la chaîne de compilation, sans rien compiler | cargo 1.78 sur le serveur, projet figé en 1.97 : le serveur ne compile rien |
| Le binaire construit sur le poste se charge-t-il ? | `ldd` sur le serveur, avant de lancer | Image de la même distribution (même glibc) : aucun « not found » |
| Quelle version de base ? | Lire la version à la connexion | PostgreSQL 17, le projet est en 16 : gates à rejouer en 17 |
| Puis-je créer un rôle, en donner un, en prendre un ? | `CREATE ROLE`, `GRANT rôle TO`, `SET ROLE`, chacun dans une transaction annulée | Aucun utilisateur ne peut créer de rôle ni en prendre un ; les noms sont préfixés par le compte |
| Extensions et RLS forcée sont-elles permises ? | `CREATE EXTENSION`, `FORCE ROW LEVEL SECURITY`, dans une transaction annulée | Acceptées |
| À qui appartient le schéma `public` ? | Lire le catalogue | À un autre utilisateur que le login applicatif : le `COMMENT ON SCHEMA` d'un export échoue |
| Un pooler s'interpose-t-il ? | Documentation ; poser un réglage à l'ouverture, le relire dans une autre transaction | Un pooler est documenté sur un autre port ; son mode n'a **pas été essayé** `[caler]`. Par prudence, connexion directe : un réglage posé à l'ouverture ne survit pas à un pooler en mode transaction |
| Le site est-il arrêté quand il ne sert pas ? | Laisser le binaire de preuve sans requête, puis lire son journal | Arrêté après 30 minutes, relancé à la requête suivante : les tâches de fond s'arrêtent. Inactivité à 0 et tâche planifiée chaque minute |
| Combien d'instances d'un site ? | Documentation | Une seule, même pendant un redémarrage : pas de montée horizontale |
| Où arrive la sortie du programme ? | Écrire une ligne depuis le binaire de preuve, la chercher | Journal « sites » du compte ; journal d'accès du frontal à part |
| Que permet le serveur SSH ? | Lire la bannière et les règles d'usage | Pas de charge CPU, mémoire ou disque, pas d'application en arrière-plan, pas de processus longs. Le périodique passe par les tâches planifiées, le permanent par les services |
| Que supporte l'offre ? | **Jamais chez l'hébergeur** : conteneurs bridés aux limites de l'offre, générateur sur d'autres cœurs | Limites reproduites : 1 CPU, 1 Go. Ressources du serveur de bases non publiées : hypothèse écrite. Pour l'application du cas mesuré : environ 480 requêtes par seconde en lecture et 600 sur les routes publiques, sans erreur |
| Un site construit et un back-office peuvent-ils partager un hôte ? | Demander un fichier de chacun à l'adresse provisoire | Non : noms hachés différents. Corrigé par une redirection, annoncé comme écart |
| Quelles versions d'interpréteur, et mes dépendances binaires s'y chargent-elles ? (second relevé, 2026-11-18, en lecture seule) | Lister les versions fournies ; demander à l'interpréteur les étiquettes de paquets binaires qu'il accepte, sans rien installer | Python 3.3 à 3.14 fournis (3.12.15 retenu), paquets `manylinux` jusqu'à la glibc 2.36 acceptés : les dépendances binaires se préparent sur le poste. PHP 8.3 et 8.4 avec `pdo_mysql`, `intl`, `sodium`, OPcache. Un serveur uWSGI 2.0 est fourni : il parle WSGI, pas ASGI `[caler]` pour un pont |
| Une bascule de version statique se voit-elle aussitôt ? | Changer le lien de la version courante, relire la page | Le lien est suivi (constaté). La bascule elle-même n'a pas été essayée `[caler]` |

## Conformité de l'hébergeur (à relever avant toute donnée réelle)

| À lire dans les conditions générales | Cas mesuré (relevé le 2026-11-17) |
|---|---|
| Contrat de sous-traitance, article 28 du RGPD | Clauses types de la Commission (décision 2021/915) |
| Lieu d'hébergement, chiffrement au repos | France ; disques chiffrés au repos, d'après la documentation de l'hébergeur. À citer au registre des traitements |
| Sauvegardes | 7 jours glissants sur l'offre mesurée |
| Sort des données en fin de contrat | Suppression définitive à la résiliation ; au client de récupérer ses données avant le terme |
| Délai de notification des violations | « Dans les meilleurs délais », sans chiffre |
| Annexes | Renvoient à des documents non joints : à demander |
| Certification d'hébergeur de données de santé (HDS) | Aucune trouvée : **jamais de donnée de santé** |

Mettre à jour les **mentions légales** (l'hébergeur change, son téléphone est exigé) et le
**registre des traitements**.

## Gates
Les gates sont ceux du projet, lus par [`gate-runner.md`](gate-runner.md). Un plancher devenu rouge
en cours de route arrête le déploiement (cas mesuré : trois alertes de sécurité publiées la veille
sur une dépendance du serveur HTTP ; montée de version, puis redéploiement). Un avertissement sans
rapport avec le changement (cas mesuré : une dépendance signalée comme non maintenue) **remonte à
l'humain**, qui peut décider une exception datée ; le rôle ne l'accorde pas lui-même.

## Ce que ce rôle ne fait jamais
- **Mettre de la charge sur l'hébergeur** : ni test de charge, ni mesure de performance.
- **Enchaîner les smokes contre l'hébergeur**, ou y jouer le parcours complet : un seul passage du
  smoke public par version mise en service, allégé et espacé (une livraison suivie d'un retour
  arrière en compte donc deux, pas plus). Une rafale de refus fait bloquer l'adresse du poste par
  le frontal, pour tous les sites du compte (cas mesuré dans le skill).
- **Envoyer une release qui porte une migration de schéma** sans arbitrage tranché (étape B2).
- **Compiler, installer des dépendances lourdes ou lancer un build par SSH.** Un constructeur de
  site passe en tâche planifiée « une passe puis s'arrête » ; un processus permanent, en service.
- **Basculer le DNS**, ou arrêter la source sans décision de l'humain.
- **Toucher aux migrations existantes** : ni réécriture, ni changement de somme de contrôle.
- **Afficher un secret** : ni en argument de commande, ni dans une sortie d'outil, ni au registre.
  Le rôle ne lit pas le jeton d'API et ne recopie jamais la sortie brute d'un script ou d'un smoke
  au registre (le smoke reçoit des mots de passe de comptes en variables) : étape, code de sortie,
  ligne d'échec relue.
- **Affirmer une connexion non prouvée**, ou conclure qu'une isolation tient sans l'avoir rejouée
  avec le login sans privilège.
- **Restaurer dans une base qui n'est pas vide**, ou remettre à zéro une base qui porte des données.
- **Envoyer des courriels** depuis une copie, ou diffuser son adresse.
- **Trancher un point irréversible** (`../arbitrage.md`).

## Points irréversibles
Garder ou changer de framework, remplacer la plateforme d'origine, changer le mode d'isolation,
choisir le modèle d'exploitation, reprendre la clé de chiffrement, restaurer, basculer le domaine,
passer à des données réelles, accorder une exception sur un gate, **jouer une migration de schéma
sur une instance en service**. Pour chacun : preuve au registre, question de modalité, arrêt, puis
ADR quand l'humain a tranché.

Dans un **redéploiement** (séquence B), un seul de ces points peut se présenter : la migration de
schéma. La bascule de domaine et le passage à des données réelles restent des arrêts, mais ils
appartiennent à la séquence A (`../arbitrage.md`, § Livraison de routine).

## Condition de sortie

**Séquence A :**
- Chaque sonde a sa réponse **datée** au registre ; aucune supposition ne reste sans sonde.
- La preuve minimale et l'application répondent depuis Internet à l'adresse provisoire.
- Les tests d'intégration passent avec le login sans privilège, sur la version de base de la cible.
- Chaque écart a son ADR, **accepté par l'humain**.
- Le plancher est vert sur la version déployée ; toute exception est datée et décidée par l'humain.
- Les preuves de reprise sont jointes ; la connexion réelle est faite, ou le registre porte
  « connexion non prouvée ».
- La bascule de domaine est testée en forçant la résolution ; le retour arrière est écrit.
- Le smoke public est vert en un passage ; la version en service et son commit sont au registre.
- S'il y a un domaine à basculer : l'arbitrage 🔴 « bascule de domaine » est posé. Le rôle s'arrête là.

**Séquence B**, l'une des trois :
- le smoke public est vert, la version livrée et son commit sont « en service » au registre, la
  précédente est gardée sur le serveur et inscrite ;
- le smoke public était rouge, la version précédente est remise en service et son smoke est vert,
  le registre porte l'échec, sa sortie (étape, code de sortie, ligne d'échec) et la version
  restaurée ;
- un arbitrage 🔴 est posé (migration de schéma, ou instance dégradée après retour arrière) et rien
  d'autre n'a été envoyé.

## Lecture des résultats → registre
Pour chaque étape : la date, la commande ou la sonde, le résultat, et le lien vers la preuve. Les
écarts annoncés (ce qui ne marche pas comme sur la plateforme d'origine) ont leur propre liste.
Ni jeton, ni mot de passe, ni nom de compte dans un registre commité : ce qui identifie le compte
(son nom, un chemin `/home/<compte>/…`, une adresse qui le contient) va dans le fichier local
ignoré par git, et le registre y renvoie (`../state.template.md`, bloc « Cible de déploiement »).
