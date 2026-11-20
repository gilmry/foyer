#!/usr/bin/env bash
# Construit, SUR LE POSTE, ce qui part chez l'hébergeur : les binaires `server` et `migrate` en
# mode release, dans l'image du kit (Debian 12, glibc 2.36 : la distribution du serveur visé), et
# le front statique. Le serveur de l'hébergeur ne compile rien.
# Sortie : deploiement/alwaysdata/dist/ (ignoré par git).
set -euo pipefail
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$ICI/../.." && pwd)"
source "$ROOT/harness/ensure-images.sh"; ensure_rust_image

docker run --rm -v "$ROOT":/app -w /app "${CARGO_VOLS[@]}" todo-kit-rust:local \
  cargo build --quiet --release --locked --bin server --bin migrate

rm -rf "$ICI/dist"; mkdir -p "$ICI/dist"
# Les binaires sont dans le volume de cache : on les en sort par `docker cp` (fichiers à soi).
c="$(docker create -v todo_actix_target:/cible todo-kit-rust:local)"
trap 'docker rm "$c" >/dev/null 2>&1 || true' EXIT
docker cp -q "$c:/cible/release/server" "$ICI/dist/server"
docker cp -q "$c:/cible/release/migrate" "$ICI/dist/migrate"
cp -R "$ROOT/public" "$ICI/dist/public"
echo "construit : $(cd "$ICI/dist" && ls -1 | tr '\n' ' ')→ $ICI/dist"
