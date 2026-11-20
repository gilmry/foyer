//! Migrations du schéma — embarquées dans le binaire à la compilation, appliquées dans l'ordre et
//! **tracées** (table `_sqlx_migrations` : version, somme de contrôle, date). Une migration déjà
//! passée n'est jamais rejouée ; si son fichier a changé depuis, l'outil refuse de continuer.
//! Les fichiers restent `database/migrations/pending/NNNN_nom.up.sql` et `.down.sql` (gate G2).
use sqlx::migrate::{MigrateError, Migrator};
use sqlx::postgres::PgPool;

pub static MIGRATOR: Migrator = sqlx::migrate!("./database/migrations/pending");

/// Versions déjà appliquées, de la plus ancienne à la plus récente (vide si rien n'a été joué).
pub async fn appliquees(pool: &PgPool) -> Result<Vec<i64>, sqlx::Error> {
    let table: Option<String> = sqlx::query_scalar("SELECT to_regclass('_sqlx_migrations')::text").fetch_one(pool).await?;
    if table.is_none() {
        return Ok(Vec::new());
    }
    sqlx::query_scalar("SELECT version FROM _sqlx_migrations WHERE success ORDER BY version").fetch_all(pool).await
}

/// Applique les migrations manquantes ; rend le nombre de migrations jouées à cet appel.
pub async fn up(pool: &PgPool) -> Result<usize, MigrateError> {
    let avant = appliquees(pool).await?.len();
    MIGRATOR.run(pool).await?;
    Ok(appliquees(pool).await?.len() - avant)
}

/// Annule la dernière migration appliquée ; rend sa version, ou `None` s'il n'y en avait aucune.
pub async fn down(pool: &PgPool) -> Result<Option<i64>, MigrateError> {
    let faites = appliquees(pool).await?;
    let Some(derniere) = faites.last().copied() else { return Ok(None) };
    let cible = if faites.len() >= 2 { faites[faites.len() - 2] } else { 0 };
    MIGRATOR.undo(pool, cible).await?;
    Ok(Some(derniere))
}

/// Annule tout, puis réapplique tout : schéma propre pour un gate. Jamais en production.
pub async fn reset(pool: &PgPool) -> Result<(), MigrateError> {
    MIGRATOR.undo(pool, 0).await?;
    MIGRATOR.run(pool).await
}

/// État de chaque migration connue du binaire : (version, description, appliquée ?).
pub async fn status(pool: &PgPool) -> Result<Vec<(i64, String, bool)>, sqlx::Error> {
    let faites = appliquees(pool).await?;
    Ok(MIGRATOR
        .iter()
        .filter(|m| !m.migration_type.is_down_migration())
        .map(|m| (m.version, m.description.to_string(), faites.contains(&m.version)))
        .collect())
}
