"""Tests des cas d'usage d'identité (inscription, connexion, résolution, déconnexion) avec fakes."""
from __future__ import annotations

from datetime import timedelta

import pytest

from app.application.identity.fingerprint import fingerprint
from app.application.identity.log_in import LogIn
from app.application.identity.log_out import LogOut
from app.application.identity.register_account import RegisterAccount
from app.application.identity.resolve_identity import ResolveIdentity
from app.domain.identity.exceptions import (
    AccountValidationError,
    EmailAlreadyUsedError,
    InvalidCredentialsError,
    RegistrationClosedError,
    TooManyAttemptsError,
)
from app.domain.identity.token import BEARER, SESSION
from tests.fakes.fake_clock import FakeClock
from tests.fakes.fake_id_generator import FakeIdGenerator
from tests.fakes.fake_identity import (
    FakeAccountRepository,
    FakeLoginAttempts,
    FakePasswordHasher,
    FakeTokenGenerator,
    FakeTokenRepository,
)

KEY = "clé-de-test-" + "x" * 32
SECRET = "un mot de passe assez long"
TTL = timedelta(hours=1)


class World:
    def __init__(self) -> None:
        self.accounts = FakeAccountRepository()
        self.hasher = FakePasswordHasher()
        self.tokens = FakeTokenRepository()
        self.attempts = FakeLoginAttempts()
        self.clock = FakeClock()
        self.ids = FakeIdGenerator()

    def register(self, email: str = "a@exemple.test", password: str = SECRET, open_: bool = True):
        return RegisterAccount(self.accounts, self.hasher, self.clock, self.ids, open_).execute(email, password)

    def log_in(self, email: str = "a@exemple.test", password: str = SECRET, kind: str = SESSION):
        return LogIn(self.accounts, self.hasher, self.tokens, self.attempts, FakeTokenGenerator(),
                     self.clock, self.ids, KEY).execute(email, password, kind, TTL)

    def resolve(self, value: str, kind: str = SESSION):
        return ResolveIdentity(self.tokens, self.clock, KEY).execute(value, kind)


def test_register_stores_only_a_hash() -> None:  # @security
    w = World()
    account = w.register(email="  A@Exemple.TEST ")
    assert account.email == "a@exemple.test"
    stored = w.accounts.find(account.id)
    assert SECRET not in stored.password_hash
    assert "password" not in account.to_view() and "password_hash" not in account.to_view()


def test_register_rejects_weak_password_and_bad_email() -> None:  # @negative
    w = World()
    with pytest.raises(AccountValidationError):
        w.register(password="court")
    with pytest.raises(AccountValidationError):
        w.register(email="pas-un-courriel")
    with pytest.raises(AccountValidationError):
        w.register(password="x" * 129)
    assert w.accounts.by_id == {}


def test_register_twice_same_email() -> None:  # @negative
    w = World()
    w.register()
    with pytest.raises(EmailAlreadyUsedError):
        w.register()


def test_register_closed() -> None:  # @security
    w = World()
    with pytest.raises(RegistrationClosedError):
        w.register(open_=False)
    assert w.accounts.by_id == {}


def test_log_in_issues_opaque_token_stored_hashed() -> None:  # @security
    w = World()
    account = w.register()
    issued = w.log_in()
    assert issued.account_id == account.id
    assert issued.value not in w.tokens.by_hash  # la valeur claire n'est pas en base
    assert fingerprint(KEY, issued.value) in w.tokens.by_hash
    assert w.resolve(issued.value).account_id == account.id


def test_unknown_account_and_wrong_password_are_indistinguishable() -> None:  # @security
    w = World()
    w.register()
    with pytest.raises(InvalidCredentialsError) as wrong:
        w.log_in(password="mauvais mot de passe")
    with pytest.raises(InvalidCredentialsError) as unknown:
        w.log_in(email="inconnu@exemple.test")
    assert str(wrong.value) == str(unknown.value)
    assert w.hasher.dummy_calls == 1  # le compte inconnu coûte un hachage, comme l'autre


def test_too_many_attempts_locks_even_the_right_password() -> None:  # @security
    w = World()
    w.register()
    for _ in range(5):
        with pytest.raises(InvalidCredentialsError):
            w.log_in(password="mauvais mot de passe")
    with pytest.raises(TooManyAttemptsError):
        w.log_in()
    w.clock.advance(15 * 60 + 1)  # la fenêtre glisse
    assert w.log_in().value


def test_successful_log_in_clears_attempts() -> None:  # @edge
    w = World()
    w.register()
    for _ in range(4):
        with pytest.raises(InvalidCredentialsError):
            w.log_in(password="mauvais mot de passe")
    w.log_in()
    assert w.attempts.rows == []


def test_token_kind_is_not_interchangeable() -> None:  # @security
    w = World()
    w.register()
    session = w.log_in(kind=SESSION)
    assert w.resolve(session.value, BEARER) is None
    assert w.resolve(session.value, SESSION) is not None


def test_expired_or_revoked_token_resolves_to_nothing() -> None:  # @edge
    w = World()
    w.register()
    issued = w.log_in()
    LogOut(w.tokens, KEY).execute(issued.value)
    assert w.resolve(issued.value) is None
    other = w.log_in()
    w.clock.advance(3601)
    assert w.resolve(other.value) is None
    assert w.resolve("") is None and w.resolve("jamais-délivré") is None


def test_oversized_or_unstorable_credentials_are_refused_before_any_hashing() -> None:  # @security
    w = World()
    w.register()
    calls = []
    w.hasher.verify = lambda *a: calls.append(a) or False
    for email, password in (("a@exemple.test", "x" * 129), ("a" * 400 + "@exemple.test", SECRET),
                            ("a@exemple.test", "nul\x00" + SECRET), ("a\x00@exemple.test", SECRET),
                            ("a@exemple.test", "\ud800" + SECRET)):
        with pytest.raises(InvalidCredentialsError):
            w.log_in(email=email, password=password)
    assert calls == [] and w.hasher.dummy_calls == 0 and w.attempts.rows == []


def test_refused_attempt_does_not_extend_the_lockout() -> None:  # @edge
    w = World()
    w.register()
    for _ in range(5):
        with pytest.raises(InvalidCredentialsError):
            w.log_in(password="mauvais mot de passe")
    for _ in range(3):
        with pytest.raises(TooManyAttemptsError):
            w.log_in()
    assert len(w.attempts.rows) == 5
