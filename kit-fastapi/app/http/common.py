"""Ce que les DEUX adaptateurs HTTP (FastAPI et Starlette) ont en commun : résolution de
l'identité, contrôle d'origine, cookie de session, traduction des exceptions en codes HTTP,
câblage des cas d'usage. Ne connaît que Starlette (dont FastAPI hérite), jamais FastAPI.

L'identité est résolue ICI, dans la couche HTTP, puis passée aux cas d'usage (ADR-001) :
  - `Authorization: Bearer <jeton>` pour les clients d'API ;
  - sinon le cookie de session du front. Le cookie est une identité AMBIANTE (le navigateur le
    joint tout seul) : sur les méthodes non sûres, l'en-tête `Origin` doit désigner ce site."""
from __future__ import annotations

import logging
from dataclasses import dataclass
from urllib.parse import urlsplit

from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app import config
from app.adapter.factory import Persistence
from app.adapter.identity.argon2_password_hasher import Argon2PasswordHasher
from app.adapter.identity.random_token_generator import RandomTokenGenerator
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.identity.get_account import GetAccount
from app.application.identity.log_in import IssuedToken, LogIn
from app.application.identity.log_out import LogOut
from app.application.identity.register_account import RegisterAccount
from app.application.identity.resolve_identity import ResolveIdentity
from app.domain.identity.account import Account
from app.domain.identity.exceptions import (
    AccountValidationError,
    EmailAlreadyUsedError,
    InvalidCredentialsError,
    RegistrationClosedError,
    TooManyAttemptsError,
)
from app.domain.identity.current_user import CurrentUser
from app.domain.identity.token import BEARER, SESSION
from app.domain.todo.exceptions import TodoNotFoundError, TodoValidationError

log = logging.getLogger("todo")

# Préfixe `__Host-` : le navigateur n'accepte ce cookie que Secure, sans Domain et sur Path=/ ;
# un autre site du même domaine parent ne peut donc pas en poser un à notre place.
SESSION_COOKIE = "__Host-todo_session"
DEV_SESSION_COOKIE = "todo_session"  # en développement (http), où `__Host-` serait refusé
UNSAFE_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})


class Unauthenticated(Exception):
    """Aucune identité valide → HTTP 401."""


class OriginRefused(Exception):
    """Requête à cookie venue d'une autre origine → HTTP 403."""


class InvalidBody(Exception):
    """Corps illisible ou champ inconnu (désérialisation stricte) → HTTP 422."""


@dataclass(frozen=True)
class Caller:
    identity: CurrentUser
    token: str  # valeur présentée, pour pouvoir la révoquer à la déconnexion
    kind: str


def cookie_name() -> str:
    return SESSION_COOKIE if config.cookie_secure() else DEV_SESSION_COOKIE


def _origin_matches(request: Request) -> bool | None:
    """True/False si l'en-tête Origin est là ; None s'il est absent."""
    origin = request.headers.get("origin")
    if origin is None:
        return None
    origin = origin.strip().rstrip("/").lower()
    expected = config.public_origin()
    if expected is not None:
        return origin == expected
    # Sans adresse publique configurée — permis en développement seulement (config.public_origin
    # lève sinon) : l'origine doit viser l'hôte servi.
    return urlsplit(origin).netloc == request.headers.get("host", "").lower()


def refuse_foreign_origin(request: Request) -> None:
    """Routes sans identité (inscription, connexion) : un Origin présent doit être le nôtre."""
    if _origin_matches(request) is False:
        raise OriginRefused()


def require_json(request: Request) -> None:
    """Un corps n'est accepté qu'annoncé en application/json, sur les deux adaptateurs."""
    if request.headers.get("content-length", "0") not in ("", "0") and \
            request.headers.get("content-type", "").split(";")[0].strip().lower() != "application/json":
        raise InvalidBody()


