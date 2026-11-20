"""Cas d'usage : retrouver l'identité portée par un jeton (cookie de session ou jeton porteur).
Rend None si le jeton est inconnu, révoqué, échu, ou d'un autre type que celui attendu."""
from __future__ import annotations

from app.application.identity.fingerprint import fingerprint
from app.domain.identity.current_user import CurrentUser
from app.domain.identity.ports import TokenRepository
from app.domain.todo.clock import Clock


class ResolveIdentity:
    def __init__(self, tokens: TokenRepository, clock: Clock, secret_key: str) -> None:
        self._tokens = tokens
        self._clock = clock
        self._key = secret_key

    def execute(self, token_value: str, kind: str) -> CurrentUser | None:
        if not token_value:
            return None
        # La recherche se fait par l'empreinte : la valeur claire n'est jamais comparée en base.
        token = self._tokens.find(fingerprint(self._key, token_value))
        if token is None or token.kind != kind or token.is_expired(self._clock.now()):
            return None
        return CurrentUser(account_id=token.account_id)
