//! Cas d'usage de la fiche de personne de mesure (foyer#28), avec un faux dépôt en mémoire et les
//! adaptateurs `SansEffet` et `Local` (aucune DB, aucun OpenBao). Les variantes OpenBao sont
//! jouées contre un vrai OpenBao par le gate `harness/e2e-chiffrement.sh`.
use std::collections::HashMap;
use std::sync::Mutex;

use todo::adapter::chiffrement::{Local, SansEffet};
use todo::application::personne::{EcrirePersonne, LirePersonne, SaisiePersonne};
use todo::application::Error;
use todo::domain::chiffrement::{ChiffrementError, Chiffreur, CleDonnees, CleEnveloppee};
use todo::domain::personne::{FicheChiffree, PersonneRepository};
use todo::domain::{IdGenerator, RepoError};

#[derive(Default)]
struct FakeRepo {
    store: Mutex<HashMap<String, FicheChiffree>>,
}
impl PersonneRepository for FakeRepo {
    async fn trouver(&self, id: &str) -> Result<Option<FicheChiffree>, RepoError> {
        Ok(self.store.lock().unwrap().get(id).cloned())
    }
    async fn enregistrer(&self, fiche: &FicheChiffree) -> Result<(), RepoError> {
        self.store.lock().unwrap().insert(fiche.id.clone(), fiche.clone());
        Ok(())
    }
}

struct Ids;
impl IdGenerator for Ids {
    fn uuid(&self) -> String {
        "p-1".to_string()
    }
}

/// Chiffreur dont le service de clés est tombé après l'écriture.
struct EnPanne(Local);
impl Chiffreur for EnPanne {
    fn variante(&self) -> &str { "en-panne" }
    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError> {
        self.0.nouvelle_cle().await
    }
    async fn desenvelopper(&self, _: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError> {
        Err(ChiffrementError::Indisponible("service de clés arrêté".into()))
    }
    fn chiffrer_champ(&self, c: &CleDonnees, x: &str, s: &str) -> Result<Vec<u8>, ChiffrementError> {
        self.0.chiffrer_champ(c, x, s)
    }
    fn dechiffrer_champ(&self, c: &CleDonnees, x: &str, s: &[u8]) -> Result<String, ChiffrementError> {
        self.0.dechiffrer_champ(c, x, s)
    }
}

fn saisie() -> SaisiePersonne<'static> {
    SaisiePersonne { nom: "Ada Lovelace", courriel: "ada@exemple.invalid", telephone: "+32 2 000 00 00" }
}

async fn aller_retour<C: Chiffreur>(c: &C) -> (FakeRepo, todo::domain::personne::Personne) {
    let repo = FakeRepo::default();
    EcrirePersonne { repo: &repo, chiffreur: c, ids: &Ids }.execute(saisie()).await.unwrap();
    let relue = LirePersonne { repo: &repo, chiffreur: c }.execute("p-1").await.unwrap();
    (repo, relue)
}

#[tokio::test] // @happy — clair et local relisent les mêmes champs
async fn relit_a_l_identique() {
    for (variante, relue) in [("clair", aller_retour(&SansEffet).await.1), ("local", aller_retour(&Local::new()).await.1)] {
        assert_eq!(relue.nom(), "Ada Lovelace", "{variante}");
        assert_eq!(relue.courriel(), "ada@exemple.invalid", "{variante}");
        assert_eq!(relue.telephone(), "+32 2 000 00 00", "{variante}");
    }
}

#[tokio::test] // @security — en local, le dépôt ne voit aucun champ en clair
async fn local_ne_persiste_aucun_clair() {
    let (repo, _) = aller_retour(&Local::new()).await;
    let fiche = repo.trouver("p-1").await.unwrap().unwrap();
    for (champ, clair) in [(&fiche.nom, "Ada Lovelace"), (&fiche.courriel, "ada@exemple.invalid")] {
        assert!(!champ.windows(clair.len()).any(|w| w == clair.as_bytes()));
    }
}

#[tokio::test] // @negative — service de clés arrêté : Indisponible, aucun champ renvoyé
async fn service_de_cles_arrete() {
    let c = EnPanne(Local::new());
    let repo = FakeRepo::default();
    EcrirePersonne { repo: &repo, chiffreur: &c, ids: &Ids }.execute(saisie()).await.unwrap();
    let r = LirePersonne { repo: &repo, chiffreur: &c }.execute("p-1").await;
    assert!(matches!(r, Err(Error::Indisponible(_))));
}

#[tokio::test] // @negative — saisie invalide : rien n'est persisté
async fn saisie_invalide_ne_persiste_rien() {
    let repo = FakeRepo::default();
    let s = SaisiePersonne { nom: "", courriel: "x", telephone: "" };
    let r = EcrirePersonne { repo: &repo, chiffreur: &Local::new(), ids: &Ids }.execute(s).await;
    assert!(matches!(r, Err(Error::Validation(_))));
    assert!(repo.store.lock().unwrap().is_empty());
}

#[tokio::test] // @negative — fiche inconnue
async fn fiche_inconnue() {
    let r = LirePersonne { repo: &FakeRepo::default(), chiffreur: &SansEffet }.execute("absent").await;
    assert!(matches!(r, Err(Error::NotFound(_))));
}
