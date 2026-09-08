"""Tests des use-cases (couche Application) avec fakes in-memory."""
from __future__ import annotations

import pytest

from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.todo.exceptions import TodoNotFoundError, TodoValidationError
from tests.fakes.fake_clock import FakeClock
from tests.fakes.fake_id_generator import FakeIdGenerator
from tests.fakes.fake_repository import FakeTodoRepository


def _seed(repo: FakeTodoRepository) -> str:
    return CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute({"title": "tâche"}).id


def test_create_persists_open_todo() -> None:  # @happy
    repo = FakeTodoRepository()
    todo = CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute({"title": "  acheter du pain  "})
    assert todo.id == "gen-1"
    assert todo.title == "acheter du pain"
    assert todo.done is False
    assert repo.find("gen-1") is not None


def test_create_empty_title_raises_and_persists_nothing() -> None:  # @negative
    repo = FakeTodoRepository()
    with pytest.raises(TodoValidationError):
        CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute({"title": ""})
    assert repo.count() == 0


def test_list_empty_returns_empty() -> None:  # @negative
    assert ListTodos(FakeTodoRepository()).execute() == []


def test_list_in_creation_order() -> None:  # @happy + @edge
    repo, clock, ids = FakeTodoRepository(), FakeClock(), FakeIdGenerator()
    create = CreateTodo(repo, clock, ids)
    create.execute({"title": "première"})
    clock.advance(3600)
    create.execute({"title": "seconde"})
    items = ListTodos(repo).execute()
    assert [i["title"] for i in items] == ["première", "seconde"]


def test_toggle_flips_and_persists() -> None:  # @happy
    repo = FakeTodoRepository()
    todo_id = _seed(repo)
    uc = ToggleTodo(repo, FakeClock())
    assert uc.execute(todo_id).done is True
    assert uc.execute(todo_id).done is False


def test_toggle_unknown_raises() -> None:  # @negative
    with pytest.raises(TodoNotFoundError):
        ToggleTodo(FakeTodoRepository(), FakeClock()).execute("inconnu")


def test_delete_removes_todo() -> None:  # @happy
    repo = FakeTodoRepository()
    todo_id = _seed(repo)
    assert DeleteTodo(repo).execute(todo_id) == {"deleted": True}
    assert repo.find(todo_id) is None


def test_delete_unknown_raises() -> None:  # @negative
    with pytest.raises(TodoNotFoundError):
        DeleteTodo(FakeTodoRepository()).execute("inconnu")
