//! Binaire serveur — assemble l'app actix (routes API + front statique) et le pool PostgreSQL.
//! `CHIFFREMENT=clair|local|openbao|openbao-cache` monte en plus le module de mesure (foyer#28).
//!
//! Configuration, toute par l'environnement :
//! - `DATABASE_URL` (ou `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) — obligatoire ;
//! - `HTTP_HOST`, `HTTP_PORT` — adresse d'écoute (IPv4 ou IPv6), `127.0.0.1:8080` par défaut ;
//! - `TODO_PERSISTENCE` — `cqrs` (défaut) ou `orm` ;
//! - `PUBLIC_DIR` — dossier du front statique, `./public` par défaut ;
//! - `TODO_MIGRER=1` — applique les migrations manquantes avant d'écouter (posé par le lanceur au
//!   seul démarrage qui suit un déploiement).
use std::sync::Arc;

use actix_web::{web, App, HttpServer};
use todo::adapter::chiffrement::{ChiffreurChoisi, Compteurs};
use todo::adapter::{connect_pool, migrations, Persistance};
use todo::http::mesure::{self, Mesure};
use todo::http::{configure, en_tetes_securite, AppState};

/// Refus de démarrer : un message d'une ligne qui nomme la cause, jamais la valeur d'un secret,
/// et le code de sortie « erreur de configuration » (78).
fn refus(message: impl std::fmt::Display) -> ! {
    eprintln!("démarrage refusé : {message}");
    std::process::exit(78);
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let pool = connect_pool().await.unwrap_or_else(|e| refus(e));
    if std::env::var("TODO_MIGRER").as_deref() == Ok("1") {
        match migrations::up(&pool).await {
            Ok(n) => eprintln!("migrations : {n} appliquée(s)"),
            Err(e) => refus(format!("migrations : {e}")),
        }
    }
    let persistance = Persistance::depuis_env(&pool).unwrap_or_else(|e| refus(e));
    let compteurs = Arc::new(Compteurs::default());
    let mesure = ChiffreurChoisi::depuis_env(compteurs.clone())
        .unwrap_or_else(|e| refus(format!("configuration du chiffrement : {e}")))
        .map(|chiffreur| Arc::new(Mesure { chiffreur, compteurs }));
    let host = std::env::var("HTTP_HOST").unwrap_or_else(|_| "127.0.0.1".into());
    let port: u16 = match std::env::var("HTTP_PORT") {
        Ok(p) => p.parse().unwrap_or_else(|_| refus("HTTP_PORT invalide : un numéro de port est attendu")),
        Err(_) => 8080,
    };
    let public = std::env::var("PUBLIC_DIR").unwrap_or_else(|_| "./public".into());
    eprintln!("écoute sur {host} port {port}, persistance {}", persistance.nom());
    let state = AppState { pool, persistance, mesure };

    HttpServer::new(move || {
        let avec_mesure = state.mesure.is_some();
        App::new()
            .wrap(en_tetes_securite())
            .app_data(web::Data::new(state.clone()))
            .configure(configure)
            .configure(|cfg| {
                if avec_mesure {
                    mesure::configure(cfg);
                }
            })
            // Front statique (îlot + client généré) — monté après les routes /api. Seul ce dossier
            // est servi ; les fichiers cachés (`.env`, `.git`) ne le sont jamais.
            .service(actix_files::Files::new("/", public.clone()).index_file("index.html"))
    })
    .bind((host, port))?
    .run()
    .await
}
