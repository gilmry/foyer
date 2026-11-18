"""Cas d'usage : basculer le statut d'une tâche de l'appelant (à faire ↔ faite)."""
from __future__ import annotations

from app.domain.identity.current_user import CurrentUser
from app.domain.text import is_storable
from app.domain.todo.clock import Clock
from app.domain.todo.exceptions import TodoNotFoundError
from app.domain.todo.repository import TodoRepository
from app.domain.todo.todo import Todo


class ToggleTodo:
    def __init__(self, todos: TodoRepository, clock: Clock) -> None:
        self._todos = todos
        self._clock = clock

    def execute(self, current_user: CurrentUser, todo_id: str) -> Todo:
        # Un identifiant non stockable ne désigne aucun todo : même 404, sans interroger la base.
        todo = self._todos.find(current_user.id(), todo_id) if is_storable(todo_id) else None
        if todo is None:
            raise TodoNotFoundError.with_id(todo_id)
        toggled = todo.toggled(self._clock.now())
        self._todos.save(current_user.id(), toggled)
        return toggled
