"""Gate `verify` / `plancher` — invariants structurels (exit 0 = 🟢, ≠0 = 🔴).
Checks : G1 (pas de secret en dur), G2 (migrations réversibles + SQL portable),
H1 (pureté hexagonale : domaine/application sans infra), C1 (contrat + client à jour)."""
from __future__ import annotations

import ast
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

# --- G1 : aucun secret en clair (mot de passe non vide) dans le code versionné ---
for py in (ROOT / "app").rglob("*.py"):
    text = py.read_text(encoding="utf-8")
    if re.search(r"""password\s*=\s*['"][^'"]{3,}['"]""", text, re.IGNORECASE):
        failures.append(f"G1: secret potentiel en dur dans {py.relative_to(ROOT)}")

# --- G2 : chaque *.up.sql a son *.down.sql ; SQL portable ---
for up in (ROOT / "database" / "migrations" / "pending").glob("*.up.sql"):
    down = up.with_name(up.name.replace(".up.sql", ".down.sql"))
    if not down.exists():
        failures.append(f"G2: migration sans réversion : {up.name}")
    sql = re.sub(r"--[^\n]*", "", up.read_text(encoding="utf-8"))
    if re.search(r"\bNOW\(\)|\bSERIAL\b|\bAUTO_INCREMENT\b", sql, re.IGNORECASE):
        failures.append(f"G2: SQL non portable (NOW()/SERIAL/AUTO_INCREMENT) dans {up.name}")

# --- H1 : domaine + application ne dépendent d'aucune infra ---
FORBIDDEN = ("fastapi", "pydantic", "psycopg", "sqlalchemy", "uvicorn", "starlette")
for layer in ("domain", "application"):
    for py in (ROOT / "app" / layer).rglob("*.py"):
        tree = ast.parse(py.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            mods: list[str] = []
            if isinstance(node, ast.Import):
                mods = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                mods = [node.module]
            for m in mods:
                if m.split(".")[0] in FORBIDDEN:
                    failures.append(f"H1: import infra '{m}' dans couche pure {py.relative_to(ROOT)}")

# --- C1 : contrat OpenAPI committé == contrat réel de l'app FastAPI (anti-drift) ---
# (La fraîcheur du client TS api.ts vs OpenAPI est vérifiée par le gate `contrat`, harness/run-contract.sh.)
import json  # noqa: E402

spec_path = ROOT / "openapi" / "todos.openapi.json"
if not spec_path.exists():
    failures.append("C1: openapi/todos.openapi.json absent (lancer harness/dump_openapi.py)")
else:
    os.environ.setdefault("TODO_SERVE_STATIC", "0")
    sys.path.insert(0, str(ROOT))
    from app.http.api import app  # noqa: E402
    live = json.dumps(app.openapi(), indent=2, ensure_ascii=False).strip()
    committed = spec_path.read_text(encoding="utf-8").strip()
    if live != committed:
        failures.append("C1: openapi/todos.openapi.json désynchronisé de l'app (lancer harness/dump_openapi.py)")

if failures:
    sys.stderr.write("verify: 🔴\n - " + "\n - ".join(failures) + "\n")
    sys.exit(1)
print("verify: 🟢 tous les invariants sont verts.")
