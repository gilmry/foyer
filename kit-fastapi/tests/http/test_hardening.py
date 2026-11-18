"""Tests de la couche HTTP SANS base : en-têtes de sécurité, erreur générique, refus sans identité,
contrôle d'origine, désérialisation stricte — rejoués sur les DEUX adaptateurs (FastAPI, Starlette).

La persistance est remplacée par des doubles en mémoire ; une « base en panne » est un double qui
lève l'erreur du pilote. Le parcours contre un vrai PostgreSQL est dans le gate e2e."""
from __future__ import annotations

import importlib
import os

import pytest
from starlette.testclient import TestClient

os.environ.setdefault("TODO_SECRET_KEY", "k" * 40)
os.environ["TODO_SERVE_STATIC"] = "1"

from app.adapter import factory  # noqa: E402
from app.adapter.factory import Persistence  # noqa: E402
from app.http import common  # noqa: E402
from app.http.hardening import Hardening  # noqa: E402
from tests.fakes.fake_identity import (  # noqa: E402
    FakeAccountRepository, FakeLoginAttempts, FakeTokenRepository)
from tests.fakes.fake_repository import FakeTodoRepository  # noqa: E402

REQUIRED = ("strict-transport-security", "x-content-type-options", "x-frame-options",
            "content-security-policy", "referrer-policy")
SECRET = "un mot de passe assez long"


class _Calls:
    """Compte les accès aux todos : « aucun cas d'usage n'est exécuté » se vérifie ici."""

    def __init__(self) -> None:
        self.todos = FakeTodoRepository()
        self.count = 0

    def __getattr__(self, name):
        def call(*args, **kwargs):
            self.count += 1
            return getattr(self.todos, name)(*args, **kwargs)
        return call


@pytest.fixture(params=["fastapi", "starlette"])
def world(request, monkeypatch):
    module = importlib.import_module("app.http.api" if request.param == "fastapi" else "app.http.starlette_app")
    state = Persistence(_Calls(), FakeAccountRepository(), FakeTokenRepository(), FakeLoginAttempts())

    from contextlib import contextmanager

    @contextmanager
    def fake_persistence(which=None):
        yield state

    monkeypatch.setattr(factory, "persistence", fake_persistence)
    monkeypatch.setattr(factory, "ping", lambda: None)
    monkeypatch.setenv("TODO_REGISTRATION", "open")
    monkeypatch.setenv("TODO_PUBLIC_URL", "https://kit.exemple.test")
    client = TestClient(Hardening(module.app), base_url="https://kit.exemple.test",
                        raise_server_exceptions=False)
    return client, state, monkeypatch


def _bearer(client) -> dict:
    client.post("/api/auth/register", json={"email": "a@exemple.test", "password": SECRET})
    token = client.post("/api/auth/token", json={"email": "a@exemple.test", "password": SECRET}).json()["token"]
    return {"Authorization": f"Bearer {token}"}


def test_security_headers_on_page_api_and_errors(world) -> None:  # @security
    client, _, _ = world
    for path in ("/", "/api/health", "/api/todos", "/introuvable", "/todos-island/index.js"):
        response = client.get(path)
        for header in REQUIRED:
            assert header in response.headers, f"{header} manque sur {path} ({response.status_code})"
    assert client.get("/").headers["x-frame-options"] == "DENY"
    assert "frame-ancestors 'none'" in client.get("/api/health").headers["content-security-policy"]


def test_unauthenticated_calls_are_401_and_touch_nothing(world) -> None:  # @negative
    client, state, _ = world
    calls = [
        client.get("/api/todos"),
        client.post("/api/todos", json={"title": "x"}),
        client.get("/api/todos/un-id"),
        client.patch("/api/todos/un-id"),
        client.delete("/api/todos/un-id"),
        client.get("/api/auth/me"),
        client.post("/api/auth/logout"),
        client.get("/api/todos", headers={"Authorization": "Bearer jamais-delivre"}),
    ]
    for response in calls:
        assert response.status_code == 401
        assert response.json() == {"error": "Authentification requise."}
    assert state.todos.count == 0  # aucun accès aux todos : aucun cas d'usage exécuté


def test_owner_field_in_request_is_rejected(world) -> None:  # @security
    client, state, _ = world
    headers = _bearer(client)
    for intrus in ("owner_id", "ownerId", "owner", "proprietaire"):
        response = client.post("/api/todos", json={"title": "x", intrus: "compte-b"}, headers=headers)
        assert response.status_code == 422
        assert response.json() == {"error": "Corps invalide."}
    assert state.todos.todos.count() == 0


def test_validation_error_never_echoes_the_password(world) -> None:  # @security
    client, _, _ = world
    response = client.post("/api/auth/register",
                           json={"email": "a@exemple.test", "password": SECRET, "role": "admin"})
    assert response.status_code == 422
    assert SECRET not in response.text


