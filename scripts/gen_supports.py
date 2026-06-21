#!/usr/bin/env python3
"""Génère docs/supports.md à partir des médias présents dans notebooklm/.

Idempotent : relancé à chaque build, la page reflète exactement l'état du
dossier — ajouter un média dans notebooklm/<catégorie>/ suffit à le publier,
sans rien éditer à la main.

Les URL sont percent-encodées (UTF-8) pour servir correctement les noms
accentués sur GitHub Pages. Comme mkdocs.yml fixe use_directory_urls: false,
supports.html et notebooklm/ sont voisins à la racine du site : les liens
relatifs « notebooklm/... » résolvent correctement (y compris sous /foyer/).
"""
from pathlib import Path
from urllib.parse import quote

SRC = Path("notebooklm")
OUT = Path("docs/supports.md")

# (sous-dossier, titre affiché, description). L'ordre fixe l'ordre des sections.
SECTIONS = [
    ("Vidéos", "🎬 Vidéos", "Présentations animées de la méthode."),
    ("Podcasts", "🎧 Podcasts", "Conversations et débats audio générés."),
    ("Infographies", "🖼️ Infographies", "Visuels de synthèse — cliquer pour agrandir."),
    ("Pitchs", "📑 Pitchs (PDF)", "Supports de présentation, téléchargeables."),
]

MEDIA_EXTS = {".mp4", ".m4a", ".png", ".pdf"}
STYLE = 'style="width:100%;max-width:820px"'


def title_of(path: Path) -> str:
    return path.stem.replace("___", " — ").replace("_", " ").strip()


def url_of(path: Path) -> str:
    # chemin relatif à la racine du site (notebooklm/ y est copié tel quel)
    return quote(path.as_posix())


def render(path: Path) -> str:
    suf = path.suffix.lower()
    url = url_of(path)
    title = title_of(path)
    if suf == ".mp4":
        return (
            f"### {title}\n\n"
            f'<video controls preload="metadata" {STYLE}>\n'
            f'  <source src="{url}" type="video/mp4">\n'
            f'  <a href="{url}">Télécharger la vidéo</a>\n'
            f"</video>\n"
        )
    if suf == ".m4a":
        return (
            f"### {title}\n\n"
            f'<audio controls preload="metadata" {STYLE}>\n'
            f'  <source src="{url}" type="audio/mp4">\n'
            f'  <a href="{url}">Télécharger l\'audio</a>\n'
            f"</audio>\n"
        )
    if suf == ".png":
        return (
            f"### {title}\n\n"
            f'<a href="{url}" target="_blank" rel="noopener">'
            f'<img src="{url}" alt="{title}" {STYLE}></a>\n'
        )
    if suf == ".pdf":
        return f"- 📄 [{title}]({url}){{ target=_blank }} — *PDF*"
    return f"- [{title}]({url})"


def media_in(folder: Path):
    return sorted(
        p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in MEDIA_EXTS
    )


def main() -> None:
    lines = [
        "# Supports pédagogiques",
        "",
        "Ressources générées pour présenter et transmettre la Méthode Foyer. "
        "Vidéos et podcasts se lisent directement dans la page ; les pitchs "
        "sont téléchargeables.",
    ]

    rendered_any = False
    seen = set()

    def emit_section(folder: Path, label: str, desc: str):
        nonlocal rendered_any
        files = media_in(folder)
        if not files:
            return
        seen.add(folder.name)
        rendered_any = True
        lines.append("")
        lines.append(f"## {label}")
        lines.append("")
        lines.append(desc)
        compact = all(f.suffix.lower() == ".pdf" for f in files)
        for f in files:
            lines.append("" if compact else "")
            lines.append(render(f))

    if SRC.exists():
        for key, label, desc in SECTIONS:
            emit_section(SRC / key, label, desc)
        # Catégories non prévues : robustesse si un nouveau dossier apparaît.
        for folder in sorted(p for p in SRC.iterdir() if p.is_dir()):
            if folder.name not in seen:
                emit_section(folder, folder.name, "")

    if not rendered_any:
        lines += ["", "*Aucun support média trouvé dans `notebooklm/`.*"]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Généré {OUT}")


if __name__ == "__main__":
    main()
