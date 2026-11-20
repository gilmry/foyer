"""Configuration — tout vient de l'environnement. Aucun secret en dur (gate G1).

Base : DATABASE_URL, ou DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD.
Identité (ADR-001) :
  TODO_ENV            production (défaut) | development. En développement seulement : cookie sans
                      l'attribut Secure, clé d'instance facultative.
  TODO_SECRET_KEY     clé de l'instance (empreintes des jetons). Exigée hors développement,
                      32 caractères au moins ; tirée sur le serveur par deployer.sh.
  TODO_REGISTRATION   closed (défaut) | open : la route d'inscription est-elle ouverte ?
  TODO_PUBLIC_URL     adresse publique (https://…) : origine attendue des requêtes à cookie.
                      Exigée hors développement.
  TODO_SESSION_TTL, TODO_BEARER_TTL  durées de vie en secondes (défauts : 12 h, 30 jours)."""
from __future__ import annotations

import os
from datetime import timedelta


class ConfigError(RuntimeError):
    """Réglage manquant ou invalide : l'application refuse de démarrer plutôt que de s'affaiblir."""


def dsn() -> str:
    return os.environ.get(
        "DATABASE_URL",
        "host={h} port={p} dbname={d} user={u} password={pw}".format(
            h=os.environ.get("DB_HOST", "localhost"),
            p=os.environ.get("DB_PORT", "5432"),
            d=os.environ.get("DB_NAME", "todo"),
            u=os.environ.get("DB_USER", "todo"),
            pw=os.environ.get("DB_PASSWORD", ""),
        ),
    )


def is_development() -> bool:
    return os.environ.get("TODO_ENV", "production").lower() == "development"


def secret_key() -> str:
    key = os.environ.get("TODO_SECRET_KEY", "")
    if len(key) >= 32:
        return key
    if is_development():
        return key
    raise ConfigError("TODO_SECRET_KEY est absente ou trop courte (32 caractères au moins).")


def registration_open() -> bool:
    return os.environ.get("TODO_REGISTRATION", "closed").lower() == "open"


def public_origin() -> str | None:
    """Origine attendue des requêtes à cookie (schéma compris). Exigée hors développement : sans
    elle, le contrôle se replierait sur l'hôte de la requête, sans pouvoir comparer le schéma."""
    url = os.environ.get("TODO_PUBLIC_URL", "").strip().rstrip("/").lower()
    if url:
        if not url.startswith(("https://", "http://")) or "/" in url.split("://", 1)[1]:
            raise ConfigError("TODO_PUBLIC_URL doit être de la forme https://hôte[:port], sans chemin.")
        return url
    if is_development():
        return None
    raise ConfigError("TODO_PUBLIC_URL est absente : elle est exigée hors développement.")


def cookie_secure() -> bool:
    return not is_development()


def _seconds(name: str, default: int) -> timedelta:
    try:
        value = int(os.environ.get(name, default))
    except ValueError as exc:
        raise ConfigError(f"{name} doit être un nombre de secondes.") from exc
    if value <= 0:
        raise ConfigError(f"{name} doit être positif.")
    return timedelta(seconds=value)


def session_ttl() -> timedelta:
    return _seconds("TODO_SESSION_TTL", 12 * 3600)


def bearer_ttl() -> timedelta:
    return _seconds("TODO_BEARER_TTL", 30 * 24 * 3600)
