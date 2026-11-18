# Skill — Déploiement sur hébergement infogéré

*Skill enfant de la primitive `../Boucle-de-retroaction.md`. Ici on ne possède pas le serveur : l'hébergeur tient le système, la base et le frontal, et en fixe les règles. Trois outils **objectivent** : la **sonde jetable** (ce que l'hébergeur permet vraiment), le **login sans privilège** (ce que l'application suppose sans le dire), la **comparaison avec la source** (ce qu'une reprise a conservé). Invoque `gates.md` et `conformite.md`. Lit l'archétype (`../bmad/archetypes.md`). Séquence exécutable : `../pilote/roles/deployeur-heberge.md`.*

> **Version v0, écrite depuis un seul cas mesuré.** Le 2026-11-17, un projet consommateur (application Rust actix-web, PostgreSQL, front Astro) est passé d'un serveur à conteneurs à l'offre mutualisée d'alwaysdata. Les faits marqués « cas mesuré » en viennent. Les règles valent pour tout hébergeur du même genre ; les valeurs se relèvent à nouveau pour chacun, et ce qui n'a pas été mesuré est marqué `[caler]`.

---

## Le cercle pour un hébergement que l'on n'administre pas

- **Conception** — tu écris chaque supposition sur l'hébergeur comme une **question à sonder**, avec la réponse attendue : type de site, chaîne de compilation, droits sur la base, cycle de vie, journaux, règles d'usage. Tu écris aussi, avant de reprendre des données, **les preuves que la reprise devra fournir**.
- **Construction** — tu poses une **preuve minimale** (un binaire minimal, même framework, même version, joint depuis Internet), puis l'application, puis les données reprises.
- **Résultat** — une instance répond à une adresse provisoire.
- **Évaluation** — la **sonde** confirme ou réfute chaque supposition ; les tests d'intégration rejoués avec un **login sans privilège** disent si l'application tient sans les droits qu'elle avait ailleurs ; la **comparaison avec la source** dit si la reprise est fidèle ; les gates de `gates.md` restent ceux du projet.
- **Amélioration** — un écart devient une correction, ou un **ADR** quand il change une décision déjà prise. Puis on reboucle.

## Sonder avant de promettre

Une affirmation sur l'hébergeur ne vaut que vérifiée **deux fois** : par sa documentation **et** par un essai réel, jetable, sans effet sur les autres clients de la plateforme. La documentation dit ce qui est prévu ; l'essai dit ce qui est vrai pour ce compte et cette offre.

**La sonde précède la décision, pas l'inverse.** Cas mesuré : la question de départ était de remplacer actix-web par un framework que l'hébergeur propose à l'installation. La sonde a montré qu'un site de type « programme utilisateur » lance n'importe quel binaire qui écoute sur l'adresse et le port fournis par la plateforme. Le framework est resté, et 453 routes n'ont pas été réécrites.

**La preuve minimale précède l'application.** Un binaire minimal déployé et joint depuis Internet sépare deux questions que l'on confond sinon : « l'hébergeur fait-il tourner ce genre de programme ? » et « mon application est-elle bien configurée ? ». Il reste ensuite en place comme retour arrière.

**On ne mesure jamais la charge chez l'hébergeur.** Sur une offre mutualisée, un test de charge pèse sur les autres clients et enfreint les règles d'usage. On mesure en conteneurs bridés aux limites de l'offre (cas mesuré : 1 CPU, 1 Go), le générateur de charge sur d'autres cœurs, et l'on **écrit l'hypothèse** quand une ressource n'est pas publiée (cas mesuré : le serveur de bases).

La liste des sondes, la façon de poser chacune sans risque et ce qu'elle a donné dans le cas mesuré sont dans le rôle.

## Le login sans privilège révèle les défauts latents

Un environnement où l'on se connecte en superutilisateur **cache** ce que l'application doit à ce privilège. Cas mesuré : le projet isolait ses tenants par des politiques de sécurité au niveau des lignes (RLS), en changeant de rôle dans chaque transaction. La base managée refusait le changement de rôle. Mais surtout, les accès hors tenant ne fonctionnaient que parce que le poste, la CI et le serveur d'origine se connectaient en superutilisateur, qui ignore la RLS. Avec un propriétaire sans privilège, **11 tests d'adaptateurs sur 90 et 8 tests de contrat sur 14 échouaient**. Le défaut existait avant l'hébergeur ; il se serait montré sur toute base sans superutilisateur.

Règle générale : **avant de croire à une isolation, rejouer les tests d'intégration avec le login de la cible**, sans privilège, sur la version de base de la cible. Ce rejeu devient un gate du projet.

Quand la cible impose un autre mécanisme, la décision se prend en **ADR**, qui amende l'ADR d'origine et dit **noir sur blanc ce qui est perdu** et dans quel périmètre le nouveau mode est permis. Le cas mesuré donne la forme d'une telle décision :

