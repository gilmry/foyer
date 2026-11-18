"""Gate `integration` — exerce les DEUX adaptateurs de persistance (CQRS SQL pur ET ORM SQLAlchemy)
contre un PostgreSQL réel, via les cas d'usage. Prouve :
  - que le login de la base est SANS PRIVILÈGE (ni superutilisateur, ni BYPASSRLS) — sinon échec ;
  - l'outil de migration (up, rejeu sans effet, somme de contrôle, down puis up) ;
  - le parcours de référence et le CLOISONNEMENT par propriétaire, sur chaque adaptateur ;
  - que la limite d'essais de connexion tient sous des requêtes SIMULTANÉES ;
  - qu'aucun mot de passe ni jeton n'est en clair en base."""
from __future__ import annotations

import shutil
import sys
import tempfile
import threading
from datetime import timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import psycopg  # noqa: E402

from app import migrate  # noqa: E402
from app.adapter.factory import persistence  # noqa: E402
from app.adapter.identity.argon2_password_hasher import Argon2PasswordHasher  # noqa: E402
from app.adapter.identity.random_token_generator import RandomTokenGenerator  # noqa: E402
from app.adapter.todo.real_clock import RealClock  # noqa: E402
from app.adapter.todo.uuid_generator import UuidGenerator  # noqa: E402
from app.application.identity.fingerprint import fingerprint  # noqa: E402
from app.application.identity.log_in import LogIn  # noqa: E402
from app.application.identity.log_out import LogOut  # noqa: E402
from app.application.identity.register_account import RegisterAccount  # noqa: E402
from app.application.identity.resolve_identity import ResolveIdentity  # noqa: E402
from app.application.todo.create_todo import CreateTodo  # noqa: E402
from app.application.todo.delete_todo import DeleteTodo  # noqa: E402
from app.application.todo.get_todo import GetTodo  # noqa: E402
from app.application.todo.list_todos import ListTodos  # noqa: E402
from app.application.todo.toggle_todo import ToggleTodo  # noqa: E402
from app.config import dsn  # noqa: E402
from app.domain.identity.exceptions import (  # noqa: E402
    EmailAlreadyUsedError, InvalidCredentialsError, TooManyAttemptsError)
from app.domain.identity.current_user import CurrentUser  # noqa: E402
from app.domain.identity.token import BEARER, SESSION  # noqa: E402
from app.domain.todo.exceptions import TodoNotFoundError  # noqa: E402
from app.domain.todo.todo import Todo  # noqa: E402

assertions = 0
failures = 0
KEY = RandomTokenGenerator().new_token()  # clé d'instance du test, tirée à chaque exécution


def check(label: str, cond: bool) -> None:
    global assertions, failures
    assertions += 1
    if cond:
        print(f"  ✓ {label}")
    else:
        failures += 1
        sys.stderr.write(f"  ✗ {label}\n")


def raises(exc_type, fn) -> bool:
    try:
        fn()
    except exc_type:
        return True
    return False


def scalar(sql: str, params: tuple = ()):
    with psycopg.connect(dsn()) as conn:
        return conn.execute(sql, params).fetchone()[0]


def login_sans_privilege() -> None:
    print("\n[login de la base]")
    with psycopg.connect(dsn()) as conn:
        user, superuser, bypass, createrole, createdb = conn.execute(
            "SELECT current_user, rolsuper, rolbypassrls, rolcreaterole, rolcreatedb "
            "FROM pg_roles WHERE rolname = current_user").fetchone()
        owner = conn.execute(
            "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database()").fetchone()[0]
    check(f"le login « {user} » n'est pas superutilisateur", superuser is False)
    check(f"le login « {user} » n'est pas dispensé de RLS (BYPASSRLS)", bypass is False)
    check(f"le login « {user} » ne crée ni rôle ni base", createrole is False and createdb is False)
    check(f"le login « {user} » est propriétaire de sa base", owner == user)
    if superuser or bypass:
        sys.stderr.write("integration: 🔴 login privilégié — le gate ne prouverait rien de la cible\n")
        sys.exit(1)


