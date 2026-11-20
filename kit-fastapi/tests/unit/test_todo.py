"""Tests unitaires du domaine Todo (invariants, immuabilité, vue)."""
from __future__ import annotations

from datetime import datetime, timezone

import pytest

from app.domain.todo.exceptions import TodoValidationError
from app.domain.todo.todo import Todo


def _now() -> datetime:
    return datetime(2026, 1, 1, tzinfo=timezone.utc)


def test_construct_valid_todo_is_open() -> None:  # @happy
    todo = Todo("id-1", "compte-a", "acheter du pain", False, _now(), _now())
    assert todo.id == "id-1"
    assert todo.title == "acheter du pain"
    assert todo.done is False


def test_construct_empty_title_raises() -> None:  # @negative
    with pytest.raises(TodoValidationError):
        Todo("id-1", "compte-a", "   ", False, _now(), _now())


def test_toggle_inverts_status_and_is_immutable() -> None:  # @edge
    todo = Todo("id-1", "compte-a", "tâche", False, _now(), _now())
    done = todo.toggled(_now())
    assert done.done is True
    assert done.toggled(_now()).done is False
    assert todo.done is False  # original inchangé


def test_title_stored_verbatim() -> None:  # @security
    payload = "<script>alert(1)</script>"
    todo = Todo("id-1", "compte-a", payload, False, _now(), _now())
    assert todo.title == payload
    assert todo.to_view()["title"] == payload


def test_to_view_shape() -> None:  # @happy
    todo = Todo("id-1", "compte-a", "tâche", True, _now(), _now())
    assert list(todo.to_view().keys()) == ["id", "title", "done", "createdAt", "updatedAt"]
    assert todo.to_view()["done"] is True


def test_construct_without_owner_raises() -> None:  # @security
    with pytest.raises(TodoValidationError):
        Todo("id-1", "", "tâche", False, _now(), _now())


def test_view_has_no_owner() -> None:  # @security
    assert "owner_id" not in Todo("id-1", "compte-a", "tâche", False, _now(), _now()).to_view()
