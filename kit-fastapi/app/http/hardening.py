"""Enveloppe ASGI pure, commune aux deux adaptateurs HTTP et aux deux montages (uvicorn, uWSGI).

1. En-têtes de sécurité sur TOUTES les réponses (API, pages, fichiers statiques, erreurs) :
   sur un hébergement infogéré, aucun frontal ne les ajoute à notre place.
2. Dernier filet : une exception qui remonte jusqu'ici devient une réponse 500 générique, et une
   ligne au journal. Jamais de trace ni de message de pilote dans une réponse."""
from __future__ import annotations

import asyncio
import json
import logging

from app.http.common import GENERIC_ERROR

log = logging.getLogger("todo")

SECURITY_HEADERS = (
    # Ignoré par les navigateurs hors HTTPS, donc sans effet sur un poste en http.
    (b"strict-transport-security", b"max-age=63072000; includeSubDomains"),
    (b"x-content-type-options", b"nosniff"),
    # Interdiction d'inclusion en cadre : l'en-tête historique et sa forme CSP.
    (b"x-frame-options", b"DENY"),
    (b"content-security-policy",
     b"default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"),
    (b"referrer-policy", b"no-referrer"),
)
_NAMES = {name for name, _ in SECURITY_HEADERS}
# Aucun corps de l'API ne dépasse quelques centaines d'octets : la borne est large, et fixe.
MAX_BODY = 16 * 1024
# Un corps refusé est tout de même LU avant la réponse, dans ces deux limites. Répondre puis fermer
# sans le lire coupe la connexion pendant que le frontal écrit encore : il perd alors la réponse, et
# le client ne reçoit rien au lieu du 413. Au-delà des limites, on répond sans lire.
DRAIN_MAX = 1024 * 1024
DRAIN_SECONDS = 5.0


class Hardening:
    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        started = False
        is_api = scope.get("path", "").startswith("/api/")

        async def send_hardened(message) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
                headers = [(k, v) for k, v in message.get("headers", []) if k.lower() not in _NAMES]
                headers.extend(SECURITY_HEADERS)
                if is_api and not any(k.lower() == b"cache-control" for k, _ in headers):
                    headers.append((b"cache-control", b"no-store"))
                message = {**message, "headers": headers}
            await send(message)

        async def refuse(status: int, message: str) -> None:
            body = json.dumps({"error": message}, ensure_ascii=False).encode("utf-8")
            await send_hardened({
                "type": "http.response.start", "status": status,
                "headers": [(b"content-type", b"application/json"),
                            (b"content-length", str(len(body)).encode()), (b"connection", b"close")],
            })
            await send({"type": "http.response.body", "body": body})

        async def drain() -> None:
            seen = 0
            while seen <= DRAIN_MAX:
                message = await receive()
                if message["type"] != "http.request":
                    return
                seen += len(message.get("body", b""))
                if not message.get("more_body"):
                    return

        async def refuse_after_drain(status: int, message: str) -> None:
            try:
                await asyncio.wait_for(drain(), DRAIN_SECONDS)
            except TimeoutError:
                pass
            await refuse(status, message)

        # Taille du corps bornée AVANT tout traitement : longueur annoncée trop grande → 413 ; corps
        # sans longueur annoncée (envoi par morceaux) → 411, sa taille ne pouvant être bornée d'avance.
        headers_in = {k.lower(): v for k, v in scope.get("headers", [])}
        length = headers_in.get(b"content-length")
        if length is not None:
            if not length.isdigit():
                await refuse(400, "Requête invalide.")
                return
            if int(length) > DRAIN_MAX:
                await refuse(413, "Corps trop volumineux.")
                return
            if int(length) > MAX_BODY:
                await refuse_after_drain(413, "Corps trop volumineux.")
                return
        elif b"transfer-encoding" in headers_in:
            await refuse_after_drain(411, "Longueur du corps requise.")
            return

        try:
            await self.app(scope, receive, send_hardened)
        except Exception as exc:  # noqa: BLE001 — dernier filet, voir l'en-tête du module
            log.error("erreur interne sur %s %s : %s", scope.get("method"), scope.get("path"),
                      type(exc).__name__)
            if not started:
                body = json.dumps(GENERIC_ERROR, ensure_ascii=False).encode("utf-8")
                await send_hardened({
                    "type": "http.response.start", "status": 500,
                    "headers": [(b"content-type", b"application/json"),
                                (b"content-length", str(len(body)).encode())],
                })
                await send({"type": "http.response.body", "body": body})
