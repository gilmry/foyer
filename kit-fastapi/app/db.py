"""Fabrique de connexion PostgreSQL (psycopg v3)."""
from __future__ import annotations

import psycopg

from app.config import dsn


def connect() -> psycopg.Connection:
    return psycopg.connect(dsn())
