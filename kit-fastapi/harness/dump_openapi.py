"""Dump du contrat OpenAPI depuis l'app FastAPI vers openapi/todos.openapi.json.
FastAPI EST la source de vérité du contrat (généré depuis les routes + schémas Pydantic).
Le gate `contrat` vérifie que le fichier committé et le client généré restent en phase."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

os.environ.setdefault("TODO_SERVE_STATIC", "0")  # pas besoin du front pour dumper le contrat
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.http.api import app  # noqa: E402

out = ROOT / "openapi" / "todos.openapi.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(app.openapi(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Contrat OpenAPI écrit : {out}")
