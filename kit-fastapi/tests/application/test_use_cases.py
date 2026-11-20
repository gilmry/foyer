"""Tests des use-cases (couche Application) avec fakes in-memory."""
from __future__ import annotations

import pytest

from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.get_todo import GetTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.identity.current_user import CurrentUser
from app.domain.todo.exceptions import TodoNotFoundError, TodoValidationError
from tests.fakes.fake_clock import FakeClock
from tests.fakes.fake_id_generator import FakeIdGenerator
from tests.fakes.fake_repository import FakeTodoRepository

A = CurrentUser("compte-a")
B = CurrentUser("compte-b")


def _seed(repo: FakeTodoRepository, who: CurrentUser = A) -> str:
    return CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute(who, {"title": "tâche"}).id


def test_create_persists_open_todo() -> None:  # @happy
    repo = FakeTodoRepository()
    todo = CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute(A, {"title": "  acheter du pain  "})
    assert todo.id == "gen-1"
    assert todo.title == "acheter du pain"
    assert todo.done is False
    assert todo.owner_id == "compte-a"
    assert repo.find("compte-a", "gen-1") is not None


def test_create_empty_title_raises_and_persists_nothing() -> None:  # @negative
    repo = FakeTodoRepository()
    with pytest.raises(TodoValidationError):
        CreateTodo(repo, FakeClock(), FakeIdGenerator()).execute(A, {"title": ""})
    assert repo.count() == 0


def test_list_empty_returns_empty() -> None:  # @negative
    assert ListTodos(FakeTodoRepository()).execute(A) == []


def test_list_in_creation_order() -> None:  # @happy + @edge
    repo, clock, ids = FakeTodoRepository(), FakeClock(), FakeIdGenerator()
    create = CreateTodo(repo, clock, ids)
    create.execute(A, {"title": "première"})
    clock.advance(3600)
    create.execute(A, {"title": "seconde"})
    items = ListTodos(repo).execute(A)
    assert [i["title"] for i in items] == ["première", "seconde"]


def test_toggle_flips_and_persists() -> None:  # @happy
    repo = FakeTodoRepository()
    todo_id = _seed(repo)
    uc = ToggleTodo(repo, FakeClock())
    assert uc.execute(A, todo_id).done is True
    assert uc.execute(A, todo_id).done is False


def test_toggle_unknown_raises() -> None:  # @negative
    with pytest.raises(TodoNotFoundError):
        ToggleTodo(FakeTodoRepository(), FakeClock()).execute(A, "inconnu")


def test_delete_removes_todo() -> None:  # @happy
    repo = FakeTodoRepository()
    todo_id = _seed(repo)
    assert DeleteTodo(repo).execute(A, todo_id) == {"deleted": True}
    assert repo.find("compte-a", todo_id) is None


def test_delete_unknown_raises() -> None:  # @negative
    with pytest.raises(TodoNotFoundError):
        DeleteTodo(FakeTodoRepository()).execute(A, "inconnu")


# --- Cloisonnement par propriétaire (#33) ---

def test_list_only_returns_own_todos() -> None:  # @happy
    repo, ids = FakeTodoRepository(), FakeIdGenerator()
    CreateTodo(repo, FakeClock(), ids).execute(A, {"title": "todo de A"})
    CreateTodo(repo, FakeClock(), ids).execute(B, {"title": "todo de B"})
    assert [i["title"] for i in ListTodos(repo).execute(A)] == ["todo de A"]
    assert [i["title"] for i in ListTodos(repo).execute(B)] == ["todo de B"]


def test_view_never_exposes_owner() -> None:  # @security
    repo = FakeTodoRepository()
    _seed(repo)
    assert set(ListTodos(repo).execute(A)[0]) == {"id", "title", "done", "createdAt", "updatedAt"}


def test_foreign_todo_behaves_like_unknown() -> None:  # @edge
    repo = FakeTodoRepository()
    todo_of_b = _seed(repo, B)
    for attempt in (
        lambda: GetTodo(repo).execute(A, todo_of_b),
        lambda: ToggleTodo(repo, FakeClock()).execute(A, todo_of_b),
        lambda: DeleteTodo(repo).execute(A, todo_of_b),
    ):
        with pytest.raises(TodoNotFoundError) as foreign:
            attempt()
        with pytest.raises(TodoNotFoundError) as unknown:
            GetTodo(repo).execute(A, "inconnu")
        assert str(foreign.value) == str(unknown.value)
    # Le todo de B est intact.
    assert repo.find("compte-b", todo_of_b).done is False
