//! Binaire serveur — assemble l'app actix (routes API + front statique) et le pool PostgreSQL.
//! `CHIFFREMENT=clair|local|openbao|openbao-cache` monte en plus le module de mesure (foyer#28).
use std::sync::Arc;

use actix_web::{web, App, HttpServer};
use todo::adapter::chiffrement::{ChiffreurChoisi, Compteurs};
use todo::adapter::connect_pool;
use todo::http::mesure::{self, Mesure};
use todo::http::{configure, AppState};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let pool = connect_pool().await.expect("connexion PostgreSQL");
    let compteurs = Arc::new(Compteurs::default());
    let mesure = ChiffreurChoisi::depuis_env(compteurs.clone())
        .unwrap_or_else(|e| panic!("configuration du chiffrement : {e}"))
        .map(|chiffreur| Arc::new(Mesure { chiffreur, compteurs }));
    let state = AppState { pool, mesure };
    let host = std::env::var("HTTP_HOST").unwrap_or_else(|_| "127.0.0.1".into());
    let port: u16 = std::env::var("HTTP_PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(8080);

    HttpServer::new(move || {
        let avec_mesure = state.mesure.is_some();
        App::new()
            .app_data(web::Data::new(state.clone()))
            .configure(configure)
            .configure(|cfg| {
                if avec_mesure {
                    mesure::configure(cfg);
                }
            })
            // Front statique (îlot + client généré) — monté après les routes /api.
            .service(actix_files::Files::new("/", "./public").index_file("index.html"))
    })
    .bind((host, port))?
    .run()
    .await
}
