"""Adaptateur HTTP ALTERNATIF — Starlette (ASGI nu), sans FastAPI. Même port (les use-cases),
même contrat filaire que l'adaptateur FastAPI → le client généré api.ts fonctionne à l'identique.
Starlette ne fuit pas hors de cet adaptateur ; le domaine et l'application ne changent pas."""
from __future__ import annotations

import json
import os
from pathlib import Path

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Mount, Route
from starlette.staticfiles import StaticFiles

from app.adapter.todo.factory import repository
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.todo.exceptions import TodoNotFoundError, TodoValidationError


async def list_todos(_: Request) -> JSONResponse:
    with repository() as repo:
        return JSONResponse({"items": ListTodos(repo).execute()})


async def create_todo(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        body = None
    if not isinstance(body, dict) or set(body.keys()) - {"title"}:
        # Désérialisation stricte : corps invalide / champ inconnu → 422 (comme Pydantic côté FastAPI).
        return JSONResponse({"error": "Corps invalide."}, status_code=422)
    with repository() as repo:
        try:
            todo = CreateTodo(repo, RealClock(), UuidGenerator()).execute(body)
        except TodoValidationError as e:
            return JSONResponse({"errors": e.errors}, status_code=400)
    return JSONResponse(todo.to_view(), status_code=201)


async def toggle_todo(request: Request) -> JSONResponse:
    with repository() as repo:
        try:
            todo = ToggleTodo(repo, RealClock()).execute(request.path_params["id"])
        except TodoNotFoundError as e:
            return JSONResponse({"error": str(e)}, status_code=404)
    return JSONResponse(todo.to_view())


async def delete_todo(request: Request) -> JSONResponse:
    with repository() as repo:
        try:
            res = DeleteTodo(repo).execute(request.path_params["id"])
        except TodoNotFoundError as e:
            return JSONResponse({"error": str(e)}, status_code=404)
    return JSONResponse(res)


_routes = [
    Route("/api/todos", list_todos, methods=["GET"]),
    Route("/api/todos", create_todo, methods=["POST"]),
    Route("/api/todos/{id}", toggle_todo, methods=["PATCH"]),
    Route("/api/todos/{id}", delete_todo, methods=["DELETE"]),
]

# Front statique (îlot + client généré), monté après les routes /api.
_public = Path(__file__).resolve().parents[2] / "public"
if _public.is_dir() and os.environ.get("TODO_SERVE_STATIC", "1") == "1":
    _routes.append(Mount("/", app=StaticFiles(directory=str(_public), html=True)))

app = Starlette(routes=_routes)
