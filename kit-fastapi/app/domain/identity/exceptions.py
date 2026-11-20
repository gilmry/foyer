"""Exceptions du domaine d'identité — traduites en codes HTTP par l'adaptateur."""
from __future__ import annotations


class AccountValidationError(Exception):
    """Courriel ou mot de passe violant une règle → HTTP 400."""

    def __init__(self, errors: list[str]) -> None:
        self.errors = errors
        super().__init__(" ".join(errors))


class EmailAlreadyUsedError(Exception):
    """Un compte porte déjà ce courriel → HTTP 409."""


class RegistrationClosedError(Exception):
    """L'inscription est fermée sur cette instance → HTTP 403."""


class InvalidCredentialsError(Exception):
    """Compte inconnu OU mauvais mot de passe : volontairement indistinguables → HTTP 401."""


class TooManyAttemptsError(Exception):
    """Trop d'essais de connexion échoués pour ce courriel → HTTP 429."""
