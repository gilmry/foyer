"""Tests de validation du domaine (règles)."""
from __future__ import annotations

from app.domain.todo import rules


def test_valid_title_passes() -> None:  # @happy
    assert rules.validate({"title": "acheter du pain"}) == []


def test_missing_or_empty_title_fails() -> None:  # @negative
    assert rules.validate({}) != []
    assert rules.validate({"title": "   "}) != []


def test_title_boundaries() -> None:  # @edge
    assert rules.validate({"title": "a" * rules.TITLE_MAX}) == []
    assert rules.validate({"title": "a" * (rules.TITLE_MAX + 1)}) != []


def test_normalize_trims() -> None:  # @happy
    assert rules.normalize_title("  tâche  ") == "tâche"
