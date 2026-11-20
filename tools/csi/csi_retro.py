#!/usr/bin/env python3
"""
csi_retro.py — Télémétrie CSI Foyer reconstituée a posteriori depuis l'historique Git.

Principe (Foyer, abaque §9 « discipline de lucidité ») : chaque valeur produite est
étiquetée MESURÉ (lu tel quel dans git), DÉRIVÉ (calcul déterministe sur du mesuré)
ou SUPPOSÉ (dépend d'un paramètre [caler] ci-dessous). Rien n'est estimé à la main.

Usage :
    python3 csi_retro.py <dossier_contenant_les_depots> [--out sortie/] [--gap 120] [--lead 30]
    (relancer avec plusieurs --gap/--lead donne la sensibilité des heures aux priors [caler])
Sorties :
    depots.csv       une ligne par dépôt
    semaines.csv     activité par semaine ISO et par dépôt (parallélisme)
    jalons.csv       date d'apparition des pratiques (CI, tests, BDD, ADR, garde-fous IA…)
    sessions.csv     sessions de travail reconstituées (base du wall-clock)
Stdlib uniquement, aucun réseau, lecture seule.
"""
import csv, os, re, subprocess, sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

# ---- Paramètres [caler] : priors à remplacer par du mesuré ----------------------------
SESSION_GAP_MIN = 120      # [caler] au-delà de cet écart entre deux commits, nouvelle session
SESSION_LEAD_MIN = 30      # [caler] temps de travail avant le premier commit d'une session
BOT_AUTHORS = re.compile(r"dependabot|github-actions|renovate|\[bot\]", re.I)
AI_AUTHORS = re.compile(r"^(claude|koprogo-agent)$", re.I)
AI_TRAILER = re.compile(r"^Co-Authored-By:.*(claude|anthropic)", re.I | re.M)
CONV = re.compile(r"^(feat|fix|refactor|docs|test|tests|chore|ci|perf|security|build|style|revert|retrofit)(\(|:|!)", re.I)

CODE_EXT = {".rs", ".ts", ".svelte", ".astro", ".php", ".py", ".js", ".mjs", ".sql",
            ".tf", ".sh", ".go", ".lua", ".java", ".kt", ".vue", ".tsx", ".jsx"}
DOC_EXT = {".md", ".rst", ".adoc", ".txt"}
SKIP = re.compile(r"(package-lock\.json|Cargo\.lock|composer\.lock|yarn\.lock|pnpm-lock|\.min\.|"
                  r"notebooklm/|/vendor/|node_modules/|\.sqlx/|openapi\.(json|ya?ml)$)")
TEST_PATH = re.compile(r"(^|/)(tests?|spec|e2e|__tests__|features)(/|$)|_test\.|\.test\.|\.spec\.|\.feature$|Test\.php$")

# Jalons : (nom, motif de chemin). Date = premier commit qui AJOUTE un fichier correspondant.
MILESTONES = [
    ("CI", r"^\.github/workflows/.+\.ya?ml$"),
    ("tests", TEST_PATH.pattern),
    ("BDD (.feature)", r"\.feature$"),
    ("ADR", r"(^|/)adrs?/|(^|/)ADR[-_]?\d"),
    ("conteneur", r"(^|/)(Dockerfile|docker-compose[^/]*\.ya?ml)$"),
    ("script de déploiement", r"(^|/)deploy[^/]*\.sh$|(^|/)(terraform|ansible|helm|k8s|argocd)/"),
    ("garde-fous IA (.claude/ ou AGENTS.md)", r"^\.claude/|(^|/)AGENTS\.md$|(^|/)CLAUDE\.md$"),
    ("analyse supply chain", r"(^|/)deny\.toml$|(^|/)audit\.toml$|\.gitleaks|dependabot\.ya?ml$"),
    ("test d'architecture", r"(^|/)(architecture|purete_domaine)\.rs$|ArchitectureTest"),
]


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                          errors="replace", check=True).stdout


