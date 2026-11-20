//! Port `Chiffreur` — chiffrement par enveloppe, **Rust pur** (std uniquement, gate H1).
//!
//! Chaque enregistrement reçoit sa propre **clé de données**. Elle chiffre les champs, puis elle
//! n'est conservée qu'**enveloppée** (chiffrée par une clé maîtresse que le kit ne voit pas
//! forcément : en mémoire, ou dans le moteur `transit` d'OpenBao). Le port reste dans le kit après
//! le spike foyer#28 : c'est la mesure conservatoire d'ADR-044 (point 4.5).
//!
//! Adaptateurs : `SansEffet` (clair), `Local` (AES-256-GCM), `OpenBao` (transit, cache réglable),
//! dans `adapter::chiffrement`.

/// Clé de données en clair. Jamais persistée, jamais affichée ; effacée à la libération.
#[derive(Clone, PartialEq)]
pub struct CleDonnees(Vec<u8>);

impl CleDonnees {
    pub fn new(octets: Vec<u8>) -> Self { Self(octets) }
    pub fn octets(&self) -> &[u8] { &self.0 }
}

impl std::fmt::Debug for CleDonnees {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("CleDonnees(***)")
    }
}

impl Drop for CleDonnees {
    fn drop(&mut self) {
        for octet in self.0.iter_mut() {
            // Écriture volatile : le compilateur ne peut pas l'élider.
            unsafe { std::ptr::write_volatile(octet, 0) };
        }
    }
}

/// Clé de données enveloppée : la seule forme sous laquelle elle est persistée.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct CleEnveloppee(pub Vec<u8>);

/// Erreurs de chiffrement — traduites en codes HTTP par l'adaptateur.
#[derive(Debug, Clone, PartialEq)]
pub enum ChiffrementError {
    /// Le service de clés ne répond pas : on refuse, on ne sert jamais de clair (503).
    Indisponible(String),
    /// Chiffré altéré, mauvaise clé ou mauvais contexte (500).
    Integrite(String),
}

/// Port de chiffrement par enveloppe. Dispatch statique, comme les autres ports du kit.
///
/// `contexte` lie un chiffré à son emplacement (identifiant et nom du champ) : un champ copié
/// d'une fiche vers une autre, ou d'un champ vers un autre, ne se déchiffre plus.
pub trait Chiffreur {
    /// Nom de la variante, pour les mesures (`clair`, `local`, `openbao`, `openbao-cache`).
    fn variante(&self) -> &str;
    /// Engendre une clé de données et la renvoie en clair et enveloppée.
    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError>;
    /// Retrouve la clé de données à partir de sa forme enveloppée.
    async fn desenvelopper(&self, cle: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError>;
    fn chiffrer_champ(&self, cle: &CleDonnees, contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError>;
    fn dechiffrer_champ(&self, cle: &CleDonnees, contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test] // @security — la clé ne fuit pas dans les journaux
    fn cle_donnees_masquee_au_debug() {
        let cle = CleDonnees::new(vec![0x41; 32]);
        assert_eq!(format!("{cle:?}"), "CleDonnees(***)");
    }
}
