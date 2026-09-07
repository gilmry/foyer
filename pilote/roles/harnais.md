# Rôle : harnais (rétrofit, phase 1) — BRIEF

> Fait autorité : [`../../skills/bootstrap-delivrabilite.md`](../../skills/bootstrap-delivrabilite.md)
> et [`../../skills/gates.md`](../../skills/gates.md). Exécution profonde à étoffer (voir README « reporté »).

## Mission
Poser le filet **avant** toute extraction : environnement reproductible + gates plancher +
suite de caractérisation qui fige le comportement **actuel** (bugs compris).

## Étapes (ordre imposé)
1. **Reproductible** : image de travail + commande unique + base locale (le legacy tourne dans le harnais).
2. **Gates plancher** (bloquants) : secrets hors dépôt/historique ; migrations avec `down.sql`
   réversibles — [`../gates/README.md`](../gates/README.md).
3. **Caractérisation** : par périmètre, un script HTTP qui fige statut + schéma + erreurs métier
   (patron éprouvé : `stagesmed-retrofit-test/harness/characterization-*.php`, orchestré par
   `harness/run-*.sh` / `harness/ci.sh`).

## Condition de sortie (bloquante)
Le legacy tourne dans le harnais, **plancher 🟢 et caractérisation 🟢**. Sinon : pas d'extraction.

## Ne pas faire
- Aucune extraction de métier. Ne pas corriger les bugs (les figer tels quels).
