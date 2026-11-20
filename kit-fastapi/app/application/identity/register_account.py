"""Cas d'usage : créer un compte. Le mot de passe n'est conservé que haché."""
from __future__ import annotations

from app.domain.identity import rules
from app.domain.identity.account import Account
from app.domain.identity.exceptions import (
    AccountValidationError,
    EmailAlreadyUsedError,
    RegistrationClosedError,
)
from app.domain.identity.ports import AccountRepository, PasswordHasher
from app.domain.todo.clock import Clock
from app.domain.todo.id_generator import IdGenerator


class RegisterAccount:
    def __init__(self, accounts: AccountRepository, hasher: PasswordHasher, clock: Clock,
                 ids: IdGenerator, registration_open: bool = True) -> None:
        self._accounts = accounts
        self._hasher = hasher
        self._clock = clock
        self._ids = ids
        self._open = registration_open

    def execute(self, email: str, password: str) -> Account:
        if not self._open:
            raise RegistrationClosedError("Inscription fermée.")
        errors = rules.validate(email, password)
        if errors:
            raise AccountValidationError(errors)
        account = Account(
            id=self._ids.uuid(),
            email=rules.normalize_email(email),
            password_hash=self._hasher.hash(password),
            created_at=self._clock.now(),
        )
        if not self._accounts.add(account):
            raise EmailAlreadyUsedError("Ce courriel est déjà utilisé.")
        return account
