"""Entrée WSGI de la sonde du pont. SONDE_PONT=direct : le pont est créé à l'import (ce que fait
un `application = ASGIMiddleware(app)` naïf). SONDE_PONT=paresseux (défaut) : il est créé dans le
processus qui sert, à la première requête — ce que fait le `wsgi.py` du kit."""
from __future__ import annotations

import os
import sys
import threading

sys.path.insert(0, os.environ["SONDE_DEPS"])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from a2wsgi import ASGIMiddleware  # noqa: E402

from sonde_asgi import app  # noqa: E402

if os.environ.get("SONDE_PONT", "paresseux") == "direct":
    application = ASGIMiddleware(app)
else:
    _verrou = threading.Lock()
    _pont = None
    _pid = None

    def application(environ, start_response):
        global _pont, _pid
        if _pid != os.getpid():
            with _verrou:
                if _pid != os.getpid():
                    _pont, _pid = ASGIMiddleware(app), os.getpid()
        return _pont(environ, start_response)
