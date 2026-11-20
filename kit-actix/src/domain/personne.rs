//! Fiche de personne de **mesure** (spike foyer#28) — **Rust pur**. Elle n'existe que pour mesurer
//! le coût du chiffrement par personne ; le module n'est monté que si `CHIFFREMENT` est posé.

use super::chiffrement::CleEnveloppee;
use super::RepoError;

pub const CHAMP_MAX: usize = 255;

#[derive(Debug, Clone, PartialEq)]
pub enum PersonneError {
    Validation(Vec<String>),
}

/// Fiche en clair, telle que l'application la manipule. Jamais persistée sous cette forme.
#[derive(Clone, Debug, PartialEq)]
pub struct Personne {
    id: String,
    nom: String,
    courriel: String,
    telephone: String,
}

impl Personne {
    pub fn new(id: String, nom: String, courriel: String, telephone: String) -> Result<Self, PersonneError> {
        let mut errors = Vec::new();
        if nom.trim().is_empty() {
            errors.push("Le nom est obligatoire.".to_string());
        }
        if !courriel.contains('@') {
            errors.push("Le courriel est invalide.".to_string());
        }
        for (libelle, valeur) in [("nom", &nom), ("courriel", &courriel), ("téléphone", &telephone)] {
            if valeur.chars().count() > CHAMP_MAX {
                errors.push(format!("Le {libelle} ne peut dépasser {CHAMP_MAX} caractères."));
            }
        }
        if !errors.is_empty() {
            return Err(PersonneError::Validation(errors));
        }
        Ok(Self { id, nom, courriel, telephone })
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn nom(&self) -> &str { &self.nom }
    pub fn courriel(&self) -> &str { &self.courriel }
    pub fn telephone(&self) -> &str { &self.telephone }
}

/// Fiche telle qu'elle est persistée : champs chiffrés, clé de données enveloppée.
#[derive(Clone, Debug, PartialEq)]
pub struct FicheChiffree {
    pub id: String,
    pub cle: CleEnveloppee,
    pub nom: Vec<u8>,
    pub courriel: Vec<u8>,
    pub telephone: Vec<u8>,
}

/// Contexte d'un champ (données associées du chiffrement authentifié).
pub fn contexte(id: &str, champ: &str) -> String {
    format!("personne:{id}:{champ}")
}

/// Port de persistance des fiches chiffrées.
pub trait PersonneRepository {
    async fn trouver(&self, id: &str) -> Result<Option<FicheChiffree>, RepoError>;
    async fn enregistrer(&self, fiche: &FicheChiffree) -> Result<(), RepoError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test] // @negative
    fn nom_vide_et_courriel_invalide() {
        let r = Personne::new("p1".into(), " ".into(), "sans-arobase".into(), String::new());
        assert!(matches!(r, Err(PersonneError::Validation(e)) if e.len() == 2));
    }

    #[test] // @edge — bornes de longueur
    fn bornes_de_longueur() {
        let ok = Personne::new("p1".into(), "a".repeat(CHAMP_MAX), "a@b".into(), String::new());
        assert!(ok.is_ok());
        let ko = Personne::new("p1".into(), "a".repeat(CHAMP_MAX + 1), "a@b".into(), String::new());
        assert!(ko.is_err());
    }
}
