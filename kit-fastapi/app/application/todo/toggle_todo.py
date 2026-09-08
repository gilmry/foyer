"""Cas d'usage : basculer le statut d'une tâche (à faire ↔ faite)."""
from __future__ import annotations

from app.domain.todo.clock import Clock
from app.domain.todo.exceptions import TodoNotFoundError
from app.domain.todo.repository import TodoRepository
from app.domain.todo.todo import Todo


class ToggleTodo:
    def __init__(self, todos: TodoRepository, clock: Clock) -> None:
        self._todos = todos
        self._clock = clock

    def execute(self, todo_id: str) -> Todo:
        todo = self._todos.find(todo_id)
        if todo is None:
            raise TodoNotFoundError.with_id(todo_id)
        toggled = todo.toggled(self._clock.now())
        self._todos.save(toggled)
        return toggled
