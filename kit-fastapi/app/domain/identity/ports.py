"""Ports de l'identité — implémentés par des adaptateurs (persistance, Argon2, aléa)."""
from __future__ import annotations

from datetime import datetime
from typing import Protocol

from .account import Account
from .token import AccessToken


class AccountRepository(Protocol):
    def find_by_email(self, email: str) -> Account | None: ...

    def find(self, account_id: str) -> Account | None: ...

    def add(self, account: Account) -> bool:
        """False si le courriel est déjà pris (rien n'est écrit)."""
        ...


class PasswordHasher(Protocol):
    def hash(self, password: str) -> str: ...

    def verify(self, password_hash: str, password: str) -> bool:
        """Comparaison en temps constant ; False pour un hachage illisible."""
        ...

    def dummy_verify(self, password: str) -> None:
        """Même travail qu'un `verify`, sans compte : égalise le temps de réponse d'un compte
        inconnu et d'un mauvais mot de passe."""
        ...


class TokenGenerator(Protocol):
    def new_token(self) -> str:
        """Valeur imprévisible, au moins 256 bits d'aléa."""
        ...


class TokenRepository(Protocol):
    def add(self, token: AccessToken) -> None: ...

    def find(self, token_hash: str) -> AccessToken | None: ...

    def revoke(self, token_hash: str) -> None: ...

    def purge_expired(self, now: datetime) -> None: ...


class LoginAttempts(Protocol):
    """Essais de connexion échoués, par sujet (empreinte du courriel visé)."""

    def reserve(self, attempt_id: str, subject: str, at: datetime, since: datetime) -> int:
        """Enregistre l'essai et rend le nombre d'essais du sujet depuis `since`, celui-ci compris.
        ATOMIQUE par sujet : deux appels simultanés ne peuvent pas rendre le même rang."""
        ...

    def remove(self, attempt_id: str) -> None: ...

    def clear(self, subject: str) -> None: ...

    def purge_before(self, before: datetime) -> None: ...
