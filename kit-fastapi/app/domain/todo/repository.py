"""Port de persistance (interface) — implémenté par un adaptateur. Le domaine ne connaît que ce contrat."""
from __future__ import annotations

from typing import Protocol

from .todo import Todo


class TodoRepository(Protocol):
    def find(self, todo_id: str) -> Todo | None: ...

    def find_all(self) -> list[Todo]:
        """Ordonnées par date de création croissante."""
        ...

    def save(self, todo: Todo) -> None: ...

    def delete(self, todo_id: str) -> None: ...