def parse_log(repo):
    """Une entrée par commit non-merge : date auteur, nom, message, numstat."""
    sep, end = "\x1e", "\x1f"
    raw = git(repo, "log", "--no-merges", "--numstat", "--date=iso-strict",
              f"--format={sep}%H%x00%aI%x00%an%x00%B{end}")
    commits = []
    for block in raw.split(sep)[1:]:
        head, _, stat = block.partition(end)
        h, date, author, body = head.split("\x00", 3)
        files = []
        for line in stat.strip().splitlines():
            parts = line.split("\t")
            if len(parts) == 3:
                a, d, path = parts
                files.append((None if a == "-" else int(a), None if d == "-" else int(d), path))
        commits.append(dict(hash=h, date=datetime.fromisoformat(date), author=author,
                            subject=body.strip().splitlines()[0] if body.strip() else "",
                            body=body, files=files))
    commits.sort(key=lambda c: c["date"])
    return commits


def added_paths(repo):
    """{chemin: date du premier ajout} via --diff-filter=A."""
    raw = git(repo, "log", "--no-merges", "--diff-filter=A", "--name-only",
              "--date=iso-strict", "--reverse", "--format=\x1e%aI")
    first = {}
    for block in raw.split("\x1e")[1:]:
        lines = block.strip().splitlines()
        if not lines:
            continue
        d = datetime.fromisoformat(lines[0])
        for p in lines[1:]:
            first.setdefault(p, d)
    return first


def classify(path):
    ext = os.path.splitext(path)[1].lower()
    if SKIP.search(path):
        return None
    if TEST_PATH.search(path):
        return "test"
    if ext in CODE_EXT:
        return "code"
    if ext in DOC_EXT:
        return "doc"
    return "autre"


def sessions_of(commits):
    out, cur = [], []
    for c in commits:
        if cur and (c["date"] - cur[-1]["date"]) > timedelta(minutes=SESSION_GAP_MIN):
            out.append(cur); cur = []
        cur.append(c)
    if cur:
        out.append(cur)
    return out


def snapshot_counts(repo):
    """Comptages sur l'état courant (HEAD) : scénarios BDD et tests déclarés."""
    def gg(pattern, *globs):
        r = subprocess.run(["git", "-C", repo, "grep", "-hcE", pattern, "HEAD", "--", *globs],
                           capture_output=True, text=True)
        return sum(int(x.rsplit(":", 1)[-1]) for x in r.stdout.split() if x.rsplit(":", 1)[-1].isdigit())
    return dict(
        scenarios_bdd=gg(r"^\s*(Scenario|Scenario Outline|Scénario|Plan du scénario):", "*.feature"),
        tests_declares=gg(r"#\[(tokio::)?test\]|^\s*(public )?function test|^\s*def test_|^\s*(it|test)\(",
                          "*.rs", "*.php", "*.py", "*.ts", "*.js"),
    )


def agent_branch_commits(repo):
    """Commits arrivés par une branche d'agent fusionnée (ex. « Merge … from x/claude/… »)."""
    raw = git(repo, "log", "--merges", "--format=%H%x00%s")
    hashes = set()
    for line in raw.splitlines():
        h, _, s = line.partition("\x00")
        if re.search(r"from \S*/claude/|from claude/", s, re.I):
            hashes |= set(git(repo, "rev-list", f"{h}^1..{h}^2").split())
    return hashes


def head_lines(repo):
    """Taille de l'état courant (HEAD) par catégorie — ce qui existe, pas ce qui a transité."""
    tot = defaultdict(int)
    for p in git(repo, "ls-files").splitlines():
        k = classify(p)
        if k in ("code", "test", "doc"):
            try:
                with open(os.path.join(repo, p), "rb") as f:
                    tot[k] += sum(1 for line in f if line.strip())
            except (IsADirectoryError, FileNotFoundError):
                pass
    return tot


