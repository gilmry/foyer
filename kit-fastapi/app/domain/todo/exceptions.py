"""Exceptions du domaine Todo — traduites en codes HTTP par l'adaptateur."""
from __future__ import annotations


class TodoValidationError(Exception):
    """Entrée violant une règle du domaine → HTTP 400."""

    def __init__(self, errors: list[str]) -> None:
        self.errors = errors
        super().__init__(" ".join(errors))


class TodoNotFoundError(Exception):
    """Id inexistant → HTTP 404."""

    @classmethod
    def with_id(cls, todo_id: str) -> "TodoNotFoundError":
        return cls(f"Tâche introuvable : {todo_id}.")
