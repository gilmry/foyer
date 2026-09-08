//! Tests de la couche Application avec un fake in-memory (aucune DB). Le fake est un adaptateur
//! de test, donc hors du domaine/application purs.
use std::collections::HashMap;
use std::sync::Mutex;

use todo::application::{CreateTodo, DeleteTodo, Error, ToggleTodo};
use todo::domain::{Clock, IdGenerator, RepoError, Todo, TodoRepository};

struct FakeRepo {
    store: Mutex<HashMap<String, Todo>>,
}
impl FakeRepo {
    fn new() -> Self {
        Self { store: Mutex::new(HashMap::new()) }
    }
}
impl TodoRepository for FakeRepo {
    async fn find(&self, id: &str) -> Result<Option<Todo>, RepoError> {
        Ok(self.store.lock().unwrap().get(id).cloned())
    }
    async fn find_all(&self) -> Result<Vec<Todo>, RepoError> {
        let mut v: Vec<Todo> = self.store.lock().unwrap().values().cloned().collect();
        v.sort_by(|a, b| a.created_at().cmp(b.created_at()));
        Ok(v)
    }
    async fn save(&self, todo: &Todo) -> Result<(), RepoError> {
        self.store.lock().unwrap().insert(todo.id().to_string(), todo.clone());
        Ok(())
    }
    async fn delete(&self, id: &str) -> Result<(), RepoError> {
        self.store.lock().unwrap().remove(id);
        Ok(())
    }
}

struct FakeClock;
impl Clock for FakeClock {
    fn now(&self) -> String {
        "2026-01-01T00:00:00+00:00".to_string()
    }
}
struct SeqIds {
    n: Mutex<u32>,
}
impl IdGenerator for SeqIds {
    fn uuid(&self) -> String {
        let mut n = self.n.lock().unwrap();
        *n += 1;
        format!("gen-{n}")
    }
}

#[tokio::test] // @happy
async fn create_persists_open_todo() {
    let repo = FakeRepo::new();
    let ids = SeqIds { n: Mutex::new(0) };
    let todo = CreateTodo { repo: &repo, clock: &FakeClock, ids: &ids }
        .execute("  acheter du pain  ")
        .await
        .unwrap();
    assert_eq!(todo.id(), "gen-1");
    assert_eq!(todo.title(), "acheter du pain");
    assert!(!todo.done());
    assert!(repo.find("gen-1").await.unwrap().is_some());
}

#[tokio::test] // @negative
async fn create_empty_title_errors_and_persists_nothing() {
    let repo = FakeRepo::new();
    let ids = SeqIds { n: Mutex::new(0) };
    let res = CreateTodo { repo: &repo, clock: &FakeClock, ids: &ids }.execute("").await;
    assert!(matches!(res, Err(Error::Validation(_))));
    assert!(repo.find_all().await.unwrap().is_empty());
}

#[tokio::test] // @happy — toggle + persistance
async fn toggle_flips_and_persists() {
    let repo = FakeRepo::new();
    let ids = SeqIds { n: Mutex::new(0) };
    let id = CreateTodo { repo: &repo, clock: &FakeClock, ids: &ids }.execute("tâche").await.unwrap().id().to_string();
    assert!(ToggleTodo { repo: &repo, clock: &FakeClock }.execute(&id).await.unwrap().done());
    assert!(!ToggleTodo { repo: &repo, clock: &FakeClock }.execute(&id).await.unwrap().done());
}

#[tokio::test] // @negative — id inconnu
async fn toggle_unknown_errors() {
    let repo = FakeRepo::new();
    assert!(matches!(
        ToggleTodo { repo: &repo, clock: &FakeClock }.execute("inconnu").await,
        Err(Error::NotFound(_))
    ));
}

#[tokio::test] // @happy — delete
async fn delete_removes_todo() {
    let repo = FakeRepo::new();
    let ids = SeqIds { n: Mutex::new(0) };
    let id = CreateTodo { repo: &repo, clock: &FakeClock, ids: &ids }.execute("tâche").await.unwrap().id().to_string();
    DeleteTodo { repo: &repo }.execute(&id).await.unwrap();
    assert!(repo.find(&id).await.unwrap().is_none());
}

#[tokio::test] // @negative
async fn delete_unknown_errors() {
    let repo = FakeRepo::new();
    assert!(matches!(DeleteTodo { repo: &repo }.execute("inconnu").await, Err(Error::NotFound(_))));
}
