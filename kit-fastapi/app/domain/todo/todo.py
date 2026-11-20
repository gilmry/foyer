"""Entité agrégat Todo — pure, immuable, invariants garantis par le constructeur.
Chaque todo a un PROPRIÉTAIRE (`owner_id`, identifiant de compte) : il n'est visible que de lui."""
from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime

from .exceptions import TodoValidationError


@dataclass(frozen=True)
class Todo:
    id: str
    owner_id: str
    title: str
    done: bool
    created_at: datetime
    updated_at: datetime

    def __post_init__(self) -> None:
        # Invariant métier codé dans le constructeur : libellé non vide.
        if not self.title.strip():
            raise TodoValidationError(["Le libellé est obligatoire."])
        # Invariant de cloisonnement : pas de todo sans propriétaire.
        if not self.owner_id:
            raise TodoValidationError(["Le propriétaire est obligatoire."])

    def toggled(self, now: datetime) -> "Todo":
        """Copie avec le statut inversé (immuabilité)."""
        return replace(self, done=not self.done, updated_at=now)

    def renamed(self, title: str, now: datetime) -> "Todo":
        """Copie avec un nouveau libellé (post-MVP)."""
        return replace(self, title=title, updated_at=now)

    def to_view(self) -> dict:
        """Vue de sérialisation — clés stables, source de vérité du schéma TodoView.
        Le propriétaire n'y figure pas : l'appelant ne voit que ses propres todos."""
        return {
            "id": self.id,
            "title": self.title,
            "done": self.done,
            "createdAt": self.created_at.isoformat(),
            "updatedAt": self.updated_at.isoformat(),
        }
