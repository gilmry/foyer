"""Doubles in-memory des ports d'identité (aucune DB, aucun Argon2)."""
from __future__ import annotations

from datetime import datetime

from app.domain.identity.account import Account
from app.domain.identity.token import AccessToken


class FakeAccountRepository:
    def __init__(self) -> None:
        self.by_id: dict[str, Account] = {}

    def find_by_email(self, email: str) -> Account | None:
        return next((a for a in self.by_id.values() if a.email == email), None)

    def find(self, account_id: str) -> Account | None:
        return self.by_id.get(account_id)

    def add(self, account: Account) -> bool:
        if self.find_by_email(account.email) is not None:
            return False
        self.by_id[account.id] = account
        return True


class FakePasswordHasher:
    """Hachage reconnaissable et NON réversible à l'œil : suffit à prouver qu'on ne stocke pas le clair."""

    def __init__(self) -> None:
        self.dummy_calls = 0

    def hash(self, password: str) -> str:
        return "fake$" + password[::-1].encode("utf-8").hex()

    def verify(self, password_hash: str, password: str) -> bool:
        return password_hash == self.hash(password)

    def dummy_verify(self, password: str) -> None:
        self.dummy_calls += 1


class FakeTokenGenerator:
    def __init__(self) -> None:
        self._seq = 0

    def new_token(self) -> str:
        self._seq += 1
        return f"jeton-clair-{self._seq}"


class FakeTokenRepository:
    def __init__(self) -> None:
        self.by_hash: dict[str, AccessToken] = {}

    def add(self, token: AccessToken) -> None:
        self.by_hash[token.token_hash] = token

    def find(self, token_hash: str) -> AccessToken | None:
        return self.by_hash.get(token_hash)

    def revoke(self, token_hash: str) -> None:
        self.by_hash.pop(token_hash, None)

    def purge_expired(self, now: datetime) -> None:
        self.by_hash = {h: t for h, t in self.by_hash.items() if not t.is_expired(now)}


class FakeLoginAttempts:
    def __init__(self) -> None:
        self.rows: list[tuple[str, str, datetime]] = []

    def reserve(self, attempt_id: str, subject: str, at: datetime, since: datetime) -> int:
        self.rows.append((attempt_id, subject, at))
        return sum(1 for _, s, t in self.rows if s == subject and t > since)

    def remove(self, attempt_id: str) -> None:
        self.rows = [r for r in self.rows if r[0] != attempt_id]

    def clear(self, subject: str) -> None:
        self.rows = [r for r in self.rows if r[1] != subject]

    def purge_before(self, before: datetime) -> None:
        self.rows = [r for r in self.rows if r[2] > before]