def test_database_failure_gives_generic_500(world) -> None:  # @security
    client, _, monkeypatch = world
    headers = _bearer(client)

    class Panne(Exception):
        pass

    def broken(which=None):
        raise Panne('connection to server at "db.interne.exemple" (10.0.0.7), port 5432 failed: '
                    'FATAL: password authentication failed for user "compte_instance"')

    monkeypatch.setattr(factory, "persistence", broken)
    monkeypatch.setattr(factory, "ping", broken)
    for response in (client.get("/api/todos", headers=headers),
                     client.post("/api/auth/login", json={"email": "a@exemple.test", "password": SECRET})):
        assert response.status_code == 500
        assert response.json() == {"error": "Erreur interne."}
        for fuite in ("Traceback", "db.interne", "10.0.0.7", "compte_instance", "Panne", "psycopg"):
            assert fuite not in response.text
        assert "x-content-type-options" in response.headers
    health = client.get("/api/health")
    assert health.status_code == 503 and health.json() == {"status": "indisponible"}


def test_session_cookie_attributes_and_origin_check(world) -> None:  # @security
    client, state, monkeypatch = world
    client.post("/api/auth/register", json={"email": "a@exemple.test", "password": SECRET})
    login = client.post("/api/auth/login", json={"email": "a@exemple.test", "password": SECRET},
                        headers={"Origin": "https://kit.exemple.test"})
    assert login.status_code == 200
    cookie = login.headers["set-cookie"]
    assert cookie.startswith(common.SESSION_COOKIE + "=")
    lowered = cookie.lower()
    assert "httponly" in lowered and "samesite=strict" in lowered and "secure" in lowered and "path=/" in lowered
    assert "domain=" not in lowered
    session = {"Cookie": cookie.split(";", 1)[0]}
    client.cookies.clear()

    assert client.get("/api/todos", headers=session).status_code == 200  # méthode sûre : pas d'Origin exigé
    same = client.post("/api/todos", json={"title": "x"}, headers={**session, "Origin": "https://kit.exemple.test"})
    assert same.status_code == 201
    for headers in (session, {**session, "Origin": "https://pirate.exemple.test"}, {**session, "Origin": "null"}):
        refused = client.post("/api/todos", json={"title": "y"}, headers=headers)
        assert refused.status_code == 403 and refused.json() == {"error": "Origine refusée."}
    assert state.todos.todos.count() == 1
    # Une connexion demandée depuis une autre origine est refusée avant tout essai.
    foreign = client.post("/api/auth/login", json={"email": "a@exemple.test", "password": SECRET},
                          headers={"Origin": "https://pirate.exemple.test"})
    assert foreign.status_code == 403
    # Le cookie de session ne vaut pas jeton porteur, et inversement.
    value = session["Cookie"].split("=", 1)[1]
    assert client.get("/api/todos", headers={"Authorization": f"Bearer {value}"}).status_code == 401

    out = client.post("/api/auth/logout", headers={**session, "Origin": "https://kit.exemple.test"})
    assert out.status_code == 200 and out.json() == {"loggedOut": True}
    assert client.get("/api/todos", headers=session).status_code == 401  # session révoquée côté serveur


def test_registration_closed_by_default(world) -> None:  # @security
    client, state, monkeypatch = world
    monkeypatch.delenv("TODO_REGISTRATION", raising=False)
    response = client.post("/api/auth/register", json={"email": "a@exemple.test", "password": SECRET})
    assert response.status_code == 403 and response.json() == {"error": "Inscription fermée."}
    assert state.accounts.by_id == {}


def test_nothing_outside_public_is_served(world) -> None:  # @negative
    client, _, _ = world
    for path in ("/app/config.py", "/requirements.txt", "/database/", "/.git/config", "/.env",
                 "/wsgi.py", "/../requirements.txt", "/%2e%2e/requirements.txt", "/..%2fapp/config.py",
                 "/database/migrations/pending/0001_create_todos.up.sql"):
        response = client.get(path)
        assert response.status_code in (400, 403, 404), f"{path} → {response.status_code}"
        for contenu in ("CREATE TABLE", "fastapi==", "def dsn", "DATABASE_URL"):
            assert contenu not in response.text


def test_identity_comes_before_the_body(world) -> None:  # @negative — même ordre sur les deux adaptateurs
    client, state, _ = world
    json_headers = {"Content-Type": "application/json"}
    for content in (b"{pas du json", b'{"title": 5}', b'{"title":"x","owner":"b"}', b""):
        response = client.post("/api/todos", content=content, headers=json_headers)
        assert response.status_code == 401, content
    assert client.post("/api/todos", content=b'{"title":"x"}', headers={"Content-Type": "text/plain"}).status_code == 401
    headers = _bearer(client)
    assert client.post("/api/todos", content=b"{pas du json", headers={**headers, **json_headers}).status_code == 422
    assert state.todos.todos.count() == 0


