"""Enveloppe ASGI pure, commune aux deux adaptateurs HTTP et aux deux montages (uvicorn, uWSGI).

1. En-têtes de sécurité sur TOUTES les réponses (API, pages, fichiers statiques, erreurs) :
   sur un hébergement infogéré, aucun frontal ne les ajoute à notre place.
2. Dernier filet : une exception qui remonte jusqu'ici devient une réponse 500 générique, et une
   ligne au journal. Jamais de trace ni de message de pilote dans une réponse."""
from __future__ import annotations

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

        # Taille du corps bornée AVANT toute lecture : longueur annoncée trop grande → 413 ; corps
        # sans longueur annoncée (envoi par morceaux) → 411, sa taille ne pouvant être bornée d'avance.
        headers_in = {k.lower(): v for k, v in scope.get("headers", [])}
        length = headers_in.get(b"content-length")
        if length is not None:
            if not length.isdigit():
                await refuse(400, "Requête invalide.")
                return
            if int(length) > MAX_BODY:
                await refuse(413, "Corps trop volumineux.")
                return
        elif b"transfer-encoding" in headers_in:
            await refuse(411, "Longueur du corps requise.")
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
