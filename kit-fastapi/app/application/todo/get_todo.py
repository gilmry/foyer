"""Cas d'usage : lire une tâche de l'appelant par son identifiant."""
from __future__ import annotations

from app.domain.identity.current_user import CurrentUser
from app.domain.text import is_storable
from app.domain.todo.exceptions import TodoNotFoundError
from app.domain.todo.repository import TodoRepository
from app.domain.todo.todo import Todo


class GetTodo:
    def __init__(self, todos: TodoRepository) -> None:
        self._todos = todos

    def execute(self, current_user: CurrentUser, todo_id: str) -> Todo:
        # Un identifiant non stockable ne désigne aucun todo : même 404, sans interroger la base.
        todo = self._todos.find(current_user.id(), todo_id) if is_storable(todo_id) else None
        if todo is None:
            # Même erreur pour un todo d'autrui et pour un identifiant inexistant.
            raise TodoNotFoundError.with_id(todo_id)
        return todo
