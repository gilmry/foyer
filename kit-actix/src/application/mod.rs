//! Use-cases — orchestration, **Rust pur** (dépend uniquement du domaine). Génériques sur le port
//! `TodoRepository` (dispatch statique) → aucune fuite d'infra. Tests dans `tests/application.rs`.

use crate::domain::{normalize_title, Clock, IdGenerator, Todo, TodoError, TodoRepository};

/// Erreur de use-case — sépare validation (400), introuvable (404) et infra (500).
#[derive(Debug)]
pub enum Error {
    Validation(Vec<String>),
    NotFound(String),
    Repo(String),
}

impl From<TodoError> for Error {
    fn from(e: TodoError) -> Self {
        match e {
            TodoError::Validation(v) => Error::Validation(v),
            TodoError::NotFound(id) => Error::NotFound(id),
        }
    }
}

impl From<crate::domain::RepoError> for Error {
    fn from(e: crate::domain::RepoError) -> Self {
        Error::Repo(e.0)
    }
}

pub struct CreateTodo<'a, R: TodoRepository> {
    pub repo: &'a R,
    pub clock: &'a dyn Clock,
    pub ids: &'a dyn IdGenerator,
}

impl<'a, R: TodoRepository> CreateTodo<'a, R> {
    pub async fn execute(&self, title: &str) -> Result<Todo, Error> {
        let now = self.clock.now();
        let todo = Todo::new(self.ids.uuid(), normalize_title(title), false, now.clone(), now)?;
        self.repo.save(&todo).await?;
        Ok(todo)
    }
}

pub struct ListTodos<'a, R: TodoRepository> {
    pub repo: &'a R,
}

impl<'a, R: TodoRepository> ListTodos<'a, R> {
    pub async fn execute(&self) -> Result<Vec<Todo>, Error> {
        Ok(self.repo.find_all().await?)
    }
}

pub struct ToggleTodo<'a, R: TodoRepository> {
    pub repo: &'a R,
    pub clock: &'a dyn Clock,
}

impl<'a, R: TodoRepository> ToggleTodo<'a, R> {
    pub async fn execute(&self, id: &str) -> Result<Todo, Error> {
        let todo = self.repo.find(id).await?.ok_or_else(|| Error::NotFound(id.to_string()))?;
        let toggled = todo.toggled(self.clock.now());
        self.repo.save(&toggled).await?;
        Ok(toggled)
    }
}

pub struct DeleteTodo<'a, R: TodoRepository> {
    pub repo: &'a R,
}

impl<'a, R: TodoRepository> DeleteTodo<'a, R> {
    pub async fn execute(&self, id: &str) -> Result<(), Error> {
        if self.repo.find(id).await?.is_none() {
            return Err(Error::NotFound(id.to_string()));
        }
        self.repo.delete(id).await?;
        Ok(())
    }
}
