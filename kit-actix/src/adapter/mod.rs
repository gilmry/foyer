//! Adaptateurs — implémentent les ports du domaine. sqlx (PostgreSQL) et chrono/uuid vivent ici,
//! jamais dans le domaine/application (gate H1). Persistance : **CQRS SQL pur** (sqlx runtime API).

use chrono::{DateTime, SecondsFormat, Utc};
use sqlx::postgres::PgPool;
use sqlx::FromRow;

use crate::domain::{Clock, IdGenerator, RepoError, Todo, TodoRepository};

/// Adaptateur de persistance alternatif : ORM sea-orm (même port `TodoRepository`).
pub mod orm;

/// Migrations embarquées et tracées (`migrate up|down|status`, ou au démarrage du serveur).
pub mod migrations;

/// Adaptateurs du port `Chiffreur` et compteurs de mesure (foyer#28).
pub mod chiffrement;
/// Persistance des fiches de personne chiffrées (foyer#28).
pub mod personne;

/// Horloge réelle — horodatage ISO-8601 (UTC).
pub struct RealClock;
impl Clock for RealClock {
    fn now(&self) -> String {
        Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true)
    }
}

/// Générateur d'UUID v4.
pub struct UuidGenerator;
impl IdGenerator for UuidGenerator {
    fn uuid(&self) -> String {
        uuid::Uuid::new_v4().to_string()
    }
}

/// Ligne SQL ↔ entité de domaine.
#[derive(FromRow)]
struct TodoRow {
    id: String,
    title: String,
    done: bool,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TodoRow {
    fn into_domain(self) -> Todo {
        // Reconstruit l'entité ; les données en base respectent déjà l'invariant.
        Todo::new(
            self.id,
            self.title,
            self.done,
            self.created_at.to_rfc3339_opts(SecondsFormat::Secs, true),
            self.updated_at.to_rfc3339_opts(SecondsFormat::Secs, true),
        )
        .expect("ligne DB invalide")
    }
}

fn parse_ts(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s).map(|d| d.with_timezone(&Utc)).unwrap_or_else(|_| Utc::now())
}

/// Adaptateur CQRS (SQL pur). Côté lecture et écriture séparés (méthodes `query_*` / `cmd_*`).
pub struct CqrsTodoRepository {
    pool: PgPool,
}

impl CqrsTodoRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    // --- Côté LECTURE (queries) ---
    async fn query_find(&self, id: &str) -> Result<Option<Todo>, RepoError> {
        let row = sqlx::query_as::<_, TodoRow>(
            "SELECT id, title, done, created_at, updated_at FROM todos WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| RepoError(e.to_string()))?;
        Ok(row.map(TodoRow::into_domain))
    }

    async fn query_all(&self) -> Result<Vec<Todo>, RepoError> {
        let rows = sqlx::query_as::<_, TodoRow>(
            "SELECT id, title, done, created_at, updated_at FROM todos ORDER BY created_at, id",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| RepoError(e.to_string()))?;
        Ok(rows.into_iter().map(TodoRow::into_domain).collect())
    }

    // --- Côté ÉCRITURE (commands) ---
    async fn cmd_save(&self, todo: &Todo) -> Result<(), RepoError> {
        sqlx::query(
            "INSERT INTO todos (id, title, done, created_at, updated_at) VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, done = EXCLUDED.done, updated_at = EXCLUDED.updated_at",
        )
        .bind(todo.id())
        .bind(todo.title())
        .bind(todo.done())
        .bind(parse_ts(todo.created_at()))
        .bind(parse_ts(todo.updated_at()))
        .execute(&self.pool)
        .await
        .map_err(|e| RepoError(e.to_string()))?;
        Ok(())
    }

    async fn cmd_delete(&self, id: &str) -> Result<(), RepoError> {
        sqlx::query("DELETE FROM todos WHERE id = $1")
            .bind(id)
            .execute(&self.pool)
            .await
            .map_err(|e| RepoError(e.to_string()))?;
        Ok(())
    }
}

impl TodoRepository for CqrsTodoRepository {
    async fn find(&self, id: &str) -> Result<Option<Todo>, RepoError> {
        self.query_find(id).await
    }
    async fn find_all(&self) -> Result<Vec<Todo>, RepoError> {
        self.query_all().await
    }
    async fn save(&self, todo: &Todo) -> Result<(), RepoError> {
        self.cmd_save(todo).await
    }
    async fn delete(&self, id: &str) -> Result<(), RepoError> {
        self.cmd_delete(id).await
    }
}

