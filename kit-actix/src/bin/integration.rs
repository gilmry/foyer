//! Gate `integration` — exerce les DEUX adaptateurs de persistance (CQRS sqlx ET ORM sea-orm)
//! contre PostgreSQL réel, via les use-cases. Prouve l'interchangeabilité du port TodoRepository.
use todo::adapter::orm::{connect as orm_connect, OrmTodoRepository};
use todo::adapter::{connect_pool, CqrsTodoRepository, RealClock, UuidGenerator};
use todo::application::{CreateTodo, DeleteTodo, ListTodos, ToggleTodo};
use todo::domain::TodoRepository;

async fn exec_sql(pool: &sqlx::PgPool, sql: &str) {
    for stmt in sql.split(';') {
        let s = stmt.trim();
        if !s.is_empty() {
            sqlx::query(s).execute(pool).await.expect("exec sql");
        }
    }
}

async fn reset_schema() {
    let pool = connect_pool().await.expect("connexion PostgreSQL");
    exec_sql(&pool, "DROP TABLE IF EXISTS todos").await;
    let up = std::fs::read_to_string("database/migrations/pending/0001_create_todos.up.sql").unwrap();
    exec_sql(&pool, &up).await;
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