def identify(request: Request, p: Persistence) -> Caller:
    resolve = ResolveIdentity(p.tokens, RealClock(), config.secret_key())
    authorization = request.headers.get("authorization", "")
    if authorization[:7].lower() == "bearer ":
        token = authorization[7:].strip()
        identity = resolve.execute(token, BEARER)
        if identity is None:
            raise Unauthenticated()
        return Caller(identity, token, BEARER)
    token = request.cookies.get(cookie_name(), "")
    if not token:
        raise Unauthenticated()
    if request.method in UNSAFE_METHODS and _origin_matches(request) is not True:
        raise OriginRefused()
    identity = resolve.execute(token, SESSION)
    if identity is None:
        raise Unauthenticated()
    return Caller(identity, token, SESSION)


# --- Câblage des cas d'usage d'identité (les mêmes pour les deux adaptateurs) ---

def register(p: Persistence, email: str, password: str) -> Account:
    return RegisterAccount(p.accounts, Argon2PasswordHasher(), RealClock(), UuidGenerator(),
                           registration_open=config.registration_open()).execute(email, password)


def log_in(p: Persistence, email: str, password: str, kind: str) -> IssuedToken:
    ttl = config.session_ttl() if kind == SESSION else config.bearer_ttl()
    return LogIn(p.accounts, Argon2PasswordHasher(), p.tokens, p.attempts, RandomTokenGenerator(),
                 RealClock(), UuidGenerator(), config.secret_key()).execute(email, password, kind, ttl)


def log_out(p: Persistence, caller: Caller) -> dict:
    return LogOut(p.tokens, config.secret_key()).execute(caller.token)


def account_view(p: Persistence, identity: CurrentUser) -> dict:
    account = GetAccount(p.accounts).execute(identity)
    if account is None:
        raise Unauthenticated()
    return account.to_view()


def token_view(issued: IssuedToken) -> dict:
    return {"token": issued.value, "tokenType": "Bearer", "expiresAt": issued.expires_at.isoformat()}


def set_session_cookie(response: Response, issued: IssuedToken) -> None:
    response.set_cookie(
        cookie_name(), issued.value, max_age=int(config.session_ttl().total_seconds()),
        path="/", secure=config.cookie_secure(), httponly=True, samesite="strict",
    )


def clear_session_cookie(response: Response) -> None:
    response.delete_cookie(cookie_name(), path="/", secure=config.cookie_secure(),
                           httponly=True, samesite="strict")


# --- Traduction exceptions → HTTP (seule couche qui connaît les codes) ---

GENERIC_ERROR = {"error": "Erreur interne."}


def _json(status: int, payload: dict, headers: dict | None = None) -> JSONResponse:
    return JSONResponse(payload, status_code=status, headers=headers)


async def _internal(_: Request, exc: Exception) -> JSONResponse:
    # Réponse générique : ni trace, ni message du pilote, ni identifiant. Le détail va au journal.
    return _json(500, GENERIC_ERROR)


EXCEPTION_HANDLERS = {
    TodoValidationError: lambda _, e: _json(400, {"errors": e.errors}),
    AccountValidationError: lambda _, e: _json(400, {"errors": e.errors}),
    Unauthenticated: lambda _, e: _json(401, {"error": "Authentification requise."},
                                        {"WWW-Authenticate": "Bearer"}),
    InvalidCredentialsError: lambda _, e: _json(401, {"error": "Identifiants invalides."}),
    OriginRefused: lambda _, e: _json(403, {"error": "Origine refusée."}),
    RegistrationClosedError: lambda _, e: _json(403, {"error": "Inscription fermée."}),
    TodoNotFoundError: lambda _, e: _json(404, {"error": "Tâche introuvable."}),
    EmailAlreadyUsedError: lambda _, e: _json(409, {"error": "Ce courriel est déjà utilisé."}),
    InvalidBody: lambda _, e: _json(422, {"error": "Corps invalide."}),
    TooManyAttemptsError: lambda _, e: _json(429, {"error": "Trop d'essais. Réessayez plus tard."},
                                             {"Retry-After": "900"}),
    Exception: _internal,
}
