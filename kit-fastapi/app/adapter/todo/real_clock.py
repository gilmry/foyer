"""Horloge réelle (UTC)."""
from __future__ import annotations

from datetime import datetime, timezone


class RealClock:
    def now(self) -> datetime:
        return datetime.now(timezone.utc)