def analyse(repo_path):
    name = os.path.basename(os.path.normpath(repo_path))
    commits = parse_log(repo_path)
    if not commits:
        return None
    # Un « Initial commit » isolé (> 30 j avant la suite) est un placeholder GitHub, pas le début du travail.
    if len(commits) > 1 and re.match(r"initial commit", commits[0]["subject"], re.I) \
            and commits[1]["date"] - commits[0]["date"] > timedelta(days=30):
        commits = commits[1:]
    human = [c for c in commits if not BOT_AUTHORS.search(c["author"])]
    via_agent = agent_branch_commits(repo_path)
    is_ai = lambda c: bool(AI_AUTHORS.match(c["author"]) or AI_TRAILER.search(c["body"]) or c["hash"] in via_agent)
    ai_auth = sum(1 for c in human if AI_AUTHORS.match(c["author"]))
    ai_trailer = sum(1 for c in human if AI_TRAILER.search(c["body"]))
    ai_any = sum(1 for c in human if is_ai(c))
    conv = defaultdict(int)
    for c in human:
        m = CONV.match(c["subject"])
        conv[m.group(1).lower().rstrip("s") if m else "libre"] += 1
    lines = defaultdict(int)
    for c in human:
        for a, d, p in c["files"]:
            k = classify(p)
            if k and a is not None:
                lines[k] += a
    sess = sessions_of(human)
    hours = sum((s[-1]["date"] - s[0]["date"]).total_seconds() / 3600 + SESSION_LEAD_MIN / 60 for s in sess)
    days = sorted({c["date"].date() for c in human})
    first, last = human[0]["date"], human[-1]["date"]
    added = added_paths(repo_path)
    jalons = []
    for label, pat in MILESTONES:
        rx = re.compile(pat)
        ds = [d for p, d in added.items() if rx.search(p) and not SKIP.search(p)]
        if ds:
            d = min(ds)
            jalons.append(dict(depot=name, jalon=label, date=d.date().isoformat(),
                               jours_depuis_debut=(d - first).days))
    snap = snapshot_counts(repo_path)
    head = head_lines(repo_path)
    n = len(human)
    conv_total = n - conv.get("libre", 0)
    row = dict(
        depot=name,
        premier_commit=first.date().isoformat(), dernier_commit=last.date().isoformat(),
        duree_calendaire_j=(last - first).days + 1, jours_actifs=len(days),
        commits=n, commits_bots=len(commits) - n,
        part_ia_pct=round(100 * ai_any / n, 1) if n else 0,
        part_ia_auteur=ai_auth, part_ia_coauteur=ai_trailer,
        sessions=len(sess), heures_estimees=round(hours, 1),
        lignes_code_ajoutees=lines["code"], lignes_test_ajoutees=lines["test"],
        lignes_doc_ajoutees=lines["doc"],
        head_code=head["code"], head_test=head["test"], head_doc=head["doc"],
        ratio_test_code=round(head["test"] / head["code"], 2) if head["code"] else None,
        ratio_doc_code=round(head["doc"] / head["code"], 2) if head["code"] else None,
        churn=round((lines["code"] + lines["test"]) / (head["code"] + head["test"]), 1)
        if head["code"] + head["test"] else None,
        code_par_heure=round((head["code"] + head["test"]) / hours) if hours else None,
        commits_conventionnels_pct=round(100 * conv_total / n, 1) if n else 0,
        feat=conv.get("feat", 0), fix=conv.get("fix", 0), test=conv.get("test", 0),
        docs=conv.get("doc", 0), refactor=conv.get("refactor", 0),
        ratio_fix_feat=round(conv.get("fix", 0) / conv["feat"], 2) if conv.get("feat") else None,
        **snap,
        stories_estimees=round(snap["scenarios_bdd"] / 4) if snap["scenarios_bdd"] else None,
    )
    weeks = defaultdict(lambda: [0, set()])
    for c in human:
        y, w, _ = c["date"].isocalendar()
        weeks[f"{y}-W{w:02d}"][0] += 1
        weeks[f"{y}-W{w:02d}"][1].add(c["date"].date())
    week_rows = [dict(semaine=k, depot=name, commits=v[0], jours_actifs=len(v[1])) for k, v in sorted(weeks.items())]
    sess_rows = [dict(depot=name, debut=s[0]["date"].isoformat(), fin=s[-1]["date"].isoformat(),
                      commits=len(s), heures=round((s[-1]["date"] - s[0]["date"]).total_seconds() / 3600
                                                   + SESSION_LEAD_MIN / 60, 2)) for s in sess]
    return row, week_rows, jalons, sess_rows


