"""Port de génération d'identifiant — injecté pour la testabilité."""
from __future__ import annotations

from typing import Protocol


class IdGenerator(Protocol):
    def uuid(self) -> str: ...
