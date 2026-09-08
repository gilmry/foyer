"""Cas d'usage : créer une tâche. Valide, construit l'entité, persiste."""
from __future__ import annotations

from app.domain.todo import rules
from app.domain.todo.clock import Clock
from app.domain.todo.exceptions import TodoValidationError
from app.domain.todo.id_generator import IdGenerator
from app.domain.todo.repository import TodoRepository
from app.domain.todo.todo import Todo


class CreateTodo:
    def __init__(self, todos: TodoRepository, clock: Clock, ids: IdGenerator) -> None:
        self._todos = todos
        self._clock = clock
        self._ids = ids

    def execute(self, data: dict) -> Todo:
        errors = rules.validate(data)
        if errors:
            raise TodoValidationError(errors)
        now = self._clock.now()
        todo = Todo(
            id=self._ids.uuid(),
            title=rules.normalize_title(str(data["title"])),
            done=False,
            created_at=now,
            updated_at=now,
        )
        self._todos.save(todo)
        return todo
