"""Persistance de l'identité — option CQRS (SQL pur, psycopg) : comptes, jetons, essais.
Implémente les ports AccountRepository, TokenRepository et LoginAttempts."""
from __future__ import annotations

from datetime import datetime

import psycopg

from app.domain.identity.account import Account
from app.domain.identity.token import AccessToken


class CqrsAccountRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def _one(self, where: str, value: str) -> Account | None:
        with self._conn.cursor() as cur:
            cur.execute(f"SELECT id, email, password_hash, created_at FROM accounts WHERE {where} = %s", (value,))
            row = cur.fetchone()
        self._conn.commit()
        return Account(id=row[0], email=row[1], password_hash=row[2], created_at=row[3]) if row else None

    def find_by_email(self, email: str) -> Account | None:
        return self._one("email", email)

    def find(self, account_id: str) -> Account | None:
        return self._one("id", account_id)

    def add(self, account: Account) -> bool:
        with self._conn.cursor() as cur:
            cur.execute(
                "INSERT INTO accounts (id, email, password_hash, created_at) VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (email) DO NOTHING",
                (account.id, account.email, account.password_hash, account.created_at),
            )
            added = cur.rowcount == 1
        self._conn.commit()
        return added


class CqrsTokenRepository:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def add(self, token: AccessToken) -> None:
        with self._conn.cursor() as cur:
            cur.execute(
                "INSERT INTO auth_tokens (token_hash, account_id, kind, created_at, expires_at) "
                "VALUES (%s, %s, %s, %s, %s)",
                (token.token_hash, token.account_id, token.kind, token.created_at, token.expires_at),
            )
        self._conn.commit()

    def find(self, token_hash: str) -> AccessToken | None:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT token_hash, account_id, kind, created_at, expires_at FROM auth_tokens "
                "WHERE token_hash = %s",
                (token_hash,),
            )
            row = cur.fetchone()
        self._conn.commit()
        if not row:
            return None
        return AccessToken(token_hash=row[0], account_id=row[1], kind=row[2], created_at=row[3], expires_at=row[4])

    def revoke(self, token_hash: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM auth_tokens WHERE token_hash = %s", (token_hash,))
        self._conn.commit()

    def purge_expired(self, now: datetime) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM auth_tokens WHERE expires_at <= %s", (now,))
        self._conn.commit()


class CqrsLoginAttempts:
    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def reserve(self, attempt_id: str, subject: str, at: datetime, since: datetime) -> int:
        # Une seule transaction, sérialisée par sujet (verrou consultatif relâché au commit) :
        # l'insertion et le comptage ne peuvent pas s'entrelacer avec ceux d'une autre requête.
        with self._conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", (subject,))
            cur.execute(
                "INSERT INTO login_attempts (id, subject, attempted_at) VALUES (%s, %s, %s)",
                (attempt_id, subject, at),
            )
            cur.execute(
                "SELECT COUNT(*) FROM login_attempts WHERE subject = %s AND attempted_at > %s",
                (subject, since),
            )
            count = int(cur.fetchone()[0])
        self._conn.commit()
        return count

    def remove(self, attempt_id: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM login_attempts WHERE id = %s", (attempt_id,))
        self._conn.commit()

    def clear(self, subject: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM login_attempts WHERE subject = %s", (subject,))
        self._conn.commit()

    def purge_before(self, before: datetime) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM login_attempts WHERE attempted_at <= %s", (before,))
        self._conn.commit()
