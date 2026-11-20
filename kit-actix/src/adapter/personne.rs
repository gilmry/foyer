//! Persistance des fiches de personne chiffrées (mesure foyer#28), en SQL pur (sqlx). La table
//! `personnes` ne reçoit que des octets : champs chiffrés et clé de données enveloppée.

use sqlx::postgres::PgPool;
use sqlx::FromRow;

use crate::domain::chiffrement::CleEnveloppee;
use crate::domain::personne::{FicheChiffree, PersonneRepository};
use crate::domain::RepoError;

#[derive(FromRow)]
struct FicheRow {
    id: String,
    cle_enveloppee: Vec<u8>,
    nom: Vec<u8>,
    courriel: Vec<u8>,
    telephone: Vec<u8>,
}

pub struct CqrsPersonneRepository {
    pool: PgPool,
}

impl CqrsPersonneRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

impl PersonneRepository for CqrsPersonneRepository {
    async fn trouver(&self, id: &str) -> Result<Option<FicheChiffree>, RepoError> {
        let row = sqlx::query_as::<_, FicheRow>(
            "SELECT id, cle_enveloppee, nom, courriel, telephone FROM personnes WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| RepoError(e.to_string()))?;
        Ok(row.map(|r| FicheChiffree {
            id: r.id,
            cle: CleEnveloppee(r.cle_enveloppee),
            nom: r.nom,
            courriel: r.courriel,
            telephone: r.telephone,
        }))
    }

    async fn enregistrer(&self, fiche: &FicheChiffree) -> Result<(), RepoError> {
        sqlx::query(
            "INSERT INTO personnes (id, cle_enveloppee, nom, courriel, telephone) VALUES ($1, $2, $3, $4, $5)",
        )
        .bind(&fiche.id)
        .bind(&fiche.cle.0)
        .bind(&fiche.nom)
        .bind(&fiche.courriel)
        .bind(&fiche.telephone)
        .execute(&self.pool)
        .await
        .map_err(|e| RepoError(e.to_string()))?;
        Ok(())
    }
}
