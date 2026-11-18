"""Persistance de l'identité — option ORM (SQLAlchemy) : comptes, jetons, essais.
Mêmes ports que cqrs_identity_store.py ; interchangeable via TODO_PERSISTENCE=orm."""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.adapter.orm_models import AccountModel, AuthTokenModel, LoginAttemptModel
from app.domain.identity.account import Account
from app.domain.identity.token import AccessToken


def _account(row: AccountModel | None) -> Account | None:
    if row is None:
        return None
    return Account(id=row.id, email=row.email, password_hash=row.password_hash, created_at=row.created_at)


class OrmAccountRepository:
    def __init__(self, session: Session) -> None:
        self._s = session

    def find_by_email(self, email: str) -> Account | None:
        found = _account(self._s.scalars(select(AccountModel).where(AccountModel.email == email)).first())
        self._s.commit()
        return found

    def find(self, account_id: str) -> Account | None:
        found = _account(self._s.scalars(select(AccountModel).where(AccountModel.id == account_id)).first())
        self._s.commit()
        return found

    def add(self, account: Account) -> bool:
        self._s.add(AccountModel(
            id=account.id, email=account.email,
            password_hash=account.password_hash, created_at=account.created_at,
        ))
        try:
            self._s.commit()
        except IntegrityError:
            self._s.rollback()
            return False
        return True


class OrmTokenRepository:
    def __init__(self, session: Session) -> None:
        self._s = session

    def add(self, token: AccessToken) -> None:
        self._s.add(AuthTokenModel(
            token_hash=token.token_hash, account_id=token.account_id, kind=token.kind,
            created_at=token.created_at, expires_at=token.expires_at,
        ))
        self._s.commit()

    def find(self, token_hash: str) -> AccessToken | None:
        row = self._s.scalars(select(AuthTokenModel).where(AuthTokenModel.token_hash == token_hash)).first()
        found = None if row is None else AccessToken(
            token_hash=row.token_hash, account_id=row.account_id, kind=row.kind,
            created_at=row.created_at, expires_at=row.expires_at,
        )
        self._s.commit()
        return found

    def revoke(self, token_hash: str) -> None:
        self._s.execute(delete(AuthTokenModel).where(AuthTokenModel.token_hash == token_hash))
        self._s.commit()

    def purge_expired(self, now: datetime) -> None:
        self._s.execute(delete(AuthTokenModel).where(AuthTokenModel.expires_at <= now))
        self._s.commit()


class OrmLoginAttempts:
    def __init__(self, session: Session) -> None:
        self._s = session

    def reserve(self, attempt_id: str, subject: str, at: datetime, since: datetime) -> int:
        # Une seule transaction, sérialisée par sujet (verrou consultatif relâché au commit).
        self._s.execute(select(func.pg_advisory_xact_lock(func.hashtextextended(subject, 0))))
        self._s.add(LoginAttemptModel(id=attempt_id, subject=subject, attempted_at=at))
        self._s.flush()
        count = self._s.scalar(
            select(func.count()).select_from(LoginAttemptModel)
            .where(LoginAttemptModel.subject == subject, LoginAttemptModel.attempted_at > since)
        )
        self._s.commit()
        return int(count or 0)

    def remove(self, attempt_id: str) -> None:
        self._s.execute(delete(LoginAttemptModel).where(LoginAttemptModel.id == attempt_id))
        self._s.commit()

    def clear(self, subject: str) -> None:
        self._s.execute(delete(LoginAttemptModel).where(LoginAttemptModel.subject == subject))
        self._s.commit()

    def purge_before(self, before: datetime) -> None:
        self._s.execute(delete(LoginAttemptModel).where(LoginAttemptModel.attempted_at <= before))
        self._s.commit()
