"""Cas d'usage : lister les tâches (vues sérialisées, ordre stable du repository)."""
from __future__ import annotations

from app.domain.todo.repository import TodoRepository


class ListTodos:
    def __init__(self, todos: TodoRepository) -> None:
        self._todos = todos

    def execute(self) -> list[dict]:
        return [t.to_view() for t in self._todos.find_all()]
