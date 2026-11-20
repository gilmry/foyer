"""Texte acceptable — pur. Une chaîne venue de l'appelant peut porter ce qu'aucun stockage ne
prend : un octet NUL (refusé par PostgreSQL) ou un demi-codet isolé (non encodable en UTF-8).
Ces valeurs sont refusées à la validation, comme une entrée invalide, jamais par une erreur 500."""
from __future__ import annotations


def is_storable(value: str) -> bool:
    if "\x00" in value:
        return False
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        return False
    return True
