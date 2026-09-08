# Image visuelle du kit — base PUBLIQUE (node:22-bookworm) + Chromium Playwright.
# bookworm (Debian 12) : `playwright install --with-deps` fonctionne (contrairement à trixie).
# Autonome : aucune image privée. Construite par docker/build.sh sous le tag todo-kit-visual:local.
FROM node:22-bookworm

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /app/harness/visual
COPY package.json ./
RUN npm install >/dev/null 2>&1 && \
    npx playwright install --with-deps chromium
