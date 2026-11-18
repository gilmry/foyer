"""Cas d'usage : supprimer une tâche de l'appelant."""
from __future__ import annotations

from app.domain.identity.current_user import CurrentUser
from app.domain.text import is_storable
from app.domain.todo.exceptions import TodoNotFoundError
from app.domain.todo.repository import TodoRepository


class DeleteTodo:
    def __init__(self, todos: TodoRepository) -> None:
        self._todos = todos

    def execute(self, current_user: CurrentUser, todo_id: str) -> dict:
        if not is_storable(todo_id) or self._todos.find(current_user.id(), todo_id) is None:
            raise TodoNotFoundError.with_id(todo_id)
        self._todos.delete(current_user.id(), todo_id)
        return {"deleted": True}
