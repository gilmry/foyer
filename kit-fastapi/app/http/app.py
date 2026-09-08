"""Sélecteur d'adaptateur HTTP — FastAPI (défaut) ou Starlette (ASGI nu), via TODO_HTTP.
Les deux exposent le MÊME contrat et délèguent aux mêmes use-cases. Point d'entrée uvicorn :
`uvicorn app.http.app:app`."""
from __future__ import annotations

import os

if os.environ.get("TODO_HTTP", "fastapi").lower() == "starlette":
    from app.http.starlette_app import app  # noqa: F401
else:
    from app.http.api import app  # noqa: F401
