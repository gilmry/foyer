"""Compte — pur. Ne porte jamais de mot de passe en clair, seulement son hachage."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Account:
    id: str
    email: str
    password_hash: str
    created_at: datetime

    def to_view(self) -> dict:
        """Vue de sérialisation — le hachage n'en fait JAMAIS partie."""
        return {"id": self.id, "email": self.email}
