"""Adaptateur HTTP FastAPI — câble les routes REST vers les cas d'usage ; SEUL fichier qui connaît
FastAPI. Source du contrat OpenAPI (schémas de sécurité compris). Sert aussi le front (public/).

Identité : résolue ici par la dépendance `caller` (cookie de session ou jeton porteur, voir
app/http/common.py), puis PASSÉE aux cas d'usage. Aucun `Depends` ne descend dans l'application."""
from __future__ import annotations

import os
from pathlib import Path
from typing import Iterator

from fastapi import Depends, FastAPI, Request, Response, Security
from fastapi.exceptions import RequestValidationError
from fastapi.security import APIKeyCookie, HTTPBearer
from fastapi.staticfiles import StaticFiles

from app.adapter import factory
from app.adapter.factory import Persistence
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.todo.create_todo import CreateTodo
from app.application.todo.delete_todo import DeleteTodo
from app.application.todo.get_todo import GetTodo
from app.application.todo.list_todos import ListTodos
from app.application.todo.toggle_todo import ToggleTodo
from app.domain.identity.token import BEARER, SESSION
from app.http import common
from app.http.common import Caller
from app.http.schemas import (
    AccountView, CredentialsInput, DeleteResult, Error, ErrorList, Health, LogoutResult,
    TodoCreateInput, TodoList, TodoView, TokenView,
)

# Ni /docs ni /openapi.json en service : le contrat est un fichier versionné (openapi/), et les
# deux adaptateurs HTTP exposent ainsi exactement les mêmes routes.
app = FastAPI(title="Todo — API", version="2.0.0", docs_url=None, redoc_url=None, openapi_url=None)

for _exc, _handler in common.EXCEPTION_HANDLERS.items():
    app.add_exception_handler(_exc, _handler)
_OPEN_PATHS = frozenset({"/api/health", "/api/auth/register", "/api/auth/login", "/api/auth/token"})


def _on_invalid_request(request: Request, exc: Exception):
    """Corps refusé. FastAPI lit et valide le corps AVANT de résoudre l'identité : sur une route
    protégée, on résout donc l'identité ici, pour que l'appelant sans identité reçoive 401 quel
    que soit son corps — comme sous l'adaptateur Starlette. Le détail de Pydantic, qui recopie la
    valeur fautive (un mot de passe, par exemple), ne sort jamais."""
    if request.url.path not in _OPEN_PATHS:
        try:
            with factory.persistence() as p:
                common.identify(request, p)
        except (common.Unauthenticated, common.OriginRefused) as refusal:
            return common.EXCEPTION_HANDLERS[type(refusal)](request, refusal)
    return common.EXCEPTION_HANDLERS[common.InvalidBody](request, exc)


app.add_exception_handler(RequestValidationError, _on_invalid_request)

# Schémas de sécurité du contrat. `auto_error=False` : ils DÉCRIVENT ; la décision est prise par
# common.identify, commun aux deux adaptateurs.
_bearer = HTTPBearer(auto_error=False, scheme_name="bearerAuth",
                     description="Jeton opaque délivré par POST /api/auth/token.")
_cookie = APIKeyCookie(name=common.SESSION_COOKIE, auto_error=False, scheme_name="sessionCookie",
                       description="Session du front, posée par POST /api/auth/login "
                                   "(HttpOnly, SameSite=Strict, Secure).")

_AUTH = {401: {"model": Error}, 403: {"model": Error}}
_BODY = {422: {"model": Error}}


def get_persistence() -> Iterator[Persistence]:
    # Choix d'adaptateur (CQRS ou ORM) transparent pour le routeur, via la fabrique.
    with factory.persistence() as p:
        yield p


def caller(request: Request, p: Persistence = Depends(get_persistence),
           _b=Security(_bearer), _c=Security(_cookie)) -> Caller:
    who = common.identify(request, p)
    common.require_json(request)  # après l'identité : sans elle, la réponse reste 401
    return who


def same_origin(request: Request) -> None:
    common.refuse_foreign_origin(request)
    common.require_json(request)


# --- Santé ---

@app.get("/api/health", response_model=Health, operation_id="health",
         responses={503: {"model": Health}})
