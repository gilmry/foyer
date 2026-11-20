"""Port de persistance (interface) — implémenté par un adaptateur. Le domaine ne connaît que ce contrat.

CLOISONNEMENT : toute lecture et toute écriture prend le propriétaire (`owner_id`). Un adaptateur
ne peut donc ni lire, ni modifier, ni supprimer le todo d'un autre compte, même si la couche HTTP
se trompait. Un todo d'autrui se comporte exactement comme un todo inexistant."""
from __future__ import annotations

from typing import Protocol

from .todo import Todo


class TodoRepository(Protocol):
    def find(self, owner_id: str, todo_id: str) -> Todo | None: ...

    def find_all(self, owner_id: str) -> list[Todo]:
        """Les todos de ce propriétaire, par date de création croissante."""
        ...

    def save(self, owner_id: str, todo: Todo) -> None:
        """Crée, ou met à jour si le todo appartient déjà à `owner_id`. Ne réattribue jamais."""
        ...

    def delete(self, owner_id: str, todo_id: str) -> None: ...
