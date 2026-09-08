//! Adaptateur de persistance ALTERNATIF : ORM **sea-orm**. Même port `TodoRepository` que
//! l'adaptateur CQRS (sqlx). sea-orm ne fuit jamais hors de cet adaptateur : on mappe l'entité
//! de persistance `todo_entity::Model` ↔ l'entité de domaine `Todo`.

use chrono::{DateTime, SecondsFormat, Utc};
use sea_orm::sea_query::OnConflict;
use sea_orm::{ActiveValue::Set, Database, DatabaseConnection, EntityTrait, QueryOrder};

use crate::domain::{RepoError, Todo, TodoRepository};

/// Entité de persistance sea-orm (table `todos`). Vit dans l'adaptateur, pas dans le domaine.
mod todo_entity {
    use sea_orm::entity::prelude::*;

    #[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
    #[sea_orm(table_name = "todos")]
    pub struct Model {
        #[sea_orm(primary_key, auto_increment = false)]
        pub id: String,
        pub title: String,
        pub done: bool,
        pub created_at: DateTimeUtc,
        pub updated_at: DateTimeUtc,
    }

    #[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
    pub enum Relation {}

    impl ActiveModelBehavior for ActiveModel {}
}

use todo_entity::{ActiveModel, Column, Entity, Model};

fn parse_ts(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s).map(|d| d.with_timezone(&Utc)).unwrap_or_else(|_| Utc::now())
}

fn to_domain(m: Model) -> Todo {
    Todo::new(
        m.id,
        m.title,
        m.done,
        m.created_at.to_rfc3339_opts(SecondsFormat::Secs, true),
        m.updated_at.to_rfc3339_opts(SecondsFormat::Secs, true),
    )
    .expect("ligne DB invalide")
}

/// Connexion sea-orm depuis l'environnement (mêmes variables que l'adaptateur CQRS).
pub async fn connect() -> Result<DatabaseConnection, sea_orm::DbErr> {
    let url = std::env::var("DATABASE_URL").unwrap_or_else(|_| {
        format!(
            "postgres://{u}:{pw}@{h}:{p}/{d}",
            u = std::env::var("DB_USER").unwrap_or_else(|_| "todo".into()),
            pw = std::env::var("DB_PASSWORD").unwrap_or_else(|_| "todo".into()),
            h = std::env::var("DB_HOST").unwrap_or_else(|_| "localhost".into()),
            p = std::env::var("DB_PORT").unwrap_or_else(|_| "5432".into()),
            d = std::env::var("DB_NAME").unwrap_or_else(|_| "todo".into()),
        )
    });
    Database::connect(url).await
}

pub struct OrmTodoRepository {
    db: DatabaseConnection,
}

impl OrmTodoRepository {
    pub fn new(db: DatabaseConnection) -> Self {
        Self { db }
    }
}

impl TodoRepository for OrmTodoRepository {
    async fn find(&self, id: &str) -> Result<Option<Todo>, RepoError> {
        let m = Entity::find_by_id(id.to_string())
            .one(&self.db)
            .await
            .map_err(|e| RepoError(e.to_string()))?;
        Ok(m.map(to_domain))
    }

    async fn find_all(&self) -> Result<Vec<Todo>, RepoError> {
        let ms = Entity::find()
            .order_by_asc(Column::CreatedAt)
            .order_by_asc(Column::Id)
            .all(&self.db)
            .await
            .map_err(|e| RepoError(e.to_string()))?;
        Ok(ms.into_iter().map(to_domain).collect())
    }

    async fn save(&self, todo: &Todo) -> Result<(), RepoError> {
        let am = ActiveModel {
            id: Set(todo.id().to_string()),
            title: Set(todo.title().to_string()),
            done: Set(todo.done()),
            created_at: Set(parse_ts(todo.created_at())),
            updated_at: Set(parse_ts(todo.updated_at())),
        };
        Entity::insert(am)
            .on_conflict(
                OnConflict::column(Column::Id)
                    .update_columns([Column::Title, Column::Done, Column::UpdatedAt])
                    .to_owned(),
            )
            .exec(&self.db)
            .await
            .map_err(|e| RepoError(e.to_string()))?;
        Ok(())
    }

    async fn delete(&self, id: &str) -> Result<(), RepoError> {
        Entity::delete_by_id(id.to_string())
            .exec(&self.db)
            .await
            .map_err(|e| RepoError(e.to_string()))?;
        Ok(())
    }
}