STATUT = {  # étiquette de lucidité par colonne de depots.csv
    "premier_commit": "MESURÉ", "dernier_commit": "MESURÉ", "duree_calendaire_j": "DÉRIVÉ",
    "jours_actifs": "MESURÉ", "commits": "MESURÉ", "commits_bots": "MESURÉ", "part_ia_pct": "MESURÉ",
    "part_ia_auteur": "MESURÉ", "part_ia_coauteur": "MESURÉ", "sessions": "SUPPOSÉ [caler gap]",
    "heures_estimees": "SUPPOSÉ [caler gap+lead]", "lignes_code_ajoutees": "MESURÉ",
    "lignes_test_ajoutees": "MESURÉ", "lignes_doc_ajoutees": "MESURÉ",
    "head_code": "MESURÉ (HEAD, lignes non vides)", "head_test": "MESURÉ (HEAD)", "head_doc": "MESURÉ (HEAD)",
    "ratio_doc_code": "DÉRIVÉ (HEAD)", "ratio_test_code": "DÉRIVÉ (HEAD)",
    "churn": "DÉRIVÉ (lignes ajoutées ÷ lignes présentes : réécriture)",
    "code_par_heure": "SUPPOSÉ (dépend des heures)",
    "commits_conventionnels_pct": "MESURÉ", "ratio_fix_feat": "DÉRIVÉ (si commits conventionnels)",
    "scenarios_bdd": "MESURÉ (HEAD)", "tests_declares": "MESURÉ (HEAD)",
    "stories_estimees": "SUPPOSÉ (règle Foyer ÷4)",
}


def write(path, rows):
    if not rows:
        return
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)


def main():
    import argparse
    global SESSION_GAP_MIN, SESSION_LEAD_MIN
    ap = argparse.ArgumentParser(description="Télémétrie CSI Foyer reconstituée depuis Git.")
    ap.add_argument("racine", nargs="?", default=".", help="dossier contenant les dépôts clonés")
    ap.add_argument("--out", default="csi_out", help="dossier de sortie des CSV")
    ap.add_argument("--gap", type=int, default=SESSION_GAP_MIN, help="[caler] écart (min) qui coupe une session")
    ap.add_argument("--lead", type=int, default=SESSION_LEAD_MIN, help="[caler] travail (min) avant le 1er commit")
    a = ap.parse_args()
    SESSION_GAP_MIN, SESSION_LEAD_MIN = a.gap, a.lead
    root, out = a.racine, a.out
    os.makedirs(out, exist_ok=True)
    rows, weeks, jalons, sess = [], [], [], []
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d)
        if os.path.isdir(os.path.join(p, ".git")):
            r = analyse(p)
            if r:
                rows.append(r[0]); weeks += r[1]; jalons += r[2]; sess += r[3]
    write(os.path.join(out, "depots.csv"), rows)
    write(os.path.join(out, "semaines.csv"), weeks)
    write(os.path.join(out, "jalons.csv"), sorted(jalons, key=lambda j: (j["depot"], j["date"])))
    write(os.path.join(out, "sessions.csv"), sess)
    write(os.path.join(out, "statuts.csv"), [dict(colonne=k, statut=v) for k, v in STATUT.items()])
    print(f"{len(rows)} dépôts, {sum(r['commits'] for r in rows)} commits → {out}/")


if __name__ == "__main__":
    main()
