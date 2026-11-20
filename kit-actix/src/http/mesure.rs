//! Routes du module de mesure (foyer#28) : écrire et relire une fiche de personne chiffrée selon
//! la variante choisie au démarrage, et relever les compteurs. Hors du contrat OpenAPI du gabarit.

use std::sync::Arc;

use actix_web::{web, HttpResponse, Responder};
use serde::{Deserialize, Serialize};

use super::{err_response, AppState};
use crate::adapter::chiffrement::{ressources_processus, ChiffreurChoisi, Compteurs};
use crate::adapter::personne::CqrsPersonneRepository;
use crate::adapter::UuidGenerator;
use crate::application::personne::{EcrirePersonne, LirePersonne, SaisiePersonne};
use crate::domain::chiffrement::Chiffreur;
use crate::domain::personne::Personne;

pub struct Mesure {
    pub chiffreur: ChiffreurChoisi,
    pub compteurs: Arc<Compteurs>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct PersonneInput {
    nom: String,
    courriel: String,
    #[serde(default)]
    telephone: String,
}

#[derive(Serialize)]
struct PersonneView<'p> {
    id: &'p str,
    nom: &'p str,
    courriel: &'p str,
    telephone: &'p str,
}

impl<'p> From<&'p Personne> for PersonneView<'p> {
    fn from(p: &'p Personne) -> Self {
        Self { id: p.id(), nom: p.nom(), courriel: p.courriel(), telephone: p.telephone() }
    }
}

fn mesure(state: &AppState) -> &Mesure {
    state.mesure.as_deref().expect("routes de mesure montées sans module de mesure")
}

async fn ecrire(state: web::Data<AppState>, body: web::Json<PersonneInput>) -> impl Responder {
    let m = mesure(&state);
    let repo = CqrsPersonneRepository::new(state.pool.clone());
    let uc = EcrirePersonne { repo: &repo, chiffreur: &m.chiffreur, ids: &UuidGenerator };
    let saisie = SaisiePersonne { nom: &body.nom, courriel: &body.courriel, telephone: &body.telephone };
    match uc.execute(saisie).await {
        Ok(p) => HttpResponse::Created().json(PersonneView::from(&p)),
        Err(e) => err_response(e),
    }
}

async fn relire(state: web::Data<AppState>, id: web::Path<String>) -> impl Responder {
    let m = mesure(&state);
    let repo = CqrsPersonneRepository::new(state.pool.clone());
    match (LirePersonne { repo: &repo, chiffreur: &m.chiffreur }).execute(&id).await {
        Ok(p) => HttpResponse::Ok().json(PersonneView::from(&p)),
        Err(e) => err_response(e),
    }
}

async fn compteurs(state: web::Data<AppState>) -> impl Responder {
    let m = mesure(&state);
    HttpResponse::Ok().json(serde_json::json!({
        "variante": m.chiffreur.variante(),
        "compteurs": m.compteurs.releve(),
        "processus": ressources_processus(),
    }))
}

/// Enregistre les routes du module de mesure.
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(web::resource("/api/personnes").route(web::post().to(ecrire)))
        .service(web::resource("/api/personnes/{id}").route(web::get().to(relire)))
        .service(web::resource("/api/mesure/compteurs").route(web::get().to(compteurs)));
}
