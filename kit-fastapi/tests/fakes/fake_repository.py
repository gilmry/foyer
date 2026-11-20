"""Repository in-memory pour les tests (aucune DB). Même cloisonnement que les vrais adaptateurs."""
from __future__ import annotations

from app.domain.todo.todo import Todo


class FakeTodoRepository:
    def __init__(self) -> None:
        self._store: dict[str, Todo] = {}

    def find(self, owner_id: str, todo_id: str) -> Todo | None:
        todo = self._store.get(todo_id)
        return todo if todo is not None and todo.owner_id == owner_id else None

    def find_all(self, owner_id: str) -> list[Todo]:
        return sorted((t for t in self._store.values() if t.owner_id == owner_id), key=lambda t: t.created_at)

    def save(self, owner_id: str, todo: Todo) -> None:
        if todo.owner_id != owner_id:
            raise ValueError("Un todo ne s'enregistre que pour son propriétaire.")
        existing = self._store.get(todo.id)
        if existing is None or existing.owner_id == owner_id:
            self._store[todo.id] = todo

    def delete(self, owner_id: str, todo_id: str) -> None:
        if self.find(owner_id, todo_id) is not None:
            del self._store[todo_id]

    def count(self) -> int:
        return len(self._store)
