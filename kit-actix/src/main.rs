//! Binaire serveur — assemble l'app actix (routes API + front statique) et le pool PostgreSQL.
use actix_web::{web, App, HttpServer};
use todo::adapter::connect_pool;
use todo::http::{configure, AppState};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let pool = connect_pool().await.expect("connexion PostgreSQL");
    let state = AppState { pool };
    let host = std::env::var("HTTP_HOST").unwrap_or_else(|_| "127.0.0.1".into());
    let port: u16 = std::env::var("HTTP_PORT").ok().and_then(|p| p.parse().ok()).unwrap_or(8080);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(state.clone()))
            .configure(configure)
            // Front statique (îlot + client généré) — monté après les routes /api.
            .service(actix_files::Files::new("/", "./public").index_file("index.html"))
    })
    .bind((host, port))?
    .run()
    .await
}
