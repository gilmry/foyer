"""Jeton d'accès — opaque. Seule son EMPREINTE est conservée : la valeur claire n'existe que dans
la réponse qui la remet à l'appelant. `kind` distingue la session (cookie) du jeton porteur."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

SESSION = "session"
BEARER = "bearer"
KINDS = (SESSION, BEARER)


@dataclass(frozen=True)
class AccessToken:
    token_hash: str
    account_id: str
    kind: str
    created_at: datetime
    expires_at: datetime

    def __post_init__(self) -> None:
        if self.kind not in KINDS:
            raise ValueError(f"Type de jeton inconnu : {self.kind}.")

    def is_expired(self, now: datetime) -> bool:
        return now >= self.expires_at