def health(response: Response) -> dict:
    try:
        factory.ping()
    except Exception:  # noqa: BLE001 — la sonde ne dit jamais pourquoi
        response.status_code = 503
        return {"status": "indisponible"}
    return {"status": "ok"}


# --- Identité ---

@app.post("/api/auth/register", response_model=AccountView, status_code=201, operation_id="register",
          responses={400: {"model": ErrorList}, 403: {"model": Error}, 409: {"model": Error}, **_BODY},
          dependencies=[Depends(same_origin)])
def register(body: CredentialsInput, p: Persistence = Depends(get_persistence)) -> dict:
    return common.register(p, body.email, body.password).to_view()


@app.post("/api/auth/login", response_model=AccountView, operation_id="login",
          responses={401: {"model": Error}, 403: {"model": Error}, 429: {"model": Error}, **_BODY},
          dependencies=[Depends(same_origin)])
def login(body: CredentialsInput, response: Response, p: Persistence = Depends(get_persistence)) -> dict:
    issued = common.log_in(p, body.email, body.password, SESSION)
    common.set_session_cookie(response, issued)
    return {"id": issued.account_id, "email": body.email.strip().lower()}


@app.post("/api/auth/token", response_model=TokenView, operation_id="issueToken",
          responses={401: {"model": Error}, 403: {"model": Error}, 429: {"model": Error}, **_BODY},
          dependencies=[Depends(same_origin)])
def issue_token(body: CredentialsInput, p: Persistence = Depends(get_persistence)) -> dict:
    return common.token_view(common.log_in(p, body.email, body.password, BEARER))


@app.post("/api/auth/logout", response_model=LogoutResult, operation_id="logout", responses=_AUTH)
def logout(response: Response, who: Caller = Depends(caller),
           p: Persistence = Depends(get_persistence)) -> dict:
    result = common.log_out(p, who)
    common.clear_session_cookie(response)
    return result


@app.get("/api/auth/me", response_model=AccountView, operation_id="me", responses=_AUTH)
def me(who: Caller = Depends(caller), p: Persistence = Depends(get_persistence)) -> dict:
    return common.account_view(p, who.identity)


# --- Todos (toutes protégées ; le propriétaire est l'identité de l'appelant) ---

@app.get("/api/todos", response_model=TodoList, operation_id="listTodos", responses=_AUTH)
def list_todos(who: Caller = Depends(caller), p: Persistence = Depends(get_persistence)) -> dict:
    return {"items": ListTodos(p.todos).execute(who.identity)}


@app.post("/api/todos", response_model=TodoView, status_code=201, operation_id="createTodo",
          responses={400: {"model": ErrorList}, **_AUTH, **_BODY})
def create_todo(body: TodoCreateInput, who: Caller = Depends(caller),
                p: Persistence = Depends(get_persistence)) -> dict:
    todo = CreateTodo(p.todos, RealClock(), UuidGenerator()).execute(who.identity, body.model_dump())
    return todo.to_view()


@app.get("/api/todos/{id}", response_model=TodoView, operation_id="getTodo",
         responses={404: {"model": Error}, **_AUTH})
def get_todo(id: str, who: Caller = Depends(caller), p: Persistence = Depends(get_persistence)) -> dict:
    return GetTodo(p.todos).execute(who.identity, id).to_view()


@app.patch("/api/todos/{id}", response_model=TodoView, operation_id="toggleTodo",
           responses={404: {"model": Error}, **_AUTH})
def toggle_todo(id: str, who: Caller = Depends(caller), p: Persistence = Depends(get_persistence)) -> dict:
    return ToggleTodo(p.todos, RealClock()).execute(who.identity, id).to_view()


@app.delete("/api/todos/{id}", response_model=DeleteResult, operation_id="deleteTodo",
            responses={404: {"model": Error}, **_AUTH})
def delete_todo(id: str, who: Caller = Depends(caller), p: Persistence = Depends(get_persistence)) -> dict:
    return DeleteTodo(p.todos).execute(who.identity, id)


# Front statique (îlot Svelte + client généré). Monté en dernier : les routes /api priment.
# Seul `public/` est servi : ni sources, ni migrations, ni configuration.
_public = Path(__file__).resolve().parents[2] / "public"
if _public.is_dir() and os.environ.get("TODO_SERVE_STATIC", "1") == "1":
    app.mount("/", StaticFiles(directory=str(_public), html=True), name="public")