def outil_de_migration() -> None:
    print("\n[outil de migration]")
    versions = sorted(p.name[:-7] for p in migrate.MIGRATIONS_DIR.glob("*.up.sql"))
    with psycopg.connect(dsn()) as conn:
        migrate._ensure_table(conn)
        check("up applique toutes les migrations, dans l'ordre", migrate.up(conn) == versions)
        dates = conn.execute("SELECT version, applied_at FROM schema_migrations ORDER BY version").fetchall()
        check("up rejoué : rien à jouer", migrate.up(conn) == [])
        check("up rejoué : dates de passage inchangées",
              conn.execute("SELECT version, applied_at FROM schema_migrations ORDER BY version").fetchall() == dates)
        check("chaque migration est tracée avec sa somme de contrôle",
              scalar("SELECT COUNT(*) FROM schema_migrations WHERE length(checksum) = 64") == len(versions))
        check("status : tout est « passée »", all(s == "passée" for _, s in migrate.status(conn)))

        # Une migration déjà passée dont le fichier a changé : refus, sans rien toucher.
        altered = Path(tempfile.mkdtemp())
        try:
            for f in migrate.MIGRATIONS_DIR.glob("*.sql"):
                shutil.copy(f, altered / f.name)
            first = altered / f"{versions[0]}.up.sql"
            first.write_text(first.read_text() + "\n-- retouche après coup\n")
            check("up refuse si la somme d'une migration passée a changé",
                  raises(migrate.MigrationError, lambda: migrate.up(conn, altered)))
            check("down refuse aussi dans ce cas",
                  raises(migrate.MigrationError, lambda: migrate.down(conn, altered)))
        finally:
            shutil.rmtree(altered)

        # Réversibilité : down de la dernière, puis de toutes, puis up à nouveau.
        check("down annule la dernière migration", migrate.down(conn) == versions[-1])
        check("après down : la colonne propriétaire a disparu", scalar(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'todos' AND column_name = 'owner_id'") == 0)
        check("après down : la table des comptes a disparu", scalar("SELECT to_regclass('accounts') IS NULL"))
        for expected in reversed(versions[:-1]):
            check(f"down annule {expected}", migrate.down(conn) == expected)
        check("down sans migration passée : rien à annuler", migrate.down(conn) is None)
        check("up après down complet : tout est rejoué", migrate.up(conn) == versions)


def vider() -> None:
    with psycopg.connect(dsn()) as conn:
        conn.execute("DELETE FROM todos")
        conn.execute("DELETE FROM login_attempts")
        conn.execute("DELETE FROM accounts")  # emporte les jetons (ON DELETE CASCADE)


def run(kind: str) -> None:
    print(f"\n[{kind}]")
    vider()
    clock, ids, hasher, generator = RealClock(), UuidGenerator(), Argon2PasswordHasher(), RandomTokenGenerator()
    mdp_a, mdp_b = generator.new_token(), generator.new_token()  # tirés, jamais en dur

    with persistence(kind) as p:
        register = RegisterAccount(p.accounts, hasher, clock, ids)
        a = register.execute("A@exemple.test", mdp_a)
        b = register.execute("b@exemple.test", mdp_b)
        check(f"{kind}: compte créé, courriel normalisé", a.email == "a@exemple.test")
        check(f"{kind}: courriel déjà pris → refus",
              raises(EmailAlreadyUsedError, lambda: register.execute("a@exemple.test", mdp_a)))
        stored = scalar("SELECT password_hash FROM accounts WHERE id = %s", (a.id,))
        check(f"{kind}: le mot de passe est stocké en Argon2id", stored.startswith("$argon2id$"))
        check(f"{kind}: aucun mot de passe en clair dans la table des comptes",
              scalar("SELECT COUNT(*) FROM accounts WHERE accounts::text LIKE %s OR accounts::text LIKE %s",
                     (f"%{mdp_a}%", f"%{mdp_b}%")) == 0)

        def log_in(email: str, password: str, kind_: str = BEARER):
            return LogIn(p.accounts, hasher, p.tokens, p.attempts, generator, clock, ids, KEY) \
                .execute(email, password, kind_, timedelta(hours=1))

        resolve = ResolveIdentity(p.tokens, clock, KEY)
        issued = log_in("a@exemple.test", mdp_a)
        check(f"{kind}: connexion → jeton résolu en identité", resolve.execute(issued.value, BEARER) == CurrentUser(a.id))
        check(f"{kind}: un jeton porteur ne vaut pas session", resolve.execute(issued.value, SESSION) is None)
        check(f"{kind}: le jeton n'est pas en clair en base (empreinte seule)",
              scalar("SELECT COUNT(*) FROM auth_tokens WHERE token_hash = %s", (issued.value,)) == 0
              and scalar("SELECT COUNT(*) FROM auth_tokens WHERE length(token_hash) = 64") == 1)
        check(f"{kind}: mauvais mot de passe → refus",
              raises(InvalidCredentialsError, lambda: log_in("a@exemple.test", "mauvais mot de passe")))
        check(f"{kind}: compte inconnu → même refus",
              raises(InvalidCredentialsError, lambda: log_in("inconnu@exemple.test", mdp_a)))
        for _ in range(4):
            raises(InvalidCredentialsError, lambda: log_in("inconnu@exemple.test", mdp_a))
        check(f"{kind}: sixième essai échoué → limite atteinte",
              raises(TooManyAttemptsError, lambda: log_in("inconnu@exemple.test", mdp_a)))
        check(f"{kind}: les essais sont tracés par empreinte, jamais par courriel",
              scalar("SELECT COUNT(*) FROM login_attempts WHERE subject LIKE '%%@%%'") == 0)
        LogOut(p.tokens, KEY).execute(issued.value)
        check(f"{kind}: jeton révoqué → plus d'identité", resolve.execute(issued.value, BEARER) is None)

        # --- Parcours de référence, par A.
        ia, ib = CurrentUser(a.id), CurrentUser(b.id)
        todo = CreateTodo(p.todos, clock, ids).execute(ia, {"title": "acheter du pain"})
        check(f"{kind}: create persiste et relit", p.todos.find(a.id, todo.id) is not None)
        check(f"{kind}: statut initial « à faire »", p.todos.find(a.id, todo.id).done is False)
        items = ListTodos(p.todos).execute(ia)
        check(f"{kind}: list = 1 élément, bon libellé", len(items) == 1 and items[0]["title"] == "acheter du pain")
        ToggleTodo(p.todos, clock).execute(ia, todo.id)
        check(f"{kind}: toggle persisté (faite)", p.todos.find(a.id, todo.id).done is True)

        # --- Cloisonnement : B a son todo, A ne le voit ni ne le touche.
        todo_b = CreateTodo(p.todos, clock, ids).execute(ib, {"title": "todo de B"})
        check(f"{kind}: A liste son todo et pas celui de B",
              [i["id"] for i in ListTodos(p.todos).execute(ia)] == [todo.id])
        check(f"{kind}: B liste son todo et pas celui de A",
              [i["id"] for i in ListTodos(p.todos).execute(ib)] == [todo_b.id])
        check(f"{kind}: le port ne rend pas à A le todo de B", p.todos.find(a.id, todo_b.id) is None)
        for name, attempt in (
            ("lire", lambda: GetTodo(p.todos).execute(ia, todo_b.id)),
            ("basculer", lambda: ToggleTodo(p.todos, clock).execute(ia, todo_b.id)),
            ("supprimer", lambda: DeleteTodo(p.todos).execute(ia, todo_b.id)),
        ):
            check(f"{kind}: A ne peut pas {name} le todo de B (introuvable)", raises(TodoNotFoundError, attempt))
        p.todos.delete(a.id, todo_b.id)  # appel direct du port, sans cas d'usage
        check(f"{kind}: delete du port avec le mauvais propriétaire ne supprime rien",
              p.todos.find(b.id, todo_b.id) is not None)
        # Écriture directe d'un todo de même identifiant par A : ni modifié, ni réattribué.
        p.todos.save(a.id, Todo(todo_b.id, a.id, "détourné", True, todo_b.created_at, todo_b.updated_at))
        relu = p.todos.find(b.id, todo_b.id)
        check(f"{kind}: save du port ne détourne pas le todo d'autrui",
              relu is not None and relu.title == "todo de B" and relu.done is False
              and p.todos.find(a.id, todo_b.id) is None)
        check(f"{kind}: save refuse un todo dont le propriétaire n'est pas l'appelant",
              raises(ValueError, lambda: p.todos.save(a.id, todo_b)))
        check(f"{kind}: en base, chaque todo a son propriétaire",
              scalar("SELECT COUNT(*) FROM todos WHERE owner_id IS NULL") == 0
              and scalar("SELECT owner_id FROM todos WHERE id = %s", (todo_b.id,)) == b.id)

    essais_simultanes(kind, "b@exemple.test", mdp_b)

    # Nouvelle connexion/session : l'état survit.
    with persistence(kind) as p2:
        found = p2.todos.find_all(a.id)
        check(f"{kind}: persistance inter-connexion", len(found) == 1 and found[0].done is True)
        DeleteTodo(p2.todos).execute(CurrentUser(a.id), found[0].id)
        check(f"{kind}: delete → liste de A vide, todo de B intact",
              ListTodos(p2.todos).execute(CurrentUser(a.id)) == [] and len(p2.todos.find_all(b.id)) == 1)


def essais_simultanes(kind: str, email: str, bon_mdp: str) -> None:
    """Douze connexions fausses lancées ENSEMBLE sur le même courriel, chacune sur sa connexion :
    cinq au plus atteignent la vérification du mot de passe. Compter puis enregistrer après le
    hachage les laisserait toutes passer (chacune lirait un compteur à zéro)."""
    n = 12
    depart = threading.Barrier(n)
    verdicts: list[str] = []
    clock, ids, hasher, generator = RealClock(), UuidGenerator(), Argon2PasswordHasher(), RandomTokenGenerator()

    def essai() -> None:
        with persistence(kind) as p:
            use_case = LogIn(p.accounts, hasher, p.tokens, p.attempts, generator, clock, ids, KEY)
            depart.wait()
            try:
                use_case.execute(email, "mauvais mot de passe", BEARER, timedelta(hours=1))
                verdicts.append("accepté")
            except InvalidCredentialsError:
                verdicts.append("vérifié")
            except TooManyAttemptsError:
                verdicts.append("limité")
            except Exception as exc:  # noqa: BLE001
                verdicts.append(f"erreur {type(exc).__name__}")

    fils = [threading.Thread(target=essai) for _ in range(n)]
    for f in fils:
        f.start()
    for f in fils:
        f.join()
    verifies, limites = verdicts.count("vérifié"), verdicts.count("limité")
    check(f"{kind}: {n} essais simultanés → tous traités, aucune erreur ({verifies} vérifiés, {limites} limités)",
          verifies + limites == n)
    check(f"{kind}: essais simultanés → exactement cinq vérifications de mot de passe, sept refus", verifies == 5 and limites == 7)
    check(f"{kind}: essais simultanés → seuls les essais vérifiés restent comptés",
          scalar("SELECT COUNT(*) FROM login_attempts WHERE subject = %s",
                 (fingerprint(KEY, "essai:" + email),)) == verifies)
    with persistence(kind) as p:
        use_case = LogIn(p.accounts, hasher, p.tokens, p.attempts, generator, clock, ids, KEY)
        for _ in range(5 - verifies):  # compléter jusqu'au seuil, en série
            raises(InvalidCredentialsError, lambda: use_case.execute(email, "mauvais mot de passe", BEARER, timedelta(hours=1)))
        check(f"{kind}: seuil atteint → le bon mot de passe est refusé lui aussi",
              raises(TooManyAttemptsError, lambda: use_case.execute(email, bon_mdp, BEARER, timedelta(hours=1))))


def interchangeabilite() -> None:
    """Ce qu'un adaptateur écrit, l'autre le lit : même schéma, mêmes ports."""
    print("\n[cqrs ↔ orm]")
    vider()
    clock, ids = RealClock(), UuidGenerator()
    with persistence("cqrs") as p:
        account = RegisterAccount(p.accounts, Argon2PasswordHasher(), clock, ids) \
            .execute("c@exemple.test", RandomTokenGenerator().new_token())
        todo = CreateTodo(p.todos, clock, ids).execute(CurrentUser(account.id), {"title": "écrit par cqrs"})
    with persistence("orm") as p:
        check("orm relit le compte et le todo écrits par cqrs",
              p.accounts.find_by_email("c@exemple.test") is not None
              and [t.id for t in p.todos.find_all(account.id)] == [todo.id])
        ToggleTodo(p.todos, clock).execute(CurrentUser(account.id), todo.id)
    with persistence("cqrs") as p:
        check("cqrs relit la bascule faite par orm", p.todos.find(account.id, todo.id).done is True)
    vider()


login_sans_privilege()
outil_de_migration()
run("cqrs")
run("orm")
interchangeabilite()

print(f"\nintegration: {'🟢' if failures == 0 else '🔴'} ({assertions} assertions, {failures} échecs)")
sys.exit(1 if failures else 0)
