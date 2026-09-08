"""Application FastAPI — seule couche qui traduit les exceptions du domaine en codes HTTP.
Câble les routes REST du périmètre Todo vers les use-cases. Sert aussi le front statique (public/)."""
from __future__ import annotations

import os
from pathlib import Path
from typing import Iterator

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.adapter.todo.factory import repository
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.todo.exceptions import TodoNotFoundError, TodoValidationError
from app.domain.todo.repository import TodoRepository
from app.http.schemas import DeleteResult, Error, ErrorList, TodoCreateInput, TodoList, TodoView

app = FastAPI(title="Todo — API", version="1.0.0")


@app.exception_handler(TodoValidationError)
async def _on_validation(_: Request, exc: TodoValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"errors": exc.errors})


@app.exception_handler(TodoNotFoundError)
async def _on_not_found(_: Request, exc: TodoNotFoundError) -> JSONResponse:
    return JSONResponse(status_code=404, content={"error": str(exc)})


def get_repo() -> Iterator[TodoRepository]:
    # Choix d'adaptateur (CQRS ou ORM) transparent pour le routeur, via la fabrique.
    with repository() as repo:
        yield repo


@app.get("/api/todos", response_model=TodoList, operation_id="listTodos")
def list_todos(repo: TodoRepository = Depends(get_repo)) -> dict:
    return {"items": ListTodos(repo).execute()}


@app.post("/api/todos", response_model=TodoView, status_code=201,
          operation_id="createTodo", responses={400: {"model": ErrorList}})
def create_todo(body: TodoCreateInput, repo: TodoRepository = Depends(get_repo)) -> dict:
    todo = CreateTodo(repo, RealClock(), UuidGenerator()).execute(body.model_dump())
    return todo.to_view()


@app.patch("/api/todos/{id}", response_model=TodoView,
           operation_id="toggleTodo", responses={404: {"model": Error}})
def toggle_todo(id: str, repo: TodoRepository = Depends(get_repo)) -> dict:
    return ToggleTodo(repo, RealClock()).execute(id).to_view()


@app.delete("/api/todos/{id}", response_model=DeleteResult,
            operation_id="deleteTodo", responses={404: {"model": Error}})
def delete_todo(id: str, repo: TodoRepository = Depends(get_repo)) -> dict:
    return DeleteTodo(repo).execute(id)


# Front statique (îlot Svelte + client généré). Monté en dernier : les routes /api priment.
_public = Path(__file__).resolve().parents[2] / "public"
if _public.is_dir() and os.environ.get("TODO_SERVE_STATIC", "1") == "1":
    app.mount("/", StaticFiles(directory=str(_public), html=True), name="public")