- le mode d'origine reste le mode par défaut ; le nouveau mode, « sans rôle », se choisit par configuration ;
- au lieu de changer de rôle, la transaction de tenant **coupe un réglage d'accès de plateforme** ; une politique de plus par table, réservée au login applicatif, laisse passer les accès hors tenant quand ce réglage est posé ;
- ces politiques sont **posées au démarrage, pas par migration** : le schéma des autres environnements ne change pas ;
- les **migrations existantes ne sont pas modifiées** : le nom du rôle y est remplacé à l'exécution, et leurs sommes de contrôle sont gardées ;
- une **garde au démarrage** refuse un login superutilisateur ou dispensé de RLS : sans elle, l'isolation disparaît **sans symptôme**, car les tests HTTP rendent leur 404 avant d'atteindre la base ;
- le retour arrière des migrations, s'il n'a plus de sens dans ce mode, y est **refusé** et remplacé par la restauration d'une sauvegarde.

## Déployer sans compiler ni exposer un secret

- **Le serveur ne compile rien.** Cas mesuré : l'hébergeur fournissait cargo 1.78, le projet était figé en 1.97. Le binaire se construit sur le poste, dans une image de la même distribution que le serveur (même glibc), et l'on vérifie sur le serveur qu'aucune bibliothèque ne manque.
- **Un lanceur** lit un fichier d'environnement à droits restreints, fait correspondre l'adresse et le port de la plateforme à ceux de l'application, et **remplace son processus** par celui de l'application, pour que le signal d'arrêt de la plateforme l'atteigne.
- **Les secrets naissent sur le serveur.** Jamais en argument de commande, jamais dans une sortie d'outil. Le jeton d'API de l'hébergeur vit dans un fichier ignoré par git.
- **La bascule de version est atomique** : le binaire arrive sous un autre nom, puis est renommé. La version précédente, ou le binaire de preuve, reste comme retour arrière.
- **Les migrations se jouent une fois, sur décision du déploiement**, jamais à chaque démarrage, et jamais par un processus lancé dans une session SSH quand l'hébergeur la réserve aux commandes courtes (cas mesuré : elles se jouent au seul démarrage qui suit un déploiement, signalé par un témoin que le lanceur efface).
- **Le déploiement se répète en local avant d'aller chez l'hébergeur.** Une cible jetable qui lui ressemble (même distribution, un compte sans privilège joignable par SSH, aucun compilateur, une base à login sans privilège) reçoit le **vrai script**, deux fois : le second passage prouve qu'aucune migration n'est rejouée, que les données et la configuration sont intactes et que la version précédente est gardée. Le smoke e2e du projet vise alors l'adresse de la cible, puis, inchangé, l'adresse publique. Cette répétition est un gate du projet (`deploiement` dans les kits, `KITS.md`) ; elle ne prouve pas l'hébergeur, elle évite d'y découvrir les défauts du script.
- **Le cycle de vie est celui de l'hébergeur.** Cas mesuré : un site sans requête est arrêté après 30 minutes et ne repart qu'à la requête suivante, ce qui arrête les tâches de fond ; une seule instance par site, même pendant un redémarrage. On règle l'inactivité à 0, on ajoute une tâche planifiée qui appelle la sonde de santé chaque minute, et l'on monte en capacité en changeant d'offre ou en découpant en plusieurs sites.

## Reprendre une instance sans que l'utilisateur le voie