/// Adresse de la base, lue dans l'environnement : `DATABASE_URL`, ou `DB_HOST` avec `DB_PORT`,
/// `DB_NAME`, `DB_USER`, `DB_PASSWORD`. Sans l'une ni l'autre, l'erreur **nomme la variable
/// manquante** : un programme lancé par un hébergeur doit dire pourquoi il ne démarre pas, et ne
/// jamais retomber en silence sur une base par défaut.
pub fn database_url() -> Result<String, String> {
    if let Ok(url) = std::env::var("DATABASE_URL") {
        if !url.trim().is_empty() {
            return Ok(url);
        }
    }
    let host = std::env::var("DB_HOST").map_err(|_| {
        "DATABASE_URL manquante (ou, à défaut, DB_HOST avec DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)".to_string()
    })?;
    Ok(format!(
        "postgres://{u}:{pw}@{h}:{p}/{d}",
        u = std::env::var("DB_USER").unwrap_or_else(|_| "todo".into()),
        pw = std::env::var("DB_PASSWORD").unwrap_or_else(|_| "todo".into()),
        h = host,
        p = std::env::var("DB_PORT").unwrap_or_else(|_| "5432".into()),
        d = std::env::var("DB_NAME").unwrap_or_else(|_| "todo".into()),
    ))
}

/// Construit un pool PostgreSQL depuis l'environnement (voir [`database_url`]).
pub async fn connect_pool() -> Result<PgPool, sqlx::Error> {
    let url = database_url().map_err(|m| sqlx::Error::Configuration(m.into()))?;
    PgPool::connect(&url).await
}

/// Choix de l'adaptateur de persistance du serveur, par `TODO_PERSISTENCE` (`cqrs` par défaut,
/// ou `orm`). Les deux partagent le même pool de connexions.
#[derive(Clone)]
pub enum Persistance {
    Cqrs,
    Orm(sea_orm::DatabaseConnection),
}

impl Persistance {
    pub fn depuis_env(pool: &PgPool) -> Result<Self, String> {
        match std::env::var("TODO_PERSISTENCE").unwrap_or_else(|_| "cqrs".into()).to_lowercase().as_str() {
            "cqrs" | "" => Ok(Self::Cqrs),
            "orm" => Ok(Self::Orm(sea_orm::SqlxPostgresConnector::from_sqlx_postgres_pool(pool.clone()))),
            autre => Err(format!("TODO_PERSISTENCE invalide : « {autre} » (attendu : cqrs ou orm)")),
        }
    }

    pub fn nom(&self) -> &'static str {
        match self {
            Self::Cqrs => "cqrs",
            Self::Orm(_) => "orm",
        }
    }

    pub fn repo(&self, pool: &PgPool) -> RepoChoisi {
        match self {
            Self::Cqrs => RepoChoisi::Cqrs(CqrsTodoRepository::new(pool.clone())),
            Self::Orm(db) => RepoChoisi::Orm(orm::OrmTodoRepository::new(db.clone())),
        }
    }
}

/// L'adaptateur retenu, derrière le même port. Un `match` et non un `dyn` : le dispatch reste
/// statique, le domaine n'a besoin ni d'`async-trait` ni d'objet-trait.
pub enum RepoChoisi {
    Cqrs(CqrsTodoRepository),
    Orm(orm::OrmTodoRepository),
}

impl TodoRepository for RepoChoisi {
    async fn find(&self, id: &str) -> Result<Option<Todo>, RepoError> {
        match self {
            Self::Cqrs(r) => r.find(id).await,
            Self::Orm(r) => r.find(id).await,
        }
    }
    async fn find_all(&self) -> Result<Vec<Todo>, RepoError> {
        match self {
            Self::Cqrs(r) => r.find_all().await,
            Self::Orm(r) => r.find_all().await,
        }
    }
    async fn save(&self, todo: &Todo) -> Result<(), RepoError> {
        match self {
            Self::Cqrs(r) => r.save(todo).await,
            Self::Orm(r) => r.save(todo).await,
        }
    }
    async fn delete(&self, id: &str) -> Result<(), RepoError> {
        match self {
            Self::Cqrs(r) => r.delete(id).await,
            Self::Orm(r) => r.delete(id).await,
        }
    }
}
