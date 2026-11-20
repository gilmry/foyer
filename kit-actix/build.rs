// Les migrations sont embarquées dans les binaires (`sqlx::migrate!`) : recompiler quand elles changent.
fn main() {
    println!("cargo:rerun-if-changed=database/migrations/pending");
}
