"""Cas d'usage : révoquer le jeton présenté (déconnexion). Sans effet s'il est déjà inconnu."""
from __future__ import annotations

from app.application.identity.fingerprint import fingerprint
from app.domain.identity.ports import TokenRepository


class LogOut:
    def __init__(self, tokens: TokenRepository, secret_key: str) -> None:
        self._tokens = tokens
        self._key = secret_key

    def execute(self, token_value: str) -> dict:
        self._tokens.revoke(fingerprint(self._key, token_value))
        return {"loggedOut": True}
