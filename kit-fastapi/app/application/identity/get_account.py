"""Cas d'usage : le compte de l'appelant (« qui suis-je ? »)."""
from __future__ import annotations

from app.domain.identity.account import Account
from app.domain.identity.current_user import CurrentUser
from app.domain.identity.ports import AccountRepository


class GetAccount:
    def __init__(self, accounts: AccountRepository) -> None:
        self._accounts = accounts

    def execute(self, current_user: CurrentUser) -> Account | None:
        return self._accounts.find(current_user.id())
