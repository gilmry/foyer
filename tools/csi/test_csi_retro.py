"""Tests de csi_retro.py sur un dépôt synthétique aux dates fixes (stdlib, hors réseau).

    python3 -m unittest tools/csi/test_csi_retro.py
"""
import os, subprocess, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(__file__))
import csi_retro as c  # noqa: E402


def commit(repo, date, msg, files, author="Dev <dev@example.org>"):
    for path, content in files.items():
        full = os.path.join(repo, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write(content)
    subprocess.run(["git", "-C", repo, "add", "-A"], check=True)
    env = dict(os.environ, GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date)
    subprocess.run(["git", "-C", repo, "-c", "user.name=x", "-c", "user.email=x@x",
                    "commit", "-q", "--author", author, "-m", msg], check=True, env=env)


class CsiRetroTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.repo = os.path.join(cls.tmp, "demo")
        os.makedirs(cls.repo)
        subprocess.run(["git", "init", "-q", cls.repo], check=True)
        r = cls.repo
        # Placeholder GitHub, 60 jours avant le vrai début : doit être ignoré.
        commit(r, "2026-01-01T10:00:00+01:00", "Initial commit", {"README.md": "x\n"})
        # Session 1 : 10:00 → 11:00 (écarts < 120 min)
        commit(r, "2026-03-02T10:00:00+01:00", "feat: socle", {
            "src/lib.rs": "fn a() {}\nfn b() {}\n",
            ".github/workflows/ci.yml": "on: push\n"})
        commit(r, "2026-03-02T11:00:00+01:00", "test: premier test\n\nCo-Authored-By: Claude <noreply@anthropic.com>",
               {"tests/a.rs": "#[test]\nfn t() {}\n"})
        # Session 2 : le lendemain, un commit de correctif
        commit(r, "2026-03-03T14:00:00+01:00", "fix: borne", {"src/lib.rs": "fn a() {}\nfn b() {}\nfn c() {}\n"})
        # Bot : exclu de tout
        commit(r, "2026-03-03T15:00:00+01:00", "chore: bump", {"Cargo.lock": "v\n"},
               author="dependabot[bot] <bot@x>")
        cls.row, cls.weeks, cls.jalons, cls.sess = c.analyse(r)

    def test_placeholder_initial_ignore(self):
        self.assertEqual(self.row["premier_commit"], "2026-03-02")

    def test_bots_exclus(self):
        self.assertEqual(self.row["commits"], 3)
        self.assertEqual(self.row["commits_bots"], 1)

    def test_part_ia(self):
        self.assertEqual(self.row["part_ia_coauteur"], 1)
        self.assertAlmostEqual(self.row["part_ia_pct"], 33.3)

    def test_sessions_et_heures(self):
        self.assertEqual(self.row["sessions"], 2)
        # 1 h + 2 × 30 min de lead [caler]
        self.assertAlmostEqual(self.row["heures_estimees"], 2.0)

    def test_commits_conventionnels(self):
        self.assertEqual((self.row["feat"], self.row["fix"], self.row["test"]), (1, 1, 1))
        self.assertEqual(self.row["ratio_fix_feat"], 1.0)

    def test_lignes_head(self):
        self.assertEqual(self.row["head_code"], 3)
        self.assertEqual(self.row["head_test"], 2)
        self.assertEqual(self.row["tests_declares"], 1)

    def test_jalons_j0(self):
        j = {x["jalon"]: x["jours_depuis_debut"] for x in self.jalons}
        self.assertEqual(j["CI"], 0)
        self.assertEqual(j["tests"], 0)

    def test_chaque_colonne_a_un_statut(self):
        sans = [k for k in self.row if k not in c.STATUT and k not in
                ("depot", "feat", "fix", "test", "docs", "refactor")]
        self.assertEqual(sans, [], f"colonnes sans étiquette mesuré/dérivé/supposé : {sans}")


if __name__ == "__main__":
    unittest.main()
