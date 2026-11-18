"""Gestion des comptes en ligne de commande — `python -m app.accounts …`.

  create <courriel>           crée un compte. Le mot de passe est lu sur l'entrée standard si elle
                              n'est pas un terminal (`printf '%s' "$mdp" | python -m app.accounts
                              create a@exemple.test`) ; sinon il est TIRÉ et affiché une seule fois.
  revoke <courriel>           révoque toutes les sessions et tous les jetons de ce compte (appareil
                              perdu, jeton divulgué) ; le compte et ses todos restent.
  adopt <courriel>            rattache à ce compte les todos sans propriétaire (créés avant la
                              migration 0002).

Sert quand l'inscription est fermée (`TODO_REGISTRATION=closed`, le réglage d'un déploiement) :
la commande passe par le même cas d'usage que la route d'inscription. Le mot de passe ne passe
jamais en argument : il se lirait dans la liste des processus et dans l'historique du shell."""
from __future__ import annotations

import secrets
import sys

from app.adapter.factory import persistence
from app.adapter.identity.argon2_password_hasher import Argon2PasswordHasher
from app.adapter.todo.real_clock import RealClock
from app.adapter.todo.uuid_generator import UuidGenerator
from app.application.identity.register_account import RegisterAccount
from app.domain.identity import rules
from app.domain.identity.exceptions import AccountValidationError, EmailAlreadyUsedError


def create(email: str) -> int:
    drawn = sys.stdin.isatty()
    password = secrets.token_urlsafe(18) if drawn else sys.stdin.readline().rstrip("\r\n")
    with persistence() as p:
        try:
            account = RegisterAccount(p.accounts, Argon2PasswordHasher(), RealClock(), UuidGenerator(),
                                      registration_open=True).execute(email, password)
        except AccountValidationError as exc:
            sys.stderr.write("accounts create : " + " ".join(exc.errors) + "\n")
            return 1
        except EmailAlreadyUsedError:
            sys.stderr.write("accounts create : ce courriel a déjà un compte\n")
            return 1
    print(f"compte créé : {account.email}")
    if drawn:
        print(f"mot de passe (affiché cette seule fois) : {password}")
    return 0


def adopt(email: str) -> int:
    import psycopg

    from app.config import dsn
    with psycopg.connect(dsn()) as conn:
        row = conn.execute("SELECT id FROM accounts WHERE email = %s", (rules.normalize_email(email),)).fetchone()
        if row is None:
            sys.stderr.write("accounts adopt : compte inconnu\n")
            return 1
        count = conn.execute("UPDATE todos SET owner_id = %s WHERE owner_id IS NULL", (row[0],)).rowcount
        conn.commit()
    print(f"{count} todo(s) sans propriétaire rattaché(s) à {rules.normalize_email(email)}")
    return 0


def revoke(email: str) -> int:
    import psycopg

    from app.config import dsn
    with psycopg.connect(dsn()) as conn:
        row = conn.execute("SELECT id FROM accounts WHERE email = %s", (rules.normalize_email(email),)).fetchone()
        if row is None:
            sys.stderr.write("accounts revoke : compte inconnu\n")
            return 1
        count = conn.execute("DELETE FROM auth_tokens WHERE account_id = %s", (row[0],)).rowcount
        conn.commit()
    print(f"{count} session(s) ou jeton(s) révoqué(s) pour {rules.normalize_email(email)}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) == 3 and argv[1] == "create":
        return create(argv[2])
    if len(argv) == 3 and argv[1] == "revoke":
        return revoke(argv[2])
    if len(argv) == 3 and argv[1] == "adopt":
        return adopt(argv[2])
    sys.stderr.write("usage : python -m app.accounts create <courriel> | revoke <courriel> | adopt <courriel>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
