//! Adaptateur HTTP (actix-web) — seule couche qui traduit les erreurs du domaine en codes HTTP.
//! Câble les routes REST du périmètre Todo vers les use-cases. actix ne fuit pas hors d'ici.

use actix_web::{web, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPool;

use crate::adapter::{CqrsTodoRepository, RealClock, UuidGenerator};
use crate::application::{CreateTodo, DeleteTodo, Error, ListTodos, ToggleTodo};
use crate::domain::Todo;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
}

#[derive(Serialize)]
struct TodoView {
    id: String,
    title: String,
    done: bool,
    #[serde(rename = "createdAt")]
    created_at: String,
    #[serde(rename = "updatedAt")]
    updated_at: String,
}

impl From<&Todo> for TodoView {
    fn from(t: &Todo) -> Self {
        Self {
            id: t.id().to_string(),
            title: t.title().to_string(),
            done: t.done(),
            created_at: t.created_at().to_string(),
            updated_at: t.updated_at().to_string(),
        }
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateInput {
    title: String,
}

fn err_response(e: Error) -> HttpResponse {
    match e {
        Error::Validation(errors) => HttpResponse::BadRequest().json(serde_json::json!({ "errors": errors })),
        Error::NotFound(id) => {
            HttpResponse::NotFound().json(serde_json::json!({ "error": format!("Tâche introuvable : {id}.") }))
        }
        Error::Repo(_) => HttpResponse::InternalServerError().json(serde_json::json!({ "error": "Erreur interne." })),
    }
}

fn repo(state: &AppState) -> CqrsTodoRepository {
    CqrsTodoRepository::new(state.pool.clone())
}

async fn list(state: web::Data<AppState>) -> impl Responder {
    let r = repo(&state);
    match (ListTodos { repo: &r }).execute().await {
        Ok(todos) => {
            let items: Vec<TodoView> = todos.iter().map(TodoView::from).collect();
            HttpResponse::Ok().json(serde_json::json!({ "items": items }))
        }
        Err(e) => err_response(e),
    }
}

async fn create(state: web::Data<AppState>, body: web::Json<CreateInput>) -> impl Responder {
    let r = repo(&state);
    let uc = CreateTodo { repo: &r, clock: &RealClock, ids: &UuidGenerator };
    match uc.execute(&body.title).await {
        Ok(todo) => HttpResponse::Created().json(TodoView::from(&todo)),
        Err(e) => err_response(e),
    }
}

async fn toggle(state: web::Data<AppState>, id: web::Path<String>) -> impl Responder {
    let r = repo(&state);
    let uc = ToggleTodo { repo: &r, clock: &RealClock };
    match uc.execute(&id).await {
        Ok(todo) => HttpResponse::Ok().json(TodoView::from(&todo)),
        Err(e) => err_response(e),
    }
}

async fn delete(state: web::Data<AppState>, id: web::Path<String>) -> impl Responder {
    let r = repo(&state);
    match (DeleteTodo { repo: &r }).execute(&id).await {
        Ok(()) => HttpResponse::Ok().json(serde_json::json!({ "deleted": true })),
        Err(e) => err_response(e),
    }
}

/// Enregistre les routes REST du périmètre Todo.
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::resource("/api/todos")
            .route(web::get().to(list))
            .route(web::post().to(create)),
    )
    .service(
        web::resource("/api/todos/{id}")
            .route(web::patch().to(toggle))
            .route(web::delete().to(delete)),
    );
}