def test_json_content_type_is_required(world) -> None:  # @negative
    client, state, _ = world
    headers = _bearer(client)
    for content_type in ("text/plain", "application/x-www-form-urlencoded"):
        response = client.post("/api/todos", content=b'{"title":"x"}', headers={**headers, "Content-Type": content_type})
        assert response.status_code == 422, content_type
    response = client.post("/api/auth/token", content=b'{"email":"a@exemple.test","password":"' + SECRET.encode() + b'"}',
                           headers={"Content-Type": "text/plain"})
    assert response.status_code == 422
    assert state.todos.todos.count() == 0


def test_body_size_is_bounded(world) -> None:  # @security
    client, state, _ = world
    headers = _bearer(client)
    big = client.post("/api/todos", json={"title": "x" * 20000}, headers=headers)
    assert big.status_code == 413 and big.json() == {"error": "Corps trop volumineux."}
    assert "x-content-type-options" in big.headers
    huge_login = client.post("/api/auth/token", json={"email": "a@exemple.test", "password": "x" * 20000})
    assert huge_login.status_code == 413
    chunked = client.post("/api/todos", content=iter([b'{"title":', b'"x"}']),
                          headers={**headers, "Content-Type": "application/json"})
    assert chunked.status_code == 411
    assert state.todos.todos.count() == 0


def _refusal(headers, chunks):
    """Joue une requête ASGI contre l'enveloppe seule : renvoie (statut, morceaux lus, ordre)."""
    import asyncio

    pending, order = list(chunks), []

    async def receive():
        order.append("lu")
        body = pending.pop(0)
        return {"type": "http.request", "body": body, "more_body": bool(pending)}

    async def send(message):
        if message["type"] == "http.response.start":
            order.append(message["status"])

    async def never(scope, receive, send):
        raise AssertionError("l'application ne doit pas être appelée")

    scope = {"type": "http", "method": "POST", "path": "/api/todos", "headers": headers}
    asyncio.run(Hardening(never)(scope, receive, send))
    return order


def test_refused_body_is_read_before_the_answer() -> None:  # @security
    """Répondre 413 puis fermer sans lire le corps fait perdre la réponse derrière un frontal."""
    chunks = [b"x" * 8000, b"x" * 8000, b"x" * 4000]
    assert _refusal([(b"content-length", b"20000")], chunks) == ["lu", "lu", "lu", 413]
    assert _refusal([(b"transfer-encoding", b"chunked")], chunks) == ["lu", "lu", "lu", 411]


def test_refused_body_is_not_read_without_bound() -> None:  # @security
    from app.http import hardening
    assert _refusal([(b"content-length", str(hardening.DRAIN_MAX + 1).encode())], [b"x"]) == [413]
    # Corps sans longueur annoncée : la lecture s'arrête dès la limite franchie.
    piece = b"x" * (hardening.DRAIN_MAX // 2 + 1)
    assert _refusal([(b"transfer-encoding", b"chunked")], [piece] * 6) == ["lu", "lu", 411]


def test_unstorable_text_is_a_validation_error_not_a_500(world) -> None:  # @negative
    client, state, _ = world
    headers = _bearer(client)
    json_headers = {**headers, "Content-Type": "application/json"}
    for body in (b'{"title":"a\\u0000b"}', b'{"title":"\\ud800"}'):
        response = client.post("/api/todos", content=body, headers=json_headers)
        assert response.status_code == 400, body
    for path in ("/api/todos/%00", "/api/todos/a%00b"):
        for verb in ("get", "patch", "delete"):
            assert getattr(client, verb)(path, headers=headers).status_code == 404
    plain = {"Content-Type": "application/json"}
    for body in (b'{"email":"a\\u0000@exemple.test","password":"' + SECRET.encode() + b'"}',
                 b'{"email":"a@exemple.test","password":"\\ud800' + SECRET.encode() + b'"}'):
        assert client.post("/api/auth/token", content=body, headers=plain).status_code == 401
        assert client.post("/api/auth/login", content=body, headers=plain).status_code == 401
        assert client.post("/api/auth/register", content=body, headers=plain).status_code == 400
    assert state.todos.todos.count() == 0


def test_public_url_is_required_outside_development(monkeypatch) -> None:  # @security
    from app import config
    monkeypatch.delenv("TODO_PUBLIC_URL", raising=False)
    monkeypatch.delenv("TODO_ENV", raising=False)
    with pytest.raises(config.ConfigError, match="TODO_PUBLIC_URL"):
        config.public_origin()
    monkeypatch.setenv("TODO_PUBLIC_URL", "https://kit.exemple.test/chemin")
    with pytest.raises(config.ConfigError, match="TODO_PUBLIC_URL"):
        config.public_origin()
    monkeypatch.setenv("TODO_ENV", "development")
    monkeypatch.delenv("TODO_PUBLIC_URL", raising=False)
    assert config.public_origin() is None
