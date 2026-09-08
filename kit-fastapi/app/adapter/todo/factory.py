"""Sélection de l'adaptateur de persistance — CQRS (SQL pur) ou ORM (SQLAlchemy).

Piloté par TODO_PERSISTENCE :
  - `cqrs` (défaut) : psycopg, séparation commandes/requêtes, schéma par migrations up/down SQL.
  - `orm`          : SQLAlchemy, schéma par métadonnées ORM ou par les mêmes migrations.

Les DEUX implémentent le même port TodoRepository → interchangeables sans toucher au domaine ni
à l'application. Ce choix est un point d'ADR (cf. bmad/archetypes.md), pas une question au PO
non-développeur : défaut annoncé `cqrs` (cf. pilote/defaults.md)."""
from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

from app.domain.todo.repository import TodoRepository


@contextmanager
def repository() -> Iterator[TodoRepository]:
    kind = os.environ.get("TODO_PERSISTENCE", "cqrs").lower()
    if kind == "orm":
        from app.adapter.todo.orm_todo_repository import orm_repo_session
        with orm_repo_session() as repo:
            yield repo
    else:  # cqrs (SQL pur)
        from app.adapter.todo.cqrs_todo_repository import CqrsTodoRepository
        from app.db import connect
        conn = connect()
        try:
            yield CqrsTodoRepository(conn)
        finally:
            conn.close()
