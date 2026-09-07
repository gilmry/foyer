# Adaptateur générique — PO sur ChatGPT / Qwen (ou tout modèle sans accès dépôt)

> Pour les modèles qui **ne lisent pas** automatiquement le dépôt (ChatGPT/Qwen web). Le PO
> copie-colle. Le cœur reste `pilote/BOOTSTRAP.md` — ce fichier ne fait que l'emballer pour un
> chat sans fichiers.

## Mode d'emploi (PO)
1. Ouvre `pilote/BOOTSTRAP.md` du dépôt cloné, **copie tout son contenu**.
2. Colle-le dans ChatGPT/Qwen, précédé de la ligne ci-dessous.
3. Quand l'agent demande de « charger le cœur », colle-lui `pilote/parcours.md` et, s'il existe,
   le **registre d'état** du projet (`RETROFIT.md` / `RELEASE.md` / `PROJET.md`).
4. Réponds à **Q0** (nouveau / rétrofit / release). Ensuite, demande quand tu veux : « statut »,
   « prochaine étape », ou traite un **arbitrage 🔴** qu'on te présente.

## Ligne d'amorce à coller devant BOOTSTRAP.md
```
Tu es le pilote Foyer pour mon projet. Suis STRICTEMENT les instructions ci-dessous.
Tu n'as pas accès à mon dépôt : quand tu as besoin d'un fichier, demande-le-moi et je te le colle.
Ne tranche jamais seul un point irréversible : présente-moi la preuve et une question de modalité.
--- BOOTSTRAP.md ---
```

## Ce que le PO fait (et ne fait pas)
- **Fait** : choisit la porte ; lit l'état ; **tranche les modalités** (timing, séquençage,
  rollback) qu'on lui présente ; valide les bascules sur preuve.
- **Ne fait pas** : le code (c'est le dev sur Claude Code / OpenCode) ; ne change pas la
  **destination** (kit hexagonal + îlots — non négociable) ; ne force pas un gate rouge.

## Synchronisation PO ↔ dev
Le PO et le dev travaillent sur **le même registre d'état** (commité). Quand le PO tranche un
arbitrage, il l'écrit (ou demande à l'agent de l'écrire) au registre + ADR ; le dev reprend de là.
