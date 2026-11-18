"""Point d'entrée ASGI — `uvicorn app.http.app:app` (et, par le pont, `wsgi.py` sous uWSGI).

Sélectionne l'adaptateur HTTP — FastAPI (défaut) ou Starlette (ASGI nu) — via TODO_HTTP. Les deux
exposent le MÊME contrat et délèguent aux mêmes cas d'usage. L'application choisie est enveloppée
par `Hardening` (en-têtes de sécurité, erreur 500 générique), identique pour les deux.

La configuration est validée ICI, au démarrage : sans clé d'instance hors développement,
l'application refuse de démarrer plutôt que de servir avec des empreintes sans clé."""
from __future__ import annotations

import logging
import os

from app import config
from app.http.hardening import Hardening

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
config.secret_key()
config.public_origin()
config.session_ttl()
config.bearer_ttl()

if os.environ.get("TODO_HTTP", "fastapi").lower() == "starlette":
    from app.http.starlette_app import app as _inner
else:
    from app.http.api import app as _inner

app = Hardening(_inner)
