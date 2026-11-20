"""Modèles SQLAlchemy — miroir du schéma posé par les migrations SQL (database/migrations/).
Les migrations restent la seule source du schéma, pour l'ORM comme pour le SQL pur :
`python -m app.migrate up`. SQLAlchemy ne fuit jamais hors de la couche adapter."""
from __future__ import annotations

from datetime import datetime
from functools import lru_cache

from sqlalchemy import Boolean, DateTime, ForeignKey, String, create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.pool import NullPool

from app.db import connect


class Base(DeclarativeBase):
    pass


class AccountModel(Base):
    __tablename__ = "accounts"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    email: Mapped[str] = mapped_column(String(254), nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class AuthTokenModel(Base):
    __tablename__ = "auth_tokens"

    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class LoginAttemptModel(Base):
    __tablename__ = "login_attempts"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    subject: Mapped[str] = mapped_column(String(64), nullable=False)
    attempted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class TodoModel(Base):
    __tablename__ = "todos"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    owner_id: Mapped[str | None] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), nullable=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    done: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


@lru_cache(maxsize=1)
def engine() -> Engine:
    """Même source de connexion que l'adaptateur SQL pur (app.db.connect) : DATABASE_URL ou DB_*
    valent pour les deux. Pas de réserve de connexions : une connexion par requête, comme en CQRS,
    et rien de partagé entre les processus d'un serveur qui se dédouble (uWSGI)."""
    return create_engine("postgresql+psycopg://", creator=connect, poolclass=NullPool, future=True)
