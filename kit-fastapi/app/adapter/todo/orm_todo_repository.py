"""Adaptateur de persistance ALTERNATIF : implémente TodoRepository via SQLAlchemy (ORM).

Même port que PgTodoRepository (SQL brut). Interchangeable via config (TODO_PERSISTENCE=orm).
SQLAlchemy ne fuit JAMAIS hors de cet adaptateur : le domaine reçoit/retourne des entités Todo pures.

Schéma : deux options possibles (au choix du projet consommateur) —
  - migrations SQL up/down (database/migrations/…), communes aux deux adaptateurs ; OU
  - `create_schema()` ci-dessous (métadonnées ORM), pour un flux 100% ORM sans SQL à la main.
"""
from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import datetime
from typing import Iterator

from sqlalchemy import Boolean, DateTime, String, create_engine, delete, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

from app.domain.todo.todo import Todo


class Base(DeclarativeBase):
    pass


class TodoModel(Base):
    __tablename__ = "todos"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    done: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


def _url() -> str:
    if os.environ.get("DATABASE_URL", "").startswith("postgresql"):
        return os.environ["DATABASE_URL"]
    return "postgresql+psycopg://{u}:{pw}@{h}:{p}/{d}".format(
        u=os.environ.get("DB_USER", "todo"),
        pw=os.environ.get("DB_PASSWORD", ""),
        h=os.environ.get("DB_HOST", "localhost"),
        p=os.environ.get("DB_PORT", "5432"),
        d=os.environ.get("DB_NAME", "todo"),
    )


def engine():
    return create_engine(_url(), future=True)


def create_schema() -> None:
    """Alternative aux migrations SQL : crée la table depuis les métadonnées ORM."""
    Base.metadata.create_all(engine())


class OrmTodoRepository:
    def __init__(self, session: Session) -> None:
        self._s = session

    def find(self, todo_id: str) -> Todo | None:
        row = self._s.get(TodoModel, todo_id)
        return self._to_domain(row) if row else None

    def find_all(self) -> list[Todo]:
        rows = self._s.scalars(select(TodoModel).order_by(TodoModel.created_at, TodoModel.id)).all()
        return [self._to_domain(r) for r in rows]

    def save(self, todo: Todo) -> None:
        self._s.merge(TodoModel(
            id=todo.id, title=todo.title, done=todo.done,
            created_at=todo.created_at, updated_at=todo.updated_at,
        ))
        self._s.commit()

    def delete(self, todo_id: str) -> None:
        self._s.execute(delete(TodoModel).where(TodoModel.id == todo_id))
        self._s.commit()

    @staticmethod
    def _to_domain(row: TodoModel) -> Todo:
        return Todo(
            id=row.id, title=row.title, done=row.done,
            created_at=row.created_at, updated_at=row.updated_at,
        )


@contextmanager
def orm_repo_session() -> Iterator[OrmTodoRepository]:
    with Session(engine(), expire_on_commit=False) as session:
        yield OrmTodoRepository(session)
