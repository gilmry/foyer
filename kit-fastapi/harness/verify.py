"""Gate `verify` / `plancher` — invariants structurels (exit 0 = 🟢, ≠0 = 🔴).
Checks : G1 (pas de secret en dur), G2 (migrations réversibles + SQL portable),
H1 (pureté hexagonale : domaine/application sans infra), C1 (contrat à jour, schémas de sécurité
compris), D1 (dépendances épinglées et verrouillées avec empreintes)."""
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
SECRET = re.compile(r"""(password|passwd|mot_de_passe|secret_key|secret|token|jeton)\s*=\s*['"][^'"$\n]{3,}['"]""",
                    re.IGNORECASE)
for src in [*(ROOT / "app").rglob("*.py"), ROOT / "wsgi.py", *(ROOT / "deploiement").rglob("*.sh"),
            *(ROOT / "harness").glob("*.sh")]:
    if SECRET.search(src.read_text(encoding="utf-8")):
        failures.append(f"G1: secret potentiel en dur dans {src.relative_to(ROOT)}")
# Aucune migration ne pose de compte : pas de compte de démonstration à mot de passe connu.
for sql_file in (ROOT / "database").rglob("*.sql"):
    if re.search(r"INSERT\s+INTO\s+accounts", sql_file.read_text(encoding="utf-8"), re.IGNORECASE):
        failures.append(f"G1: compte posé par migration dans {sql_file.relative_to(ROOT)}")

# --- G2 : chaque *.up.sql a son *.down.sql ; SQL portable ---
for up in (ROOT / "database" / "migrations" / "pending").glob("*.up.sql"):
    down = up.with_name(up.name.replace(".up.sql", ".down.sql"))
    if not down.exists():
        failures.append(f"G2: migration sans réversion : {up.name}")
    sql = re.sub(r"--[^\n]*", "", up.read_text(encoding="utf-8"))
    if re.search(r"\bNOW\(\)|\bSERIAL\b|\bAUTO_INCREMENT\b", sql, re.IGNORECASE):
        failures.append(f"G2: SQL non portable (NOW()/SERIAL/AUTO_INCREMENT) dans {up.name}")

# --- H1 : domaine + application ne dépendent d'aucune infra ---
FORBIDDEN = ("fastapi", "pydantic", "psycopg", "sqlalchemy", "uvicorn", "starlette", "argon2", "a2wsgi",
             "secrets", "os")
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
    # Le contrat décrit les deux schémas de sécurité, et toute opération sur les todos les exige.
    spec = json.loads(committed)
    schemes = spec.get("components", {}).get("securitySchemes", {})
    if schemes.get("bearerAuth", {}).get("scheme") != "bearer" or schemes.get("sessionCookie", {}).get("in") != "cookie":
        failures.append("C1: schémas de sécurité bearerAuth / sessionCookie absents du contrat")
    for path, ops in spec.get("paths", {}).items():
        if not path.startswith("/api/todos"):
            continue
        for verb, op in ops.items():
            required = {name for req in op.get("security", []) for name in req}
            if required != {"bearerAuth", "sessionCookie"}:
                failures.append(f"C1: {verb.upper()} {path} n'exige pas d'identité dans le contrat")
            if "401" not in op.get("responses", {}):
                failures.append(f"C1: {verb.upper()} {path} ne documente pas le refus 401")

# --- D1 : dépendances épinglées, verrou à jour et porteur d'empreintes ---
def _pins(name: str) -> dict[str, str]:
    pins = {}
    for line in (ROOT / name).read_text(encoding="utf-8").splitlines():
        line = line.split("#")[0].strip()
        if not line or line.startswith("-r"):
            continue
        m = re.fullmatch(r"([A-Za-z0-9_.-]+)(?:\[[^\]]*\])?==([^\s\\]+)", line)
        if not m:
            failures.append(f"D1: dépendance non épinglée dans {name} : {line}")
            continue
        pins[m.group(1).lower().replace("_", "-")] = m.group(2)
    return pins


def _locked(name: str) -> dict[str, str]:
    text = (ROOT / name).read_text(encoding="utf-8")
    if "--hash=sha256:" not in text:
        failures.append(f"D1: {name} ne porte pas d'empreintes")
    return {m.group(1).lower().replace("_", "-"): m.group(2)
            for m in re.finditer(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)", text, re.MULTILINE)}


for req, lock in (("requirements.txt", "requirements.lock"), ("requirements-dev.txt", "requirements-dev.lock")):
    if not (ROOT / lock).exists():
        failures.append(f"D1: {lock} absent (lancer docker/verrouiller.sh)")
        continue
    locked = _locked(lock)
    wanted = _pins(req) | (_pins("requirements.txt") if req != "requirements.txt" else {})
    for package, version in wanted.items():
        if locked.get(package) != version:
            failures.append(f"D1: {lock} désynchronisé pour {package} (lancer docker/verrouiller.sh)")
if {"pytest", "httpx"} & set(_locked("requirements.lock")):
    failures.append("D1: une dépendance de test est entrée dans le verrou d'exécution")

if failures:
    sys.stderr.write("verify: 🔴\n - " + "\n - ".join(failures) + "\n")
    sys.exit(1)
print("verify: 🟢 tous les invariants sont verts.")
