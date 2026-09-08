"""Repository in-memory pour les tests (aucune DB)."""
from __future__ import annotations

from app.domain.todo.todo import Todo


class FakeTodoRepository:
    def __init__(self) -> None:
        self._store: dict[str, Todo] = {}

    def find(self, todo_id: str) -> Todo | None:
        return self._store.get(todo_id)

    def find_all(self) -> list[Todo]:
        return sorted(self._store.values(), key=lambda t: t.created_at)

    def save(self, todo: Todo) -> None:
        self._store[todo.id] = todo

    def delete(self, todo_id: str) -> None:
        self._store.pop(todo_id, None)

    def count(self) -> int:
        return len(self._store)
