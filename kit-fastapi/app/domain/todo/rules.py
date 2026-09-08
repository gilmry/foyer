"""Règles de validation du domaine Todo — messages en français."""
from __future__ import annotations

TITLE_MAX = 255


def validate(data: dict) -> list[str]:
    """Retourne la liste d'erreurs (vide si valide)."""
    errors: list[str] = []
    title = str(data.get("title", "")).strip()
    if not title:
        errors.append("Le libellé est obligatoire.")
    elif len(title) > TITLE_MAX:
        errors.append(f"Le libellé ne peut dépasser {TITLE_MAX} caractères.")
    return errors


def normalize_title(title: str) -> str:
    return title.strip()
