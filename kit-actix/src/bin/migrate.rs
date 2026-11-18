//! Outil de migration : `migrate up` (applique ce qui manque), `migrate down` (annule la dernière),
//! `migrate status`. Même configuration que le serveur (`DATABASE_URL` ou `DB_*`).
use todo::adapter::{connect_pool, migrations};

fn echec(message: impl std::fmt::Display) -> ! {
    eprintln!("migrate : {message}");
    std::process::exit(1);
}

#[tokio::main]
async fn main() {
    let commande = std::env::args().nth(1).unwrap_or_default();
    if !matches!(commande.as_str(), "up" | "down" | "status") {
        eprintln!("usage : migrate up|down|status");
        std::process::exit(2);
    }
    let pool = connect_pool().await.unwrap_or_else(|e| echec(e));
    match commande.as_str() {
        "up" => match migrations::up(&pool).await {
            Ok(n) => println!("migrations : {n} appliquée(s)"),
            Err(e) => echec(e),
        },
        "down" => match migrations::down(&pool).await {
            Ok(Some(v)) => println!("migrations : version {v} annulée"),
            Ok(None) => println!("migrations : rien à annuler"),
            Err(e) => echec(e),
        },
        _ => match migrations::status(&pool).await {
            Ok(lignes) => {
                for (version, description, faite) in lignes {
                    println!("{} {version:04} {description}", if faite { "appliquée " } else { "en attente" });
                }
            }
            Err(e) => echec(e),
        },
    }
}
