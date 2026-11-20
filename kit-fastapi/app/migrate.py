"""Outil de migration du kit — `python -m app.migrate up|down|status`.

- `up`     applique, dans l'ordre, les `database/migrations/pending/*.up.sql` qui manquent ;
- `down`   annule la dernière migration appliquée (son `*.down.sql`) ;
- `status` liste les migrations et leur état.

Chaque migration appliquée est tracée dans `schema_migrations` (version, somme de contrôle SHA-256,
date). L'outil REFUSE de continuer si le fichier d'une migration déjà passée a changé, ou a
disparu : on n'édite pas une migration jouée, on en écrit une nouvelle.

Sans dépendance à l'ORM (psycopg seul) : qui a choisi le SQL pur n'installe pas SQLAlchemy pour
migrer. Un verrou consultatif PostgreSQL sérialise deux exécutions simultanées (deux processus
d'un même serveur qui démarrent ensemble). Chaque migration et sa trace partagent une transaction."""
from __future__ import annotations

import hashlib
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg

from app.config import dsn

MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "database" / "migrations" / "pending"
_LOCK_KEY = 7_203_301_001  # arbitraire, propre à cet outil


class MigrationError(RuntimeError):
    pass


def _checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _on_disk(directory: Path) -> dict[str, Path]:
    return {p.name[: -len(".up.sql")]: p for p in sorted(directory.glob("*.up.sql"))}


def _ensure_table(conn: psycopg.Connection) -> None:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS schema_migrations ("
        " version VARCHAR(255) NOT NULL PRIMARY KEY,"
        " checksum CHAR(64) NOT NULL,"
        " applied_at TIMESTAMPTZ NOT NULL)"
    )
    conn.commit()


def _applied(conn: psycopg.Connection) -> dict[str, str]:
    rows = conn.execute("SELECT version, checksum FROM schema_migrations ORDER BY version").fetchall()
    conn.commit()
    return {str(v): str(c) for v, c in rows}


def _verify(applied: dict[str, str], disk: dict[str, Path]) -> None:
    for version, checksum in applied.items():
        if version not in disk:
            raise MigrationError(f"la migration déjà passée {version} n'est plus dans le dépôt")
        if _checksum(disk[version]) != checksum:
            raise MigrationError(
                f"la somme de contrôle de {version} a changé depuis son passage : "
                "une migration jouée ne se modifie pas, écrivez-en une nouvelle"
            )


def up(conn: psycopg.Connection, directory: Path = MIGRATIONS_DIR) -> list[str]:
    """Applique les migrations manquantes ; rend la liste de celles qui viennent d'être jouées."""
    disk = _on_disk(directory)
    applied = _applied(conn)
    _verify(applied, disk)
    done: list[str] = []
    for version, path in disk.items():
        if version in applied:
            continue
        if applied and version < max(applied):
            raise MigrationError(f"{version} est antérieure à une migration déjà passée ({max(applied)})")
        try:
            conn.execute(path.read_text(encoding="utf-8"))
            conn.execute(
                "INSERT INTO schema_migrations (version, checksum, applied_at) VALUES (%s, %s, %s)",
                (version, _checksum(path), datetime.now(timezone.utc)),
            )
            conn.commit()
        except psycopg.Error as exc:
            conn.rollback()
            raise MigrationError(f"{version} a échoué, rien n'en est gardé : {exc}") from exc
        applied[version] = _checksum(path)
        done.append(version)
    return done


def down(conn: psycopg.Connection, directory: Path = MIGRATIONS_DIR) -> str | None:
    """Annule la dernière migration appliquée ; rend sa version, ou None s'il n'y en a aucune."""
    disk = _on_disk(directory)
    applied = _applied(conn)
    _verify(applied, disk)
    if not applied:
        return None
    version = max(applied)
    path = disk[version].with_name(f"{version}.down.sql")
    if not path.exists():
        raise MigrationError(f"{version} n'a pas de fichier .down.sql")
    try:
        conn.execute(path.read_text(encoding="utf-8"))
        conn.execute("DELETE FROM schema_migrations WHERE version = %s", (version,))
        conn.commit()
    except psycopg.Error as exc:
        conn.rollback()
        raise MigrationError(f"l'annulation de {version} a échoué, rien n'est changé : {exc}") from exc
    return version


def status(conn: psycopg.Connection, directory: Path = MIGRATIONS_DIR) -> list[tuple[str, str]]:
    disk = _on_disk(directory)
    applied = _applied(conn)
    lines: list[tuple[str, str]] = []
    for version in sorted(set(disk) | set(applied)):
        if version not in applied:
            lines.append((version, "en attente"))
        elif version not in disk:
            lines.append((version, "passée, FICHIER ABSENT"))
        elif _checksum(disk[version]) != applied[version]:
            lines.append((version, "passée, SOMME DE CONTRÔLE CHANGÉE"))
        else:
            lines.append((version, "passée"))
    return lines


def run(command: str, directory: Path = MIGRATIONS_DIR) -> int:
    with psycopg.connect(dsn()) as conn:
        conn.execute("SELECT pg_advisory_lock(%s)", (_LOCK_KEY,))
        try:
            _ensure_table(conn)
            if command == "up":
                done = up(conn, directory)
                print("migrate up : " + (", ".join(done) if done else "rien à jouer, la base est à jour"))
            elif command == "down":
                version = down(conn, directory)
                print("migrate down : " + (f"{version} annulée" if version else "aucune migration à annuler"))
            else:
                lines = status(conn, directory)
                for version, state in lines:
                    print(f"{version}  {state}")
                if any("en attente" not in s and s != "passée" for _, s in lines):
                    return 1
        finally:
            conn.rollback()
            conn.execute("SELECT pg_advisory_unlock(%s)", (_LOCK_KEY,))
            conn.commit()
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in ("up", "down", "status"):
        sys.stderr.write("usage : python -m app.migrate up|down|status\n")
        return 2
    try:
        return run(argv[1])
    except MigrationError as exc:
        sys.stderr.write(f"migrate {argv[1]} : REFUS — {exc}\n")
        return 1
    except psycopg.OperationalError:
        # Pas de détail : le message du pilote peut nommer l'hôte et le login de la base.
        sys.stderr.write(f"migrate {argv[1]} : connexion à la base impossible\n")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
