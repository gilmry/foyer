#!/usr/bin/env bash
# Régénère les verrous de dépendances (transitives comprises, avec empreintes SHA-256).
# Tourne dans l'image de la cible (Debian 12, Python 3.12) : les roues retenues sont celles que
# l'hébergeur sait charger. À relancer après toute modification de requirements*.txt, puis
# reconstruire l'image : `docker rmi todo-kit-fastapi:local && bash docker/build.sh`.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_IMAGE="python:3.12-slim-bookworm"
docker run --rm -v "$ROOT":/kit -w /kit -e PIP_ROOT_USER_ACTION=ignore -e PIP_DISABLE_PIP_VERSION_CHECK=1 \
  -e CUSTOM_COMPILE_COMMAND="bash docker/verrouiller.sh" "$BASE_IMAGE" sh -ec '
    pip install -q pip-tools==7.7.0
    pip-compile -q --generate-hashes --strip-extras --no-header --output-file requirements.lock requirements.txt
    pip-compile -q --generate-hashes --strip-extras --no-header --output-file requirements-dev.lock requirements-dev.txt
    chown "$(stat -c %u:%g requirements.txt)" requirements.lock requirements-dev.lock
  '
echo "✓ verrous régénérés : requirements.lock, requirements-dev.lock"
