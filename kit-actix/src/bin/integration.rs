//! Gate `integration` — exerce le vrai CqrsTodoRepository (sqlx) + les use-cases contre PostgreSQL.
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

#[tokio::main]
async fn main() {
    let pool = connect_pool().await.expect("connexion PostgreSQL");

    // Migration up (schéma propre).
    exec_sql(&pool, "DROP TABLE IF EXISTS todos").await;
    let up = std::fs::read_to_string("database/migrations/pending/0001_create_todos.up.sql").unwrap();
    exec_sql(&pool, &up).await;

    let mut assertions = 0u32;
    let mut failures = 0u32;
    let mut check = |label: &str, cond: bool| {
        assertions += 1;
        if cond {
            println!("  ✓ {label}");
        } else {
            failures += 1;
            eprintln!("  ✗ {label}");
        }
    };

    let repo = CqrsTodoRepository::new(pool.clone());

    println!("\n[cqrs]");
    let todo = CreateTodo { repo: &repo, clock: &RealClock, ids: &UuidGenerator }
        .execute("acheter du pain")
        .await
        .unwrap();
    check("cqrs: create persiste et relit", repo.find(todo.id()).await.unwrap().is_some());
    check("cqrs: statut initial « à faire »", !repo.find(todo.id()).await.unwrap().unwrap().done());
    let items = ListTodos { repo: &repo }.execute().await.unwrap();
    check("cqrs: list = 1 élément, bon libellé", items.len() == 1 && items[0].title() == "acheter du pain");
    ToggleTodo { repo: &repo, clock: &RealClock }.execute(todo.id()).await.unwrap();
    check("cqrs: toggle persisté (faite)", repo.find(todo.id()).await.unwrap().unwrap().done());

    // Nouveau pool/instance : l'état survit.
    let pool2 = connect_pool().await.unwrap();
    let repo2 = CqrsTodoRepository::new(pool2);
    let found = repo2.find_all().await.unwrap();
    check("cqrs: persistance inter-connexion", found.len() == 1 && found[0].done());
    DeleteTodo { repo: &repo2 }.execute(found[0].id()).await.unwrap();
    check("cqrs: delete → liste vide", ListTodos { repo: &repo2 }.execute().await.unwrap().is_empty());

    println!("\nintegration: {} ({} assertions, {} échecs)", if failures == 0 { "🟢" } else { "🔴" }, assertions, failures);
    std::process::exit(if failures == 0 { 0 } else { 1 });
}
