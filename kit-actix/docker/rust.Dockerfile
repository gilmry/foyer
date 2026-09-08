# Image Rust du kit — base PUBLIQUE (rust:1-slim-bookworm) + outils de build.
# Autonome : aucune image privée. sqlx en tls-none (pas d'OpenSSL).
FROM rust:1-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*
