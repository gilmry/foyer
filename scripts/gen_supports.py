#!/usr/bin/env python3
"""Génère docs/supports.md à partir des médias présents dans notebooklm/.

Idempotent : relancé à chaque build, la page reflète exactement l'état du
dossier — ajouter un média dans notebooklm/<catégorie>/ suffit à le publier,
sans rien éditer à la main.

Une section peut être éclatée en sous-sections (un titre par sous-dossier) :
c'est le cas des Podcasts, où « Deep Dive » et « Débat » sont distingués, le
Débat étant rejeté à la fin.

Les URL sont percent-encodées (UTF-8) pour servir correctement les noms
accentués sur GitHub Pages. Comme mkdocs.yml fixe use_directory_urls: false,
supports.html et notebooklm/ sont voisins à la racine du site : les liens
relatifs « notebooklm/... » résolvent correctement (y compris sous /foyer/).
"""
from pathlib import Path
from urllib.parse import quote

SRC = Path("notebooklm")
OUT = Path("docs/supports.md")

# Chaque entrée décrit une section. `split` éclate la section par sous-dossier ;
# `sub_labels` renomme l'affichage d'un sous-dossier ; `sub_last` force certains
# sous-dossiers en fin de section (ici, le Débat passe après le Deep Dive).
SECTIONS = [
    {
        "dir": "Vidéos",
        "label": "🎬 Vidéos",
        "desc": "Présentations animées de la méthode.",
    },
    {
        "dir": "Podcasts",
        "label": "🎧 Podcasts",
        "desc": "Conversations audio générées.",
        "split": True,
        "sub_labels": {"Deep Dive": "Deep Dive", "Debat": "Débat"},
        "sub_last": ["Debat"],
    },
    {
        "dir": "Infographies",
        "label": "🖼️ Infographies",
        "desc": "Visuels de synthèse — cliquer pour agrandir.",
    },
    {
        "dir": "Pitchs",
        "label": "📑 Pitchs (PDF)",
        "desc": "Supports de présentation, téléchargeables.",
    },
]

MEDIA_EXTS = {".mp4", ".m4a", ".png", ".pdf"}
STYLE = 'style="width:100%;max-width:820px"'


def title_of(path: Path) -> str:
    return path.stem.replace("___", " — ").replace("_", " ").strip()


def url_of(path: Path) -> str:
    # chemin relatif à la racine du site (notebooklm/ y est copié tel quel)
    return quote(path.as_posix())


def render(path: Path, level: int = 3) -> str:
    suf = path.suffix.lower()
    url = url_of(path)
    title = title_of(path)
    h = "#" * level
    if suf == ".mp4":
        return (
            f"{h} {title}\n\n"
            f'<video controls preload="metadata" {STYLE}>\n'
            f'  <source src="{url}" type="video/mp4">\n'
            f'  <a href="{url}">Télécharger la vidéo</a>\n'
            f"</video>\n"
        )
    if suf == ".m4a":
        return (
            f"{h} {title}\n\n"
            f'<audio controls preload="metadata" {STYLE}>\n'
            f'  <source src="{url}" type="audio/mp4">\n'
            f'  <a href="{url}">Télécharger l\'audio</a>\n'
            f"</audio>\n"
        )
    if suf == ".png":
        return (
            f"{h} {title}\n\n"
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


def ordered_subdirs(folder: Path, sub_last):
    subs = sorted(p for p in folder.iterdir() if p.is_dir())
    last = [s for s in subs if s.name in sub_last]
    rest = [s for s in subs if s.name not in sub_last]
    # `rest` alphabétique, puis les sous-dossiers « rejetés en fin » dans l'ordre demandé.
    last.sort(key=lambda s: sub_last.index(s.name))
    return rest + last


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

    def emit_items(files, level):
        for f in files:
            lines.append("")
            lines.append(render(f, level))

    def emit_section(section):
        nonlocal rendered_any
        folder = SRC / section["dir"]
        if not folder.exists():
            return
        split = section.get("split", False)
        if not split:
            files = media_in(folder)
            if not files:
                return
            seen.add(folder.name)
            rendered_any = True
            lines.append("")
            lines.append(f"## {section['label']}")
            lines.append("")
            lines.append(section["desc"])
            emit_items(files, level=3)
            return

        # Section éclatée par sous-dossier.
        sub_labels = section.get("sub_labels", {})
        sub_last = section.get("sub_last", [])
        subdirs = [d for d in ordered_subdirs(folder, sub_last) if media_in(d)]
        direct = sorted(
            p for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() in MEDIA_EXTS
        )
        if not subdirs and not direct:
            return
        seen.add(folder.name)
        rendered_any = True
        lines.append("")
        lines.append(f"## {section['label']}")
        lines.append("")
        lines.append(section["desc"])
        if direct:  # fichiers à la racine de la section (sans sous-dossier)
            emit_items(direct, level=3)
        for d in subdirs:
            lines.append("")
            lines.append(f"### {sub_labels.get(d.name, d.name)}")
            emit_items(media_in(d), level=4)

    if SRC.exists():
        for section in SECTIONS:
            emit_section(section)
        # Catégories non prévues : robustesse si un nouveau dossier apparaît.
        for folder in sorted(p for p in SRC.iterdir() if p.is_dir()):
            if folder.name not in seen:
                emit_section({"dir": folder.name, "label": folder.name, "desc": ""})

    if not rendered_any:
        lines += ["", "*Aucun support média trouvé dans `notebooklm/`.*"]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Généré {OUT}")


if __name__ == "__main__":
    main()
