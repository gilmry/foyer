"""Configuration — DSN PostgreSQL depuis l'environnement. Aucun secret en dur (gate G1)."""
from __future__ import annotations

import os


def dsn() -> str:
    return os.environ.get(
        "DATABASE_URL",
        "host={h} port={p} dbname={d} user={u} password={pw}".format(
            h=os.environ.get("DB_HOST", "localhost"),
            p=os.environ.get("DB_PORT", "5432"),
            d=os.environ.get("DB_NAME", "todo"),
            u=os.environ.get("DB_USER", "todo"),
            pw=os.environ.get("DB_PASSWORD", ""),
        ),
    )
