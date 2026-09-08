"""Gate `integration` — exerce les DEUX adaptateurs (CQRS SQL pur ET ORM SQLAlchemy) contre
un PostgreSQL réel, via les use-cases. Prouve l'interchangeabilité du port + la persistance."""
from __future__ import annotations

import os
import sys
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402

from app.adapter.todo.cqrs_todo_repository import CqrsTodoRepository  # noqa: E402
from app.adapter.todo.orm_todo_repository import create_schema, orm_repo_session  # noqa: E402
from app.adapter.todo.real_clock import RealClock  # noqa: E402
from app.adapter.todo.uuid_generator import UuidGenerator  # noqa: E402
from app.application.todo.create_todo import CreateTodo  # noqa: E402
from app.application.todo.delete_todo import DeleteTodo  # noqa: E402
from app.application.todo.list_todos import ListTodos  # noqa: E402
from app.application.todo.toggle_todo import ToggleTodo  # noqa: E402
from app.config import dsn  # noqa: E402

assertions = 0
failures = 0


def check(label: str, cond: bool) -> None:
    global assertions, failures
    assertions += 1
    if cond:
        print(f"  ✓ {label}")
    else:
        failures += 1
        sys.stderr.write(f"  ✗ {label}\n")


def reset_schema_sql() -> None:
    with psycopg.connect(dsn()) as conn, conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS todos")
        cur.execute((ROOT / "database/migrations/pending/0001_create_todos.up.sql").read_text())
        conn.commit()


def reset_schema_orm() -> None:
    with psycopg.connect(dsn()) as conn, conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS todos")
        conn.commit()
    create_schema()  # schéma via métadonnées ORM (alternative aux migrations SQL)


@contextmanager
def cqrs_repo():
    with psycopg.connect(dsn()) as conn:
        yield CqrsTodoRepository(conn)


def run(kind: str, reset, repo_ctx) -> None:
    print(f"\n[{kind}]")
    reset()
    with repo_ctx() as repo:
        clock, ids = RealClock(), UuidGenerator()
        todo = CreateTodo(repo, clock, ids).execute({"title": "acheter du pain"})
        check(f"{kind}: create persiste et relit", repo.find(todo.id) is not None)
        check(f"{kind}: statut initial « à faire »", repo.find(todo.id).done is False)
        items = ListTodos(repo).execute()
        check(f"{kind}: list = 1 élément, bon libellé", len(items) == 1 and items[0]["title"] == "acheter du pain")
        ToggleTodo(repo, clock).execute(todo.id)
        check(f"{kind}: toggle persisté (faite)", repo.find(todo.id).done is True)
    # Nouvelle connexion/sessions : l'état survit
    with repo_ctx() as repo2:
        found = repo2.find_all()
        check(f"{kind}: persistance inter-connexion", len(found) == 1 and found[0].done is True)
        DeleteTodo(repo2).execute(found[0].id)
        check(f"{kind}: delete → liste vide", ListTodos(repo2).execute() == [])


run("cqrs", reset_schema_sql, cqrs_repo)
run("orm", reset_schema_orm, orm_repo_session)

print(f"\nintegration: {'🟢' if failures == 0 else '🔴'} ({assertions} assertions, {failures} échecs)")
sys.exit(1 if failures else 0)
