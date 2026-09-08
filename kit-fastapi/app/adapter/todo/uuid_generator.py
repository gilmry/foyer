"""Génère un UUID v4."""
from __future__ import annotations

import uuid


class UuidGenerator:
    def uuid(self) -> str:
        return str(uuid.uuid4())
