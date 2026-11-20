"""Cas d'usage : ouvrir une session (cookie) ou délivrer un jeton porteur.

- « compte inconnu » et « mauvais mot de passe » lèvent la MÊME erreur, après le même travail ;
- au-delà de `max_attempts` échecs dans la fenêtre pour un même courriel, tout essai est refusé,
  bon mot de passe compris, jusqu'à ce que la fenêtre glisse ; la limite tient aussi sous des
  requêtes simultanées (essai réservé, avec son rang, avant toute vérification) ;
- le jeton remis est opaque ; seule son empreinte est conservée, avec son échéance."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.application.identity.fingerprint import fingerprint
from app.domain.identity import rules
from app.domain.identity.exceptions import InvalidCredentialsError, TooManyAttemptsError
from app.domain.identity.ports import (
    AccountRepository,
    LoginAttempts,
    PasswordHasher,
    TokenGenerator,
    TokenRepository,
)
from app.domain.identity.token import AccessToken
from app.domain.todo.clock import Clock
from app.domain.todo.id_generator import IdGenerator

MAX_ATTEMPTS = 5
ATTEMPT_WINDOW = timedelta(minutes=15)


@dataclass(frozen=True)
class IssuedToken:
    """Seul endroit où la valeur claire du jeton existe : elle part dans la réponse, puis disparaît."""

    value: str
    kind: str
    account_id: str
    expires_at: datetime


class LogIn:
    def __init__(self, accounts: AccountRepository, hasher: PasswordHasher, tokens: TokenRepository,
                 attempts: LoginAttempts, generator: TokenGenerator, clock: Clock, ids: IdGenerator,
                 secret_key: str, max_attempts: int = MAX_ATTEMPTS,
                 window: timedelta = ATTEMPT_WINDOW) -> None:
        self._accounts = accounts
        self._hasher = hasher
        self._tokens = tokens
        self._attempts = attempts
        self._generator = generator
        self._clock = clock
        self._ids = ids
        self._key = secret_key
        self._max = max_attempts
        self._window = window

    def execute(self, email: str, password: str, kind: str, ttl: timedelta) -> IssuedToken:
        # Bornes d'abord : ni hachage ni accès à la base pour une valeur démesurée ou non stockable.
        if not rules.acceptable_for_login(email, password):
            raise InvalidCredentialsError("Identifiants invalides.")
        now = self._clock.now()
        email = rules.normalize_email(email)
        subject = fingerprint(self._key, "essai:" + email)
        self._attempts.purge_before(now - self._window)
        # L'essai est RÉSERVÉ avant toute vérification : enregistré et compté d'un seul geste
        # atomique par sujet, il reçoit son rang. Compter d'abord et enregistrer après le hachage
        # laisserait N requêtes simultanées lire toutes un compteur sous le seuil.
        attempt_id = self._ids.uuid()
        if self._attempts.reserve(attempt_id, subject, now, now - self._window) > self._max:
            self._attempts.remove(attempt_id)  # un essai refusé ne prolonge pas le verrouillage
            raise TooManyAttemptsError("Trop d'essais. Réessayez plus tard.")

        account = self._accounts.find_by_email(email)
        if account is None:
            self._hasher.dummy_verify(password)
            valid = False
        else:
            valid = self._hasher.verify(account.password_hash, password)
        if not valid or account is None:
            raise InvalidCredentialsError("Identifiants invalides.")  # l'essai reste compté

        self._attempts.clear(subject)
        self._tokens.purge_expired(now)
        value = self._generator.new_token()
        expires_at = now + ttl
        self._tokens.add(AccessToken(
            token_hash=fingerprint(self._key, value),
            account_id=account.id,
            kind=kind,
            created_at=now,
            expires_at=expires_at,
        ))
        return IssuedToken(value=value, kind=kind, account_id=account.id, expires_at=expires_at)
