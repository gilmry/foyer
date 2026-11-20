"""Point d'entrée WSGI — montage B : site « Python » de l'hébergeur, servi par uWSGI.

FastAPI et Starlette parlent ASGI, uWSGI parle WSGI : le pont `a2wsgi` (Apache-2.0) traduit.
Ce fichier fait, pour uWSGI, ce que `deploiement/alwaysdata/lancer.sh` fait pour uvicorn :
  1. il ajoute au chemin Python le code de SA version et ses dépendances préparées
     (`versions/<id>/` et `versions/<id>/deps/` sur le serveur ; le dépôt lui-même sur un poste) ;
  2. il lit `.env`, dans le dossier de l'instance (droits 600 exigés) ;
  3. il joue les migrations si le témoin `.migrer` lui est adressé, une seule fois même si
     plusieurs processus démarrent ensemble, puis efface le témoin ; si elles échouent, il ne sert pas.

LIMITES DU PONT, essayées par harness/pont/essayer.sh (voir le guide) : pas de cycle de vie ASGI
(lifespan), pas de WebSocket. Fils de uWSGI (`enable-threads`) : à activer par prudence.
Le pont porte une boucle d'événements dans un fil : il est donc créé DANS le processus qui sert,
à sa première requête, jamais à l'import — un fil ne survit pas au dédoublement des processus."""
from __future__ import annotations

import os
import shlex
import stat
import sys
import threading
from pathlib import Path

# Sur le serveur, ce fichier vit DANS sa version (`versions/<id>/wsgi.py`) et le site y accède par
# le lien `wsgi.py -> courant/wsgi.py` : la bascule du lien `courant` change d'un seul coup le
# point d'entrée, le code et les dépendances. RACINE = la version à laquelle CE fichier appartient ;
# ICI = le dossier de l'instance, où sont `.env` et le témoin `.migrer`.
RACINE = Path(__file__).resolve().parent
SUR_SERVEUR = RACINE.parent.name == "versions"
ICI = RACINE.parent.parent if SUR_SERVEUR else RACINE
for _chemin in (RACINE, RACINE / "deps"):
    if _chemin.is_dir() and str(_chemin) not in sys.path:
        sys.path.insert(0, str(_chemin))


def _lire_env(fichier: Path) -> None:
    """Même syntaxe que le shell qui lit ce fichier dans lancer.sh : NOM='valeur', une par ligne."""
    if not fichier.is_file():
        return
    if stat.S_IMODE(fichier.stat().st_mode) & 0o077:
        raise RuntimeError(f"{fichier} doit être à droits 600 : il porte des secrets")
    for ligne in fichier.read_text(encoding="utf-8").splitlines():
        ligne = ligne.strip()
        if not ligne or ligne.startswith("#") or "=" not in ligne:
            continue
        nom, valeur = ligne.split("=", 1)
        os.environ[nom.strip()] = "".join(shlex.split(valeur))


def _temoins(dossier: Path, version: str) -> list[Path]:
    """Témoins de migration adressés à CETTE version (le témoin porte l'identifiant de la version
    qui doit migrer : un réveil de l'ancienne version, pendant un déploiement, ne le consomme pas)."""
    trouves = []
    for temoin in (dossier / ".migrer", *dossier.glob(".migrer.*")):
        try:
            if temoin.read_text(encoding="utf-8").strip() == version:
                trouves.append(temoin)
        except FileNotFoundError:
            pass
    return trouves


def _migrer_si_demande(dossier: Path, version: str) -> None:
    """Tout processus qui voit le témoin lance lui-même `migrate up` : l'outil se sérialise par un
    verrou consultatif en base et ne rejoue rien de ce qui est passé, donc N processus qui démarrent
    ensemble migrent une seule fois, et chacun ne sert qu'APRÈS avoir constaté une base à jour.
    Échec, ou processus tué en route : le témoin reste, ce processus ne sert pas, le suivant réessaie."""
    temoins = _temoins(dossier, version)
    if not temoins:
        return
    from app import migrate
    if migrate.main(["migrate", "up"]) != 0:
        raise RuntimeError("les migrations ont échoué : le témoin .migrer reste, voir le journal du site")
    for temoin in temoins:
        temoin.unlink(missing_ok=True)


_lire_env(ICI / ".env")
if SUR_SERVEUR:
    _migrer_si_demande(ICI, RACINE.name)

from a2wsgi import ASGIMiddleware  # noqa: E402

from app.http.app import app as _asgi  # noqa: E402

_verrou = threading.Lock()
_pont = None
_pid = None


def application(environ, start_response):
    global _pont, _pid
    if _pid != os.getpid():
        with _verrou:
            if _pid != os.getpid():
                _pont, _pid = ASGIMiddleware(_asgi), os.getpid()
    return _pont(environ, start_response)
