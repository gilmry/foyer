#!/usr/bin/env bash
# Gate `unit` + `bdd` (domaine + application), sans DB — cargo test via Docker (base publique).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image
exec docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" \
  todo-kit-rust:local cargo test --quiet --lib --test application
