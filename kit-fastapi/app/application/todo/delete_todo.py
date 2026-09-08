"""Cas d'usage : supprimer une tâche."""
from __future__ import annotations

from app.domain.todo.exceptions import TodoNotFoundError
from app.domain.todo.repository import TodoRepository


class DeleteTodo:
    def __init__(self, todos: TodoRepository) -> None:
        self._todos = todos

    def execute(self, todo_id: str) -> dict:
        if self._todos.find(todo_id) is None:
            raise TodoNotFoundError.with_id(todo_id)
        self._todos.delete(todo_id)
        return {"deleted": True}
