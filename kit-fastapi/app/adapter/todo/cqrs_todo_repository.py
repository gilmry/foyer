"""Adaptateur de persistance — option CQRS (SQL pur, psycopg).

CQRS = séparation explicite du modèle d'écriture (commandes) et de lecture (requêtes).
Deux collaborateurs distincts (_TodoCommands / _TodoQueries) composés pour satisfaire le port
TodoRepository. Aucune fuite SQL hors de cet adaptateur ; schéma géré par migrations up/down SQL.

CLOISONNEMENT : chaque requête SQL porte `owner_id = %s`. Un todo d'autrui est introuvable,
non modifiable et non supprimable depuis cet adaptateur.

Interchangeable avec OrmTodoRepository (ORM SQLAlchemy) via app/adapter/factory.py.
"""
from __future__ import annotations

from datetime import datetime

import psycopg

from app.domain.todo.todo import Todo

_COLUMNS = "id, owner_id, title, done, created_at, updated_at"


def _map(row: tuple) -> Todo:
    return Todo(
        id=str(row[0]),
        owner_id=str(row[1]),
        title=str(row[2]),
        done=bool(row[3]),
        created_at=row[4] if isinstance(row[4], datetime) else datetime.fromisoformat(str(row[4])),
        updated_at=row[5] if isinstance(row[5], datetime) else datetime.fromisoformat(str(row[5])),
    )


class _TodoQueries:
    """Côté LECTURE (queries) — aucune mutation."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def find(self, owner_id: str, todo_id: str) -> Todo | None:
        with self._conn.cursor() as cur:
            cur.execute(
                f"SELECT {_COLUMNS} FROM todos WHERE owner_id = %s AND id = %s",
                (owner_id, todo_id),
            )
            row = cur.fetchone()
        self._conn.commit()
        return _map(row) if row else None

    def find_all(self, owner_id: str) -> list[Todo]:
        with self._conn.cursor() as cur:
            cur.execute(
                f"SELECT {_COLUMNS} FROM todos WHERE owner_id = %s ORDER BY created_at, id",
                (owner_id,),
            )
            rows = cur.fetchall()
        self._conn.commit()
        return [_map(r) for r in rows]


class _TodoCommands:
    """Côté ÉCRITURE (commands) — mutations transactionnelles."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def save(self, owner_id: str, todo: Todo) -> None:
        if todo.owner_id != owner_id:
            raise ValueError("Un todo ne s'enregistre que pour son propriétaire.")
        with self._conn.cursor() as cur:
            # La mise à jour ne s'applique que si la ligne appartient déjà à ce propriétaire :
            # un identifiant qui existerait chez un autre compte n'est ni modifié ni réattribué.
            cur.execute(
                """
                INSERT INTO todos (id, owner_id, title, done, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE
                    SET title = EXCLUDED.title, done = EXCLUDED.done, updated_at = EXCLUDED.updated_at
                    WHERE todos.owner_id = EXCLUDED.owner_id
                """,
                (todo.id, owner_id, todo.title, todo.done, todo.created_at, todo.updated_at),
            )
        self._conn.commit()

    def delete(self, owner_id: str, todo_id: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM todos WHERE owner_id = %s AND id = %s", (owner_id, todo_id))
        self._conn.commit()


class CqrsTodoRepository:
    """Compose lecture + écriture pour satisfaire le port TodoRepository."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._queries = _TodoQueries(conn)
        self._commands = _TodoCommands(conn)

    def find(self, owner_id: str, todo_id: str) -> Todo | None:
        return self._queries.find(owner_id, todo_id)

    def find_all(self, owner_id: str) -> list[Todo]:
        return self._queries.find_all(owner_id)

    def save(self, owner_id: str, todo: Todo) -> None:
        self._commands.save(owner_id, todo)

    def delete(self, owner_id: str, todo_id: str) -> None:
        self._commands.delete(owner_id, todo_id)
