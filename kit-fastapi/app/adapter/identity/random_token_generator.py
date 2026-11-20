"""Jetons opaques — 256 bits tirés du générateur du système."""
from __future__ import annotations

import secrets


class RandomTokenGenerator:
    def new_token(self) -> str:
        return secrets.token_urlsafe(32)
