"""Adaptateur HTTP ALTERNATIF — Starlette (ASGI nu), sans FastAPI ni Pydantic. Même port (les cas
d'usage), même contrat filaire que l'adaptateur FastAPI → le client généré api.ts fonctionne à
l'identique. MÊME protection : identité, contrôle d'origine et traduction des erreurs viennent de
app/http/common.py, partagé par les deux adaptateurs.

Les traitements sont synchrones (base, Argon2) : ils tournent dans la réserve de fils, jamais dans
la boucle d'événements."""
from __future__ import annotations

import os
from pathlib import Path

from starlette.applications import Starlette
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Mount, Route
from starlette.staticfiles import StaticFiles

from app.adapter import factory
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.get_todo import GetTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.identity.token import BEARER, SESSION
from app.http import common


async def _strict_body(request: Request, fields: set[str]) -> dict:
    """Désérialisation stricte : type application/json, objet JSON, tous les champs attendus,
    aucun autre, des chaînes."""
    if request.headers.get("content-type", "").split(";")[0].strip().lower() != "application/json":
        raise common.InvalidBody()
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001 — tout corps illisible est le même refus
        raise common.InvalidBody() from None
    if not isinstance(body, dict) or set(body.keys()) != fields \
            or not all(isinstance(v, str) for v in body.values()):
        raise common.InvalidBody()
    return body


# --- Santé ---

def health(_: Request) -> JSONResponse:
    try:
        factory.ping()
    except Exception:  # noqa: BLE001 — la sonde ne dit jamais pourquoi
        return JSONResponse({"status": "indisponible"}, status_code=503)
    return JSONResponse({"status": "ok"})


# --- Identité ---

async def register(request: Request) -> JSONResponse:
    common.refuse_foreign_origin(request)
    body = await _strict_body(request, {"email", "password"})

    def work() -> dict:
        with factory.persistence() as p:
            return common.register(p, body["email"], body["password"]).to_view()
    return JSONResponse(await run_in_threadpool(work), status_code=201)


async def login(request: Request) -> JSONResponse:
    common.refuse_foreign_origin(request)
    body = await _strict_body(request, {"email", "password"})

    def work():
        with factory.persistence() as p:
            return common.log_in(p, body["email"], body["password"], SESSION)
    issued = await run_in_threadpool(work)
    response = JSONResponse({"id": issued.account_id, "email": body["email"].strip().lower()})
    common.set_session_cookie(response, issued)
    return response


async def issue_token(request: Request) -> JSONResponse:
    common.refuse_foreign_origin(request)
    body = await _strict_body(request, {"email", "password"})

    def work():
        with factory.persistence() as p:
            return common.log_in(p, body["email"], body["password"], BEARER)
    return JSONResponse(common.token_view(await run_in_threadpool(work)))


def logout(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        response = JSONResponse(common.log_out(p, common.identify(request, p)))
    common.clear_session_cookie(response)
    return response


def me(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        return JSONResponse(common.account_view(p, common.identify(request, p).identity))


# --- Todos (toutes protégées ; le propriétaire est l'identité de l'appelant) ---

def list_todos(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        who = common.identify(request, p)
        return JSONResponse({"items": ListTodos(p.todos).execute(who.identity)})


async def create_todo(request: Request) -> JSONResponse:
    try:
        body = await _strict_body(request, {"title"})
    except common.InvalidBody:
        body = None

    def work() -> dict:
        with factory.persistence() as p:
            who = common.identify(request, p)  # l'identité d'abord : 401 quel que soit le corps
            if body is None:
                raise common.InvalidBody()
            return CreateTodo(p.todos, RealClock(), UuidGenerator()).execute(who.identity, body).to_view()
    return JSONResponse(await run_in_threadpool(work), status_code=201)


def get_todo(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        who = common.identify(request, p)
        return JSONResponse(GetTodo(p.todos).execute(who.identity, request.path_params["id"]).to_view())


def toggle_todo(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        who = common.identify(request, p)
        todo = ToggleTodo(p.todos, RealClock()).execute(who.identity, request.path_params["id"])
        return JSONResponse(todo.to_view())


def delete_todo(request: Request) -> JSONResponse:
    with factory.persistence() as p:
        who = common.identify(request, p)
        return JSONResponse(DeleteTodo(p.todos).execute(who.identity, request.path_params["id"]))


_routes = [
    Route("/api/health", health, methods=["GET"]),
    Route("/api/auth/register", register, methods=["POST"]),
    Route("/api/auth/login", login, methods=["POST"]),
    Route("/api/auth/token", issue_token, methods=["POST"]),
    Route("/api/auth/logout", logout, methods=["POST"]),
    Route("/api/auth/me", me, methods=["GET"]),
    Route("/api/todos", list_todos, methods=["GET"]),
    Route("/api/todos", create_todo, methods=["POST"]),
    Route("/api/todos/{id}", get_todo, methods=["GET"]),
    Route("/api/todos/{id}", toggle_todo, methods=["PATCH"]),
    Route("/api/todos/{id}", delete_todo, methods=["DELETE"]),
]

# Front statique (îlot + client généré), monté après les routes /api. Seul `public/` est servi.
_public = Path(__file__).resolve().parents[2] / "public"
if _public.is_dir() and os.environ.get("TODO_SERVE_STATIC", "1") == "1":
    _routes.append(Mount("/", app=StaticFiles(directory=str(_public), html=True)))

app = Starlette(routes=_routes, exception_handlers=common.EXCEPTION_HANDLERS)
