"""Port d'identité — `CurrentUser`, le même nom que dans les autres kits de la famille : il donne
aux cas d'usage l'identifiant du compte courant. Il n'est JAMAIS alimenté par la requête.

Forme propre à ce kit : un objet-valeur déjà résolu. L'adaptateur HTTP établit l'identité (cookie
de session ou jeton porteur) AVANT d'appeler le cas d'usage, qui reçoit un `CurrentUser` en
premier argument ; un cas d'usage ne s'exécute donc jamais sans identité, et `id()` ne lève pas.
(Dans kit-php, `CurrentUser` est une interface que l'adaptateur implémente et dont `id()` lève
quand aucune identité n'est établie : même nom, même rôle, résolution plus tardive.)"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CurrentUser:
    account_id: str

    def __post_init__(self) -> None:
        if not self.account_id:
            raise ValueError("Le compte courant porte toujours un identifiant.")

    def id(self) -> str:
        return self.account_id
