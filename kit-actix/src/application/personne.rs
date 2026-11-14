//! Use-cases de la fiche de personne de mesure — **Rust pur**. Génériques sur les ports
//! `PersonneRepository` et `Chiffreur` : la même orchestration sert les quatre variantes.

use super::Error;
use crate::domain::chiffrement::{ChiffrementError, Chiffreur};
use crate::domain::personne::{contexte, FicheChiffree, Personne, PersonneError, PersonneRepository};
use crate::domain::IdGenerator;

impl From<PersonneError> for Error {
    fn from(e: PersonneError) -> Self {
        match e {
            PersonneError::Validation(v) => Error::Validation(v),
        }
    }
}

impl From<ChiffrementError> for Error {
    fn from(e: ChiffrementError) -> Self {
        match e {
            ChiffrementError::Indisponible(m) => Error::Indisponible(m),
            ChiffrementError::Integrite(m) => Error::Repo(format!("intégrité : {m}")),
        }
    }
}

/// Champs saisis, avant validation.
pub struct SaisiePersonne<'s> {
    pub nom: &'s str,
    pub courriel: &'s str,
    pub telephone: &'s str,
}

pub struct EcrirePersonne<'a, R: PersonneRepository, C: Chiffreur> {
    pub repo: &'a R,
    pub chiffreur: &'a C,
    pub ids: &'a dyn IdGenerator,
}

impl<'a, R: PersonneRepository, C: Chiffreur> EcrirePersonne<'a, R, C> {
    pub async fn execute(&self, saisie: SaisiePersonne<'_>) -> Result<Personne, Error> {
        let personne = Personne::new(
            self.ids.uuid(),
            saisie.nom.trim().to_string(),
            saisie.courriel.trim().to_string(),
            saisie.telephone.trim().to_string(),
        )?;
        let (cle, enveloppee) = self.chiffreur.nouvelle_cle().await?;
        let id = personne.id();
        let c = self.chiffreur;
        let fiche = FicheChiffree {
            id: id.to_string(),
            cle: enveloppee,
            nom: c.chiffrer_champ(&cle, &contexte(id, "nom"), personne.nom())?,
            courriel: c.chiffrer_champ(&cle, &contexte(id, "courriel"), personne.courriel())?,
            telephone: c.chiffrer_champ(&cle, &contexte(id, "telephone"), personne.telephone())?,
        };
        self.repo.enregistrer(&fiche).await?;
        Ok(personne)
    }
}

pub struct LirePersonne<'a, R: PersonneRepository, C: Chiffreur> {
    pub repo: &'a R,
    pub chiffreur: &'a C,
}

impl<'a, R: PersonneRepository, C: Chiffreur> LirePersonne<'a, R, C> {
    /// Refuse (`Indisponible`) plutôt que de renvoyer un champ qu'il n'a pas pu déchiffrer.
    pub async fn execute(&self, id: &str) -> Result<Personne, Error> {
        let fiche = self.repo.trouver(id).await?.ok_or_else(|| Error::NotFound(id.to_string()))?;
        let cle = self.chiffreur.desenvelopper(&fiche.cle).await?;
        let c = self.chiffreur;
        Ok(Personne::new(
            fiche.id.clone(),
            c.dechiffrer_champ(&cle, &contexte(id, "nom"), &fiche.nom)?,
            c.dechiffrer_champ(&cle, &contexte(id, "courriel"), &fiche.courriel)?,
            c.dechiffrer_champ(&cle, &contexte(id, "telephone"), &fiche.telephone)?,
        )?)
    }
}
