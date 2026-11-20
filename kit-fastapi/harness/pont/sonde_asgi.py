"""Sonde du pont ASGI→WSGI (montage B). Application ASGI minimale qui exerce ce qu'un pont peut
perdre : le cycle de vie (lifespan), une tâche de fond permanente, une tâche après réponse, une
réponse en flux, un WebSocket. Jouée sous uWSGI par harness/pont/essayer.sh ; ses résultats sont
ceux que cite le guide de déploiement. Ne fait pas partie de l'application."""
from __future__ import annotations

import asyncio
import contextlib
import os
import threading
import time

from starlette.applications import Starlette
from starlette.background import BackgroundTask
from starlette.responses import JSONResponse, StreamingResponse
from starlette.routing import Route, WebSocketRoute

ETAT = {"lifespan": False, "tics": 0, "apres_reponse": False, "fil_tics": 0}
_fil_lance = False


def _lancer_fil() -> None:
    """Un fil ordinaire, lancé à la première requête du processus : avance-t-il quand uWSGI ne
    sert rien ? (Sans `enable-threads`, uWSGI garde le verrou de l'interpréteur entre deux requêtes.)"""
    global _fil_lance
    if _fil_lance:
        return
    _fil_lance = True

    def tic() -> None:
        while True:
            ETAT["fil_tics"] += 1
            time.sleep(0.05)

    threading.Thread(target=tic, daemon=True).start()


@contextlib.asynccontextmanager
async def lifespan(app):
    ETAT["lifespan"] = True

    async def tic() -> None:
        while True:
            ETAT["tics"] += 1
            await asyncio.sleep(0.1)

    tache = asyncio.create_task(tic())
    yield
    tache.cancel()


async def etat(_):
    _lancer_fil()
    return JSONResponse({**ETAT, "pid": os.getpid(), "fils": threading.active_count()})


async def flux(_):
    async def morceaux():
        for i in range(4):
            yield f"{time.monotonic():.3f} morceau {i}\n"
            await asyncio.sleep(0.5)
    return StreamingResponse(morceaux(), media_type="text/plain")


def _marquer() -> None:
    time.sleep(0.5)
    ETAT["apres_reponse"] = True


async def fond(_):
    return JSONResponse({"lance": True}, background=BackgroundTask(_marquer))


async def ws(websocket):
    await websocket.accept()
    await websocket.send_text("bonjour")
    await websocket.close()


app = Starlette(lifespan=lifespan, routes=[
    Route("/etat", etat), Route("/flux", flux), Route("/fond", fond), WebSocketRoute("/ws", ws),
])
