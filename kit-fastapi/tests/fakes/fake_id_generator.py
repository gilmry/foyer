"""Génère des IDs séquentiels déterministes (gen-1, gen-2, …)."""
from __future__ import annotations


class FakeIdGenerator:
    def __init__(self) -> None:
        self._seq = 0

    def uuid(self) -> str:
        self._seq += 1
        return f"gen-{self._seq}"
