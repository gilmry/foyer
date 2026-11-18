"""Cas d'usage : lister les tâches de l'appelant (vues sérialisées, ordre stable du repository)."""
from __future__ import annotations

from app.domain.identity.current_user import CurrentUser
from app.domain.todo.repository import TodoRepository


class ListTodos:
    def __init__(self, todos: TodoRepository) -> None:
        self._todos = todos

    def execute(self, current_user: CurrentUser) -> list[dict]:
        return [t.to_view() for t in self._todos.find_all(current_user.id())]
