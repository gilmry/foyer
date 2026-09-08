"""Entité agrégat Todo — pure, immuable, invariants garantis par le constructeur."""
from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime

from .exceptions import TodoValidationError


@dataclass(frozen=True)
class Todo:
    id: str
    title: str
    done: bool
    created_at: datetime
    updated_at: datetime

    def __post_init__(self) -> None:
        # Invariant métier codé dans le constructeur : libellé non vide.
        if not self.title.strip():
            raise TodoValidationError(["Le libellé est obligatoire."])

    def toggled(self, now: datetime) -> "Todo":
        """Copie avec le statut inversé (immuabilité)."""
        return replace(self, done=not self.done, updated_at=now)

    def renamed(self, title: str, now: datetime) -> "Todo":
        """Copie avec un nouveau libellé (post-MVP)."""
        return replace(self, title=title, updated_at=now)

    def to_view(self) -> dict:
        """Vue de sérialisation — clés stables, source de vérité du schéma TodoView."""
        return {
            "id": self.id,
            "title": self.title,
            "done": self.done,
            "createdAt": self.created_at.isoformat(),
            "updatedAt": self.updated_at.isoformat(),
        }
