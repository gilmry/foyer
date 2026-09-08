"""Codegen : génère public/generated/todos.client.js depuis openapi/todos.openapi.json.
Le client est la SEULE porte d'accès du front à l'API (anti-drift : pas d'URL en dur dans l'îlot)."""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = json.loads((ROOT / "openapi" / "todos.openapi.json").read_text(encoding="utf-8"))
out = Path(os.environ.get("TODOS_CLIENT_OUT", ROOT / "public" / "generated" / "todos.client.js"))

methods: list[str] = []
for path, ops in spec.get("paths", {}).items():
    for http in ("get", "post", "patch", "delete"):
        op = ops.get(http)
        if not op or "operationId" not in op:
            continue
        op_id = op["operationId"]
        has_id = "{id}" in path
        has_body = "requestBody" in op
        js_path = path.lstrip("/").replace("{id}", "${encodeURIComponent(id)}")
        args = ([("id")] if has_id else []) + (["input"] if has_body else [])
        opts = f"{{ method: '{http.upper()}'"
        if has_body:
            opts += ", body: JSON.stringify(input)"
        opts += " }"
        methods.append(
            f"    {op_id}: function ({', '.join(args)}) {{\n"
            f"      return transport(`{js_path}`, {opts});\n"
            f"    }}"
        )

code = (
    "// GÉNÉRÉ depuis openapi/todos.openapi.json — NE PAS ÉDITER À LA MAIN (gate contrat).\n"
    "function createTodosClient(transport) {\n"
    "  return {\n" + ",\n".join(methods) + ",\n"
    "  };\n"
    "}\n"
    "if (typeof window !== 'undefined') { window.createTodosClient = createTodosClient; }\n"
    "if (typeof module !== 'undefined') { module.exports = { createTodosClient }; }\n"
)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(code, encoding="utf-8")
print(f"Client généré : {out}")
