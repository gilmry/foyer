# Image Python du kit — base PUBLIQUE (python:3.12-slim) + dépendances.
# Autonome : aucune image privée. `docker/build.sh` la construit sous le tag todo-kit-fastapi:local.
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
