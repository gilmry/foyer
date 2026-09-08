"""Adaptateur de persistance — option CQRS (SQL pur, psycopg).

CQRS = séparation explicite du modèle d'écriture (commandes) et de lecture (requêtes).
Deux collaborateurs distincts (_TodoCommands / _TodoQueries) composés pour satisfaire le port
TodoRepository. Aucune fuite SQL hors de cet adaptateur ; schéma géré par migrations up/down SQL.

Interchangeable avec OrmTodoRepository (ORM SQLAlchemy) via app/adapter/todo/factory.py.
"""
from __future__ import annotations

from datetime import datetime

import psycopg

from app.domain.todo.todo import Todo


def _map(row: tuple) -> Todo:
    return Todo(
        id=str(row[0]),
        title=str(row[1]),
        done=bool(row[2]),
        created_at=row[3] if isinstance(row[3], datetime) else datetime.fromisoformat(str(row[3])),
        updated_at=row[4] if isinstance(row[4], datetime) else datetime.fromisoformat(str(row[4])),
    )


class _TodoQueries:
    """Côté LECTURE (queries) — aucune mutation."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def find(self, todo_id: str) -> Todo | None:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, done, created_at, updated_at FROM todos WHERE id = %s",
                (todo_id,),
            )
            row = cur.fetchone()
        return _map(row) if row else None

    def find_all(self) -> list[Todo]:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, done, created_at, updated_at FROM todos ORDER BY created_at, id"
            )
            rows = cur.fetchall()
        return [_map(r) for r in rows]


class _TodoCommands:
    """Côté ÉCRITURE (commands) — mutations transactionnelles."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def save(self, todo: Todo) -> None:
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO todos (id, title, done, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE
                    SET title = EXCLUDED.title, done = EXCLUDED.done, updated_at = EXCLUDED.updated_at
                """,
                (todo.id, todo.title, todo.done, todo.created_at, todo.updated_at),
            )
        self._conn.commit()

    def delete(self, todo_id: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM todos WHERE id = %s", (todo_id,))
        self._conn.commit()


class CqrsTodoRepository:
    """Compose lecture + écriture pour satisfaire le port TodoRepository."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._queries = _TodoQueries(conn)
        self._commands = _TodoCommands(conn)

    def find(self, todo_id: str) -> Todo | None:
        return self._queries.find(todo_id)

    def find_all(self) -> list[Todo]:
        return self._queries.find_all()

    def save(self, todo: Todo) -> None:
        self._commands.save(todo)

    def delete(self, todo_id: str) -> None:
        self._commands.delete(todo_id)
