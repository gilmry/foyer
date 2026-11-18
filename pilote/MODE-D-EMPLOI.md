# Mode d'emploi du pilote Foyer

Pour la personne qui **conduit un projet avec le pilote**, du premier message à la mise en ligne.
Ce guide dit quoi taper, quoi préparer et à quoi s'attendre. Il ne redit pas la méthode : chaque
section renvoie au fichier qui fait autorité. Vue d'ensemble : [`README.md`](README.md).

## 1. Démarrer

| Vous êtes | Vous faites |
|---|---|
| **Dev, sur Claude Code** | Ouvrir Claude Code **à la racine du dépôt Foyer** et taper `/foyer`, suivi si vous voulez d'une phrase qui décrit l'application. Rien à installer. |
| **PO, sur ChatGPT ou Qwen** | Coller [`adapters/generic/PROMPT-PO.md`](adapters/generic/PROMPT-PO.md), joindre `parcours.md` et le registre du projet s'il existe. |
| **Sur un autre outil** (OpenCode, Codex, Aider) | Donner [`BOOTSTRAP.md`](BOOTSTRAP.md) à l'agent. |

Le pilote pose alors **une** question (nouveau projet, rétrofit, release ou exploitation), puis
crée le **registre d'état** du projet. Le projet vit **à côté** du dépôt Foyer (`../<nom-du-projet>`),
jamais dedans. Relancer `/foyer` plus tard propose de reprendre ce projet là où il en était.

Pour un travail long, ouvrez ensuite la session dans le dossier du projet (ou `/add-dir <projet>`).

## 2. Les quatre commandes

| Commande | Ce qu'elle fait | Quand |
|---|---|---|
| `/foyer` | amorce ou reprend un projet | au début, et à chaque reprise |
| `/foyer-status` | dit où on en est : étape, gates, arbitrages en attente. Ne change rien | à tout moment |
| `/foyer-next` | exécute la prochaine étape du parcours, jusqu'au prochain arrêt | pour avancer |
| `/foyer-bascule` | prépare un point irréversible et vous pose la question d'arbitrage | quand le pilote annonce 🔴 |

Sans Claude Code, les mêmes demandes se font en clair : « statut », « prochaine étape ».

## 3. Le registre : ce que vous lisez, ce que vous décidez

Le registre (`PROJET.md`, `RELEASE.md` ou `RETROFIT.md`, à la racine du projet) est la source de
vérité, **commitée**, partagée entre le dev et le PO. Gabarit : [`state.template.md`](state.template.md).

Le pilote ne vous pose que deux sortes de questions :

- des **questions métier**, en langage clair. Tout choix technique réversible est un défaut
  annoncé, pas une question ([`defaults.md`](defaults.md)) ;
- des **arbitrages** 🔴, aux points irréversibles. Il a déjà réuni la preuve ; il vous demande
  **comment** y aller (moment, ordre, retour arrière), jamais s'il faut y aller
  ([`arbitrage.md`](arbitrage.md)).

Un **gate rouge** arrête le pilote : il corrige la cause, il ne force pas.

## 4. Mettre en ligne : ce que vous préparez, une fois

Quand tous les gates bloquants sont verts, gate `deploiement` compris, le pilote **livre sans
qu'on le lui demande** (phase L des parcours). Il lui faut trois choses, que vous posez une fois.

**a. La cible, au registre.** La première fois, le pilote demande « où met-on l'application en
ligne ? ». Répondez : l'hébergeur, l'**alias SSH** du poste (une entrée de `~/.ssh/config`), le nom
de l'instance, l'adresse publique. Il l'inscrit au registre et ne redemande plus. Si vous ne livrez
pas par ce moyen, répondez « aucune » : il l'inscrit aussi.

**b. Ce qui identifie le compte, hors de git.** Le registre est commité : il ne porte ni jeton, ni
mot de passe, ni nom de compte. Le pilote range le nom du compte dans `.foyer/cible.env` du
projet, après avoir vérifié que git ignore ce dossier.

**c. Le jeton d'API de l'hébergeur, dans le `.env` du projet.** C'est vous qui l'y posez, à la
main, jamais dans la conversation :

```
ALWAYSDATA_TOKEN=<votre jeton>
```

Vérifiez que `.env` est ignoré par git (`git check-ignore .env`). Avec ce jeton, le script du kit
crée lui-même la base, son utilisateur et le site s'ils manquent, et redémarre le site. Sans lui,
sur une instance jamais préparée, il s'arrête avant tout envoi et dit quoi créer à la main dans
l'administration de l'hébergeur ; sur une instance déjà préparée, il envoie la version mais ne
peut pas redémarrer le site. **La livraison autonome et le retour arrière automatique supposent
donc le jeton.**

Si le smoke du kit demande des comptes d'essai (voir le guide `deploiement/<hébergeur>/README.md`
du kit), rangez-les aussi dans un fichier local ignoré par git : le pilote les y charge, il ne les
affiche pas.

## 5. Ce que fait le pilote à chaque livraison

Référence : [`roles/deployeur-heberge.md`](roles/deployeur-heberge.md), séquence B.

