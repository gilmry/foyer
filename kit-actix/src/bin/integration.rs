//! Gate `integration` — exerce les DEUX adaptateurs de persistance (CQRS sqlx ET ORM sea-orm)
//! contre PostgreSQL réel, via les use-cases. Prouve l'interchangeabilité du port TodoRepository.
use todo::adapter::orm::{connect as orm_connect, OrmTodoRepository};
use todo::adapter::{connect_pool, migrations, CqrsTodoRepository, RealClock, UuidGenerator};
use todo::application::{CreateTodo, DeleteTodo, ListTodos, ToggleTodo};
use todo::domain::TodoRepository;

/// Schéma propre par l'outil de migration lui-même : tout annuler (`down`), tout rejouer (`up`).
/// Le gate prouve donc aussi que chaque migration est réversible et tracée.
async fn reset_schema() {
    let pool = connect_pool().await.expect("connexion PostgreSQL");
    migrations::reset(&pool).await.expect("migrations");
}

/// Le gate se joue avec le login de la cible : un hébergeur infogéré ne donne ni superutilisateur
/// ni dispense de RLS. Un test qui ne passe qu'avec ces privilèges cache un défaut.
async fn login_sans_privilege() -> u32 {
    let pool = connect_pool().await.expect("connexion PostgreSQL");
    let (nom, privilegie): (String, bool) = sqlx::query_as(
        "SELECT current_user::text, (rolsuper OR rolbypassrls OR rolcreaterole) FROM pg_roles WHERE rolname = current_user",
    )
    .fetch_one(&pool)
    .await
    .expect("lecture du rôle courant");
    if privilegie {
        eprintln!("  ✗ login « {nom} » privilégié (superutilisateur, BYPASSRLS ou CREATEROLE) : le gate se joue sans privilège");
        1
    } else {
        println!("  ✓ login « {nom} » sans privilège (ni superutilisateur, ni BYPASSRLS, ni CREATEROLE)");
        0
    }
}

/// Déroule le parcours de référence sur un adaptateur quelconque du port.
async fn run<R: TodoRepository>(kind: &str, repo: R, second: R) -> u32 {
    let mut failures = 0u32;
    let mut check = |label: &str, cond: bool| {
        if cond {
            println!("  ✓ {kind}: {label}");
        } else {
            failures += 1;
            eprintln!("  ✗ {kind}: {label}");
        }
    };

    let clock = RealClock;
    let ids = UuidGenerator;
    let todo = CreateTodo { repo: &repo, clock: &clock, ids: &ids }
        .execute("acheter du pain")
        .await
        .unwrap();
    check("create persiste et relit", repo.find(todo.id()).await.unwrap().is_some());
    check("statut initial « à faire »", !repo.find(todo.id()).await.unwrap().unwrap().done());
    let items = ListTodos { repo: &repo }.execute().await.unwrap();
    check("list = 1 élément, bon libellé", items.len() == 1 && items[0].title() == "acheter du pain");
    ToggleTodo { repo: &repo, clock: &clock }.execute(todo.id()).await.unwrap();
    check("toggle persisté (faite)", repo.find(todo.id()).await.unwrap().unwrap().done());

    // Seconde instance (nouvelle connexion) : l'état survit.
    let found = second.find_all().await.unwrap();
    check("persistance inter-connexion", found.len() == 1 && found[0].done());
    DeleteTodo { repo: &second }.execute(found[0].id()).await.unwrap();
    check("delete → liste vide", ListTodos { repo: &second }.execute().await.unwrap().is_empty());

    failures
}

#[tokio::main]
async fn main() {
    let mut failures = 0u32;

    println!("\n[login]");
    failures += login_sans_privilege().await;

    println!("\n[cqrs]");
    reset_schema().await;
    let a = CqrsTodoRepository::new(connect_pool().await.unwrap());
    let b = CqrsTodoRepository::new(connect_pool().await.unwrap());
    failures += run("cqrs", a, b).await;

    println!("\n[orm]");
    reset_schema().await;
    let a = OrmTodoRepository::new(orm_connect().await.unwrap());
    let b = OrmTodoRepository::new(orm_connect().await.unwrap());
    failures += run("orm", a, b).await;

    println!("\nintegration: {} ({} échecs)", if failures == 0 { "🟢" } else { "🔴" }, failures);
    std::process::exit(if failures == 0 { 0 } else { 1 });
}
