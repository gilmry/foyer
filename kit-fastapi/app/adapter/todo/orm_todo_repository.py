"""Adaptateur de persistance ALTERNATIF : implémente TodoRepository via SQLAlchemy (ORM).

Même port que CqrsTodoRepository (SQL pur). Interchangeable via config (TODO_PERSISTENCE=orm).
SQLAlchemy ne fuit JAMAIS hors de cet adaptateur : le domaine reçoit/retourne des entités Todo pures.

CLOISONNEMENT : chaque requête filtre sur `owner_id`. Pas de `Session.get` ni de `merge` par le
seul identifiant : ils liraient ou écraseraient le todo d'un autre compte.
"""
from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.adapter.orm_models import TodoModel
from app.domain.todo.todo import Todo


class OrmTodoRepository:
    def __init__(self, session: Session) -> None:
        self._s = session

    def _row(self, owner_id: str, todo_id: str) -> TodoModel | None:
        return self._s.scalars(
            select(TodoModel).where(TodoModel.owner_id == owner_id, TodoModel.id == todo_id)
        ).first()

    def find(self, owner_id: str, todo_id: str) -> Todo | None:
        row = self._row(owner_id, todo_id)
        self._s.commit()
        return self._to_domain(row) if row else None

    def find_all(self, owner_id: str) -> list[Todo]:
        rows = self._s.scalars(
            select(TodoModel).where(TodoModel.owner_id == owner_id)
            .order_by(TodoModel.created_at, TodoModel.id)
        ).all()
        self._s.commit()
        return [self._to_domain(r) for r in rows]

    def save(self, owner_id: str, todo: Todo) -> None:
        if todo.owner_id != owner_id:
            raise ValueError("Un todo ne s'enregistre que pour son propriétaire.")
        row = self._row(owner_id, todo.id)
        if row is not None:
            row.title, row.done, row.updated_at = todo.title, todo.done, todo.updated_at
        elif self._s.scalars(select(TodoModel.id).where(TodoModel.id == todo.id)).first() is None:
            self._s.add(TodoModel(
                id=todo.id, owner_id=owner_id, title=todo.title, done=todo.done,
                created_at=todo.created_at, updated_at=todo.updated_at,
            ))
        # Sinon l'identifiant existe chez un autre compte : ni modifié, ni réattribué.
        self._s.commit()

    def delete(self, owner_id: str, todo_id: str) -> None:
        self._s.execute(delete(TodoModel).where(TodoModel.owner_id == owner_id, TodoModel.id == todo_id))
        self._s.commit()

    @staticmethod
    def _to_domain(row: TodoModel) -> Todo:
        return Todo(
            id=row.id, owner_id=row.owner_id, title=row.title, done=row.done,
            created_at=row.created_at, updated_at=row.updated_at,
        )