1. Il vérifie que tous les gates sont verts sur le dernier commit et que l'arbre de travail est
   propre. La **répétition locale** du déploiement (gate `deploiement`) fait partie des gates.
2. Il cherche une **migration de schéma** entre la version en service et la version à livrer.
3. Il joue le script de déploiement du projet.
4. Il prouve par **un seul passage** du smoke contre l'adresse publique, au profil public.
5. Vert : il inscrit au registre la version en service, son commit et la version précédente.

Une première mise en ligne (ou la reprise d'une instance existante) suit une séquence plus
longue, avec des sondes de l'hébergeur et, s'il y a un domaine à basculer, un arbitrage : séquence A
du même rôle.

## 6. Quand le pilote s'arrête, et ce qu'il fait seul

| Situation | Ce que fait le pilote | Ce qu'on attend de vous |
|---|---|---|
| Un gate est rouge | rien n'est envoyé ; il corrige la cause | rien |
| La release porte une **migration de schéma** | arrêt **avant tout envoi**, arbitrage 🔴 | dire si la sauvegarde est vérifiée, à quel moment migrer, et que faire si le smoke échoue |
| Le smoke public est rouge après la livraison | il **remet la version précédente** sans demander, rejoue le smoke une fois, écrit l'échec au registre | rien ; la cause repart en correction |
| Le smoke est encore rouge après le retour arrière | arrêt, arbitrage 🔴 « instance dégradée » | décider |
| **Bascule d'un nom de domaine** | il prépare tout et s'arrête | **vous** basculez le DNS |
| **Passage à des données réelles** | arrêt, arbitrage 🔴 | décider |
| Pas de jeton d'API, instance jamais préparée | le script s'arrête et dit quoi créer | poser le jeton, ou créer base et site à la main |
| Pas de jeton d'API, instance déjà préparée | la version est envoyée, le site n'est pas redémarré : il s'arrête, sans smoke ni inscription | poser le jeton, ou redémarrer le site dans l'administration |
| Le script de retour arrière sort en erreur | arrêt, arbitrage 🔴 ; il ne le rejoue pas | décider |

Les deux arrêts « domaine » et « données réelles » ne se présentent pas dans une livraison de
routine, qui ne touche ni au DNS ni à la nature des données. Cette règle est la recommandation
retenue par défaut le 2026-11-18 ([`arbitrage.md`](arbitrage.md)) ; elle reste à confirmer.

Le retour arrière remet le **code**, pas le schéma de la base : c'est pour cela qu'une migration
arrête le pilote avant l'envoi.

## 7. Faire les mêmes gestes à la main

Les commandes exactes sont dans l'`AGENTS.md` du projet. Dans un projet issu d'un kit Foyer :

```bash
bash harness/repeter-deploiement.sh                                   # répétition locale (gate)
bash deploiement/alwaysdata/deployer.sh <alias ssh> <compte> <instance> https://<adresse>
E2E_PROFIL=public E2E_BASE_URL=https://<adresse> bash harness/e2e-smoke.sh   # un seul passage
bash deploiement/alwaysdata/revenir.sh  <alias ssh> <compte> <instance> https://<adresse>
```

Le smoke de certains kits demande des comptes d'essai en variables : voir le guide du kit.

## 8. Trois règles chez l'hébergeur

Elles viennent de déploiements réels ; le pourquoi est dans
[`../skills/deploiement-heberge-infogere.md`](../skills/deploiement-heberge-infogere.md).

- **Un seul passage du smoke, au profil public.** Rejouer le parcours complet en rafale a fait
  bloquer l'adresse du poste par le frontal de l'hébergeur, pour tous les sites du compte.
- **Jamais de test de charge chez l'hébergeur**, ni de processus long dans une session SSH.
- **Une adresse neuve attend son certificat**, quelques minutes : le script patiente, ne le relancez pas.

## 9. Ce qui est prouvé, et ce qui ne l'est pas

- **Prouvé chez l'hébergeur** (2026-11-18) : le déploiement des trois kits par leur script **dans
  sa version d'alors** (base et site créés à la main, redémarrage demandé à part), joué deux fois,
  et leur smoke contre l'adresse publique.
- **Prouvé par la répétition locale seulement** : le script actuel, qui crée la base et le site par
  l'API, redémarre et attend (contre un faux serveur d'API), et le script de retour arrière.
- **Non prouvé** : la phase L menée de bout en bout par le pilote sur un projet réel, et le
  chargement des sous-agents par Claude Code.

## 10. Où chercher

| Question | Fichier |
|---|---|
| Quelle étape vient après ? | [`parcours.md`](parcours.md), [`journeys/`](journeys/) |
| Qui joue cette étape ? | [`README.md`](README.md), tableaux persona et skill ; [`roles/`](roles/) |
| Pourquoi cette question m'est-elle posée ? | [`arbitrage.md`](arbitrage.md), [`defaults.md`](defaults.md) |
| Qu'est-ce qu'un gate, comment le lancer ? | [`gates/README.md`](gates/README.md), `AGENTS.md` du projet |
| Comment déployer ce kit ? | `deploiement/alwaysdata/README.md` du kit |