L'outil qui objective est la **comparaison avec la source** : même nombre de lignes dans chaque table, réponses publiques identiques octet pour octet, accès administrateur, refus (401) sans jeton, journaux sans erreur. **Chaque différence s'explique ou bloque** (cas mesuré : 8 réponses publiques sur 10 identiques ; les 2 autres portaient les champs d'une version plus récente que la source, et une seule migration de plus séparait les deux bases).

Une preuve échappe à la machine : **une connexion réelle, faite par l'humain**. Elle seule prouve que la clé de chiffrement de l'instance d'origine a suivi ; sans cette clé, les seconds facteurs des comptes sont illisibles. Tant que cette connexion n'est pas faite, on écrit **« connexion non prouvée »**, quoi que disent les autres preuves.

La reprise se **répète en entier en local** (même version de base, login sans privilège) avant d'être jouée chez l'hébergeur. La copie porte de vrais comptes et se trouve sur Internet : on ne diffuse pas son adresse, on n'envoie aucun courriel pendant la répétition, et l'export est supprimé du poste.

## Conditionnement par archétype

- **stateless** — sondes du type de site, de la chaîne de compilation, du cycle de vie et des journaux ; ni base ni reprise.
- **stateful** — sondes de la base managée, **rejeu des tests avec le login sans privilège**, reprise prouvée contre la source. Les sauvegardes de l'hébergeur ont une durée (cas mesuré : 7 jours glissants) : une copie hors de l'hébergeur et une restauration essayée restent à la charge du projet.
- **API-first** — le contrat ne change pas avec l'hébergeur : les réponses publiques comparées octet pour octet en sont la preuve.
- **full-stack** — un site statique par nom d'hôte, servi depuis le lien de la version courante ; sur ces hôtes, seule l'API publique est ouverte vers l'application ; puis la bascule de domaine.

## Points irréversibles

*Louer le réversible, posséder l'irréversible.* À chacun de ces points, tu présentes la preuve et **l'humain valide** (`../pilote/arbitrage.md`) :

- **Garder ou changer de framework, remplacer la plateforme d'origine** : décisions de l'humain, tracées en ADR, prises après la sonde.
- **Changer le mode d'isolation** : ADR qui amende l'ADR d'origine.
- **Le modèle d'exploitation** (cas mesuré : une instance et une base par client, déploiement d'une version nommée, branches de client qui suivent la branche principale par fusion, aucune migration de schéma sur une branche de client).
- **La clé de chiffrement et les secrets d'une instance reprise** : ils passent d'un serveur à l'autre sans être écrits sur le poste ni affichés. Une clé perdue ne se retrouve pas.
- **La restauration** : elle se fait dans une base vide. La remise à zéro de la base s'essaie tant qu'elle est vide ; après, elle détruit des données.
- **La bascule de domaine** : **le DNS est basculé par l'humain**, jamais par l'agent.
- **Le passage à des données réelles**, et la **nature des données** : sans certification d'hébergeur de données de santé relevée, jamais de donnée de santé.
- **Une exception sur un gate** (par exemple une dépendance signalée comme non maintenue, sans rapport avec le changement) : remontée à l'humain, qui décide une exception **datée**.

## Conformité de l'hébergeur

Changer d'hébergeur change le sous-traitant. Avant toute donnée réelle, on **lit les conditions générales** et l'on relève : le contrat de sous-traitance au sens de l'article 28 du RGPD, le lieu d'hébergement, le chiffrement au repos, les sauvegardes, le sort des données en fin de contrat, le délai de notification des violations, et les annexes qui renvoient à des documents non joints, à demander. On met à jour les **mentions légales** et le **registre des traitements**. Le relevé du cas mesuré est dans le rôle ; le cadre est dans `conformite.md`.

## Condition de sortie

On reboucle **tant qu'une sonde réfute une supposition**, qu'un test échoue avec le login sans privilège, qu'une comparaison avec la source diffère ou qu'un gate du plancher est rouge. Cas mesuré : trois alertes de sécurité publiées la veille sur une dépendance du serveur HTTP ont rendu le plancher rouge en cours de route ; la correction a été une montée de version, puis un redéploiement.

On sort quand l'instance répond à son adresse provisoire, que toutes les preuves de reprise sont réunies, que la bascule de domaine est **préparée et testée sans toucher au DNS**, et que le registre dit ce qui n'est pas prouvé. La sortie de l'agent n'est pas la mise en service : celle-ci appartient à l'humain, qui bascule le DNS.

## Ce que ce skill ne remplace pas

`convergence-iac.md` vaut pour un serveur **que l'on administre** : on déclare l'état désiré, on l'applique, et la ré-application sans diff prouve la convergence. Ici, rien de cela :

- **on n'administre pas le serveur** : système, base, frontal et mises à jour de sécurité sont à l'hébergeur, le durcissement du système aussi ;
- **on ne décrit pas l'infrastructure en code** : l'état du compte (sites, bases, tâches planifiées, certificats) **se lit par l'API de l'hébergeur**, il ne s'applique pas depuis un dépôt ;
- **il n'y a pas de réconciliateur** : la surveillance est une sonde de santé appelée par une tâche planifiée, et les journaux de l'hébergeur.

Ce que l'hébergeur ne prend pas reste au projet : l'application, ses dépendances, sa configuration, ses données, et **la preuve qu'une sauvegarde se restaure**. Ce skill ne remplace pas non plus `gates.md` (les mêmes gates, rejoués sur la version de base de la cible) ni `conformite.md`.

## Coût

**Peu de tokens, fort wall-clock**, comme tout terrain qui se prouve par exécution : chaque sonde attend l'hébergeur, et plusieurs preuves attendent l'humain (connexion réelle, bascule du DNS). Nombre de tours par déploiement : `[caler]`. La sonde coûte peu au regard de ce qu'elle évite (cas mesuré : la réécriture de 453 routes).

---

*Registre guidance ; le blocage (gates, garde au démarrage, refus du retour arrière) est l'enforcement. Dérivé du Manifeste Maury (CC BY-SA 4.0).*
