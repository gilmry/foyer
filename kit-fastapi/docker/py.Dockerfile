# Image Python du kit — base PUBLIQUE, la même distribution que la cible de déploiement
# (Debian 12, glibc 2.36, Python 3.12) : ce qui passe les gates ici est ce qui tourne là-bas.
# Dépendances installées depuis le VERROU (versions et empreintes) : rien n'est résolu au build.
# Autonome : aucune image privée. `docker/build.sh` la construit sous le tag todo-kit-fastapi:local.
FROM python:3.12-slim-bookworm
ARG VERROU=inconnu
LABEL kit.verrou=$VERROU
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY requirements-dev.lock ./
RUN pip install --no-cache-dir --no-deps --require-hashes -r requirements-dev.lock
