"""Sélection de l'adaptateur de persistance — CQRS (SQL pur) ou ORM (SQLAlchemy).

Piloté par TODO_PERSISTENCE :
  - `cqrs` (défaut) : psycopg, séparation commandes/requêtes.
  - `orm`          : SQLAlchemy.
Le schéma est posé par les mêmes migrations SQL dans les deux cas (`python -m app.migrate up`).

Les DEUX implémentent les mêmes ports (todos, comptes, jetons, essais de connexion) →
interchangeables sans toucher au domaine ni à l'application. Ce choix est un point d'ADR
(cf. bmad/archetypes.md), pas une question au PO non-développeur : défaut annoncé `cqrs`
(cf. pilote/defaults.md). Une connexion par requête, fermée en sortie."""
from __future__ import annotations

import os
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator

from app.domain.identity.ports import AccountRepository, LoginAttempts, TokenRepository
from app.domain.todo.repository import TodoRepository


@dataclass(frozen=True)
class Persistence:
    todos: TodoRepository
    accounts: AccountRepository
    tokens: TokenRepository
    attempts: LoginAttempts


def kind() -> str:
    return "orm" if os.environ.get("TODO_PERSISTENCE", "cqrs").lower() == "orm" else "cqrs"


@contextmanager
def persistence(which: str | None = None) -> Iterator[Persistence]:
    if (which or kind()) == "orm":
        from sqlalchemy.orm import Session

        from app.adapter.identity.orm_identity_store import (
            OrmAccountRepository, OrmLoginAttempts, OrmTokenRepository)
        from app.adapter.orm_models import engine
        from app.adapter.todo.orm_todo_repository import OrmTodoRepository
        with Session(engine(), expire_on_commit=False) as session:
            yield Persistence(OrmTodoRepository(session), OrmAccountRepository(session),
                              OrmTokenRepository(session), OrmLoginAttempts(session))
    else:  # cqrs (SQL pur)
        from app.adapter.identity.cqrs_identity_store import (
            CqrsAccountRepository, CqrsLoginAttempts, CqrsTokenRepository)
        from app.adapter.todo.cqrs_todo_repository import CqrsTodoRepository
        from app.db import connect
        conn = connect()
        try:
            yield Persistence(CqrsTodoRepository(conn), CqrsAccountRepository(conn),
                              CqrsTokenRepository(conn), CqrsLoginAttempts(conn))
        finally:
            conn.close()


def ping() -> None:
    """Sonde de santé : la base répond-elle ? Lève l'exception du pilote sinon."""
    from app.db import connect
    conn = connect()
    try:
        conn.execute("SELECT 1")
    finally:
        conn.close()
