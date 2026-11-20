"""Hachage des mots de passe — Argon2id (argon2-cffi, licence MIT).

Paramètres : m = 19 Mio, t = 2, p = 1 — le plancher recommandé par l'OWASP, retenu parce que la
cible est une offre mutualisée à 1 CPU et 1 Go (ADR-001). Le hachage porte ses paramètres : on
peut les durcir sans casser les comptes existants. `verify` compare en temps constant."""
from __future__ import annotations

from argon2 import PasswordHasher as _Argon2
from argon2 import Type
from argon2.exceptions import InvalidHashError, VerificationError

_ARGON2 = _Argon2(time_cost=2, memory_cost=19456, parallelism=1, type=Type.ID)
_DUMMY: str | None = None


class Argon2PasswordHasher:
    def hash(self, password: str) -> str:
        return _ARGON2.hash(password)

    def verify(self, password_hash: str, password: str) -> bool:
        try:
            return _ARGON2.verify(password_hash, password)
        except (VerificationError, InvalidHashError):
            return False

    def dummy_verify(self, password: str) -> None:
        # Hachage factice calculé une fois par processus : mêmes paramètres, donc même coût.
        global _DUMMY
        if _DUMMY is None:
            _DUMMY = _ARGON2.hash("compte-inconnu")
        self.verify(_DUMMY, password)
