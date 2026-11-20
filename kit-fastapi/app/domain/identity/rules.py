"""Règles de validation des comptes — messages en français."""
from __future__ import annotations

import re

from app.domain.text import is_storable

EMAIL_MAX = 254
PASSWORD_MIN = 12
# Borne haute : un mot de passe démesuré ferait travailler le hachage pour rien (déni de service).
PASSWORD_MAX = 128
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def acceptable_for_login(email: str, password: str) -> bool:
    """Bornes appliquées AVANT tout hachage et tout accès à la base, à la connexion : une valeur
    démesurée ou non stockable ne peut être celle d'aucun compte."""
    return (is_storable(email) and is_storable(password)
            and len(email) <= EMAIL_MAX + 64 and len(password) <= PASSWORD_MAX)


def normalize_email(email: str) -> str:
    return email.strip().lower()


def validate(email: str, password: str) -> list[str]:
    """Retourne la liste d'erreurs (vide si valide)."""
    errors: list[str] = []
    if not is_storable(email) or not is_storable(password):
        return ["Le courriel ou le mot de passe contient un caractère interdit."]
    email = normalize_email(email)
    if not _EMAIL.match(email) or len(email) > EMAIL_MAX:
        errors.append("Le courriel est invalide.")
    if len(password) < PASSWORD_MIN:
        errors.append(f"Le mot de passe doit compter au moins {PASSWORD_MIN} caractères.")
    elif len(password) > PASSWORD_MAX:
        errors.append(f"Le mot de passe ne peut dépasser {PASSWORD_MAX} caractères.")
    return errors
