//! Adaptateurs du port `Chiffreur` (foyer#28). AES-256-GCM (RustCrypto `aes-gcm`), client HTTP
//! `reqwest` vers le moteur `transit` d'OpenBao. Rien de ceci ne fuit dans le domaine (gate H1).
//!
//! **Limite du spike, à ne pas recopier telle quelle** : l'adaptateur OpenBao s'authentifie par
//! un jeton statique, le jeton racine du mode dev (`bao server -dev`). La cible est un jeton court
//! délivré à l'application (ADR-042 de Sluis, point 6 ; l'émetteur, point C, reste ouvert).

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use aes_gcm::aead::{Aead, AeadCore, KeyInit, OsRng, Payload};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::engine::general_purpose::STANDARD as B64;
use base64::Engine;
use serde::Serialize;

use crate::domain::chiffrement::{ChiffrementError, Chiffreur, CleDonnees, CleEnveloppee};

const NONCE: usize = 12;
const CONTEXTE_ENVELOPPE: &str = "kit-actix:cle-de-donnees";

/// Chiffre `clair` sous `cle` (32 octets) ; sortie = nonce aléatoire ‖ chiffré ‖ étiquette.
fn sceller(cle: &[u8], contexte: &str, clair: &[u8]) -> Result<Vec<u8>, ChiffrementError> {
    if cle.len() != 32 {
        return Err(ChiffrementError::Integrite("clé de longueur invalide".into()));
    }
    let aead = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(cle));
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
    let chiffre = aead
        .encrypt(&nonce, Payload { msg: clair, aad: contexte.as_bytes() })
        .map_err(|_| ChiffrementError::Integrite("chiffrement impossible".into()))?;
    let mut sortie = nonce.to_vec();
    sortie.extend_from_slice(&chiffre);
    Ok(sortie)
}

fn ouvrir(cle: &[u8], contexte: &str, scelle: &[u8]) -> Result<Vec<u8>, ChiffrementError> {
    if cle.len() != 32 || scelle.len() < NONCE {
        return Err(ChiffrementError::Integrite("chiffré ou clé invalide".into()));
    }
    let aead = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(cle));
    let (nonce, chiffre) = scelle.split_at(NONCE);
    aead.decrypt(Nonce::from_slice(nonce), Payload { msg: chiffre, aad: contexte.as_bytes() })
        .map_err(|_| ChiffrementError::Integrite("chiffré altéré ou hors contexte".into()))
}

fn champ_aes(cle: &CleDonnees, contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError> {
    sceller(cle.octets(), contexte, clair.as_bytes())
}

fn champ_aes_inverse(cle: &CleDonnees, contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError> {
    String::from_utf8(ouvrir(cle.octets(), contexte, chiffre)?)
        .map_err(|_| ChiffrementError::Integrite("champ non UTF-8".into()))
}

/// Variante `clair` : n'enveloppe ni ne chiffre rien. C'est la référence de la mesure.
pub struct SansEffet;

impl Chiffreur for SansEffet {
    fn variante(&self) -> &str { "clair" }
    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError> {
        Ok((CleDonnees::new(Vec::new()), CleEnveloppee(Vec::new())))
    }
    async fn desenvelopper(&self, _cle: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError> {
        Ok(CleDonnees::new(Vec::new()))
    }
    fn chiffrer_champ(&self, _cle: &CleDonnees, _contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError> {
        Ok(clair.as_bytes().to_vec())
    }
    fn dechiffrer_champ(&self, _cle: &CleDonnees, _contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError> {
        String::from_utf8(chiffre.to_vec()).map_err(|_| ChiffrementError::Integrite("champ non UTF-8".into()))
    }
}

/// Variante `local` : AES-256-GCM, clé maîtresse tirée au démarrage et gardée en mémoire.
/// Un redémarrage rend donc illisibles les fiches écrites avant : acceptable pour une mesure.
pub struct Local {
    maitresse: Vec<u8>,
}

impl Local {
    pub fn new() -> Self {
        Self { maitresse: Aes256Gcm::generate_key(&mut OsRng).to_vec() }
    }
}

impl Default for Local {
    fn default() -> Self { Self::new() }
}

impl Chiffreur for Local {
    fn variante(&self) -> &str { "local" }
    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError> {
        let cle = Aes256Gcm::generate_key(&mut OsRng).to_vec();
        let enveloppee = sceller(&self.maitresse, CONTEXTE_ENVELOPPE, &cle)?;
        Ok((CleDonnees::new(cle), CleEnveloppee(enveloppee)))
    }
    async fn desenvelopper(&self, cle: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError> {
        Ok(CleDonnees::new(ouvrir(&self.maitresse, CONTEXTE_ENVELOPPE, &cle.0)?))
    }
    fn chiffrer_champ(&self, cle: &CleDonnees, contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError> {
        champ_aes(cle, contexte, clair)
    }
    fn dechiffrer_champ(&self, cle: &CleDonnees, contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError> {
        champ_aes_inverse(cle, contexte, chiffre)
    }
}

/// Compteurs exposés par `GET /api/mesure/compteurs` : la campagne de Sluis (sluis#104) y lit
/// le nombre d'appels à OpenBao par variante.
#[derive(Default)]
pub struct Compteurs {
    pub openbao_requetes: AtomicU64,
    pub openbao_echecs: AtomicU64,
    pub openbao_enveloppements: AtomicU64,
    pub openbao_desenveloppements: AtomicU64,
    pub cache_succes: AtomicU64,
    pub cache_echecs: AtomicU64,
}

#[derive(Serialize)]
pub struct ReleveCompteurs {
    pub openbao_requetes: u64,
    pub openbao_echecs: u64,
    pub openbao_enveloppements: u64,
    pub openbao_desenveloppements: u64,
    pub cache_succes: u64,
    pub cache_echecs: u64,
}

impl Compteurs {
    fn plus(c: &AtomicU64) {
        c.fetch_add(1, Ordering::Relaxed);
    }
    pub fn releve(&self) -> ReleveCompteurs {
        let l = |c: &AtomicU64| c.load(Ordering::Relaxed);
        ReleveCompteurs {
            openbao_requetes: l(&self.openbao_requetes),
            openbao_echecs: l(&self.openbao_echecs),
            openbao_enveloppements: l(&self.openbao_enveloppements),
            openbao_desenveloppements: l(&self.openbao_desenveloppements),
            cache_succes: l(&self.cache_succes),
            cache_echecs: l(&self.cache_echecs),
        }
    }
}

/// Au-delà, le cache purge ses entrées expirées avant d'en ajouter une.
const CACHE_PURGE: usize = 10_000;

/// Variantes `openbao` (TTL nul, aucun cache) et `openbao-cache` (TTL > 0) : la clé de données
/// est engendrée et enveloppée par `transit/datakey`, désenveloppée par `transit/decrypt`. Les
/// champs sont chiffrés localement avec elle, comme en variante `local`.
pub struct OpenBao {
    client: reqwest::Client,
    adresse: String,
    jeton: String,
    cle_transit: String,
    ttl: Duration,
    cache: Mutex<HashMap<CleEnveloppee, (CleDonnees, Instant)>>,
    compteurs: Arc<Compteurs>,
}

impl OpenBao {
    pub fn new(adresse: String, jeton: String, cle_transit: String, ttl: Duration, compteurs: Arc<Compteurs>) -> Self {
        let client = reqwest::Client::builder()
            .connect_timeout(Duration::from_secs(1))
            .timeout(Duration::from_secs(3))
            .build()
            .expect("client HTTP");
        Self { client, adresse, jeton, cle_transit, ttl, cache: Mutex::new(HashMap::new()), compteurs }
    }

    fn en_cache(&self, cle: &CleEnveloppee) -> Option<CleDonnees> {
        let cache = self.cache.lock().unwrap();
        cache.get(cle).filter(|(_, expire)| Instant::now() < *expire).map(|(c, _)| c.clone())
    }

    fn mettre_en_cache(&self, enveloppee: CleEnveloppee, cle: &CleDonnees) {
        if self.ttl.is_zero() {
            return;
        }
        let mut cache = self.cache.lock().unwrap();
        let maintenant = Instant::now();
        if cache.len() >= CACHE_PURGE {
            cache.retain(|_, (_, expire)| maintenant < *expire);
        }
        cache.insert(enveloppee, (cle.clone(), maintenant + self.ttl));
    }

    async fn appeler(&self, chemin: &str, corps: serde_json::Value) -> Result<serde_json::Value, ChiffrementError> {
        Compteurs::plus(&self.compteurs.openbao_requetes);
        let echec = |m: String| {
            Compteurs::plus(&self.compteurs.openbao_echecs);
            m
        };
        let reponse = self
            .client
            .post(format!("{}/v1/transit/{chemin}/{}", self.adresse, self.cle_transit))
            .header("X-Vault-Token", &self.jeton)
            .json(&corps)
            .send()
            .await
            .map_err(|e| ChiffrementError::Indisponible(echec(format!("OpenBao injoignable : {e}"))))?;
        let statut = reponse.status();
        if statut.as_u16() == 400 {
            return Err(ChiffrementError::Integrite(echec("OpenBao refuse le chiffré".into())));
        }
        if !statut.is_success() {
            return Err(ChiffrementError::Indisponible(echec(format!("OpenBao répond {statut}"))));
        }
        reponse
            .json::<serde_json::Value>()
            .await
            .map_err(|e| ChiffrementError::Indisponible(echec(format!("réponse OpenBao illisible : {e}"))))
    }

    fn texte<'v>(v: &'v serde_json::Value, champ: &str) -> Result<&'v str, ChiffrementError> {
        v["data"][champ]
            .as_str()
            .ok_or_else(|| ChiffrementError::Indisponible(format!("réponse OpenBao sans data.{champ}")))
    }

    fn cle_depuis_b64(b64: &str) -> Result<CleDonnees, ChiffrementError> {
        B64.decode(b64)
            .map(CleDonnees::new)
            .map_err(|_| ChiffrementError::Integrite("clé de données mal encodée".into()))
    }
}

impl Chiffreur for OpenBao {
    fn variante(&self) -> &str {
        if self.ttl.is_zero() { "openbao" } else { "openbao-cache" }
    }

    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError> {
        let v = self.appeler("datakey/plaintext", serde_json::json!({})).await?;
        Compteurs::plus(&self.compteurs.openbao_enveloppements);
        let cle = Self::cle_depuis_b64(Self::texte(&v, "plaintext")?)?;
        let enveloppee = CleEnveloppee(Self::texte(&v, "ciphertext")?.as_bytes().to_vec());
        self.mettre_en_cache(enveloppee.clone(), &cle);
        Ok((cle, enveloppee))
    }

    async fn desenvelopper(&self, enveloppee: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError> {
        if !self.ttl.is_zero() {
            if let Some(cle) = self.en_cache(enveloppee) {
                Compteurs::plus(&self.compteurs.cache_succes);
                return Ok(cle);
            }
            Compteurs::plus(&self.compteurs.cache_echecs);
        }
        let chiffre = std::str::from_utf8(&enveloppee.0)
            .map_err(|_| ChiffrementError::Integrite("clé enveloppée invalide".into()))?;
        let v = self.appeler("decrypt", serde_json::json!({ "ciphertext": chiffre })).await?;
        Compteurs::plus(&self.compteurs.openbao_desenveloppements);
        let cle = Self::cle_depuis_b64(Self::texte(&v, "plaintext")?)?;
        self.mettre_en_cache(enveloppee.clone(), &cle);
        Ok(cle)
    }

    fn chiffrer_champ(&self, cle: &CleDonnees, contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError> {
        champ_aes(cle, contexte, clair)
    }
    fn dechiffrer_champ(&self, cle: &CleDonnees, contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError> {
        champ_aes_inverse(cle, contexte, chiffre)
    }
}

/// Variante choisie au démarrage. Énumération plutôt que `dyn` : le port reste en dispatch statique.
pub enum ChiffreurChoisi {
    Clair(SansEffet),
    Local(Local),
    OpenBao(OpenBao),
}

impl ChiffreurChoisi {
    /// Lit `CHIFFREMENT=clair|local|openbao|openbao-cache` ; `None` si absent (module désactivé).
    /// OpenBao : `OPENBAO_ADDR`, `OPENBAO_JETON`, `OPENBAO_CLE` (défaut `kit-actix`),
    /// `CHIFFREMENT_CACHE_TTL_S` (défaut 30, variante `openbao-cache` seulement).
    pub fn depuis_env(compteurs: Arc<Compteurs>) -> Result<Option<Self>, String> {
        let variante = match std::env::var("CHIFFREMENT") {
            Ok(v) if !v.trim().is_empty() => v,
            _ => return Ok(None),
        };
        let openbao = |ttl: Duration| -> Result<Self, String> {
            let adresse = std::env::var("OPENBAO_ADDR").map_err(|_| "OPENBAO_ADDR manquant".to_string())?;
            let jeton = std::env::var("OPENBAO_JETON").map_err(|_| "OPENBAO_JETON manquant".to_string())?;
            let cle = std::env::var("OPENBAO_CLE").unwrap_or_else(|_| "kit-actix".into());
            Ok(Self::OpenBao(OpenBao::new(adresse.trim_end_matches('/').into(), jeton, cle, ttl, compteurs.clone())))
        };
        match variante.as_str() {
            "clair" => Ok(Some(Self::Clair(SansEffet))),
            "local" => Ok(Some(Self::Local(Local::new()))),
            "openbao" => openbao(Duration::ZERO).map(Some),
            "openbao-cache" => {
                let s: u64 = std::env::var("CHIFFREMENT_CACHE_TTL_S").ok().and_then(|s| s.parse().ok()).unwrap_or(30);
                if s == 0 {
                    return Err("openbao-cache exige CHIFFREMENT_CACHE_TTL_S > 0".into());
                }
                openbao(Duration::from_secs(s)).map(Some)
            }
            autre => Err(format!("CHIFFREMENT inconnu : {autre} (clair|local|openbao|openbao-cache)")),
        }
    }
}

impl Chiffreur for ChiffreurChoisi {
    fn variante(&self) -> &str {
        match self {
            Self::Clair(c) => c.variante(),
            Self::Local(c) => c.variante(),
            Self::OpenBao(c) => c.variante(),
        }
    }
    async fn nouvelle_cle(&self) -> Result<(CleDonnees, CleEnveloppee), ChiffrementError> {
        match self {
            Self::Clair(c) => c.nouvelle_cle().await,
            Self::Local(c) => c.nouvelle_cle().await,
            Self::OpenBao(c) => c.nouvelle_cle().await,
        }
    }
    async fn desenvelopper(&self, cle: &CleEnveloppee) -> Result<CleDonnees, ChiffrementError> {
        match self {
            Self::Clair(c) => c.desenvelopper(cle).await,
            Self::Local(c) => c.desenvelopper(cle).await,
            Self::OpenBao(c) => c.desenvelopper(cle).await,
        }
    }
    fn chiffrer_champ(&self, cle: &CleDonnees, contexte: &str, clair: &str) -> Result<Vec<u8>, ChiffrementError> {
        match self {
            Self::Clair(c) => c.chiffrer_champ(cle, contexte, clair),
            Self::Local(c) => c.chiffrer_champ(cle, contexte, clair),
            Self::OpenBao(c) => c.chiffrer_champ(cle, contexte, clair),
        }
    }
    fn dechiffrer_champ(&self, cle: &CleDonnees, contexte: &str, chiffre: &[u8]) -> Result<String, ChiffrementError> {
        match self {
            Self::Clair(c) => c.dechiffrer_champ(cle, contexte, chiffre),
            Self::Local(c) => c.dechiffrer_champ(cle, contexte, chiffre),
            Self::OpenBao(c) => c.dechiffrer_champ(cle, contexte, chiffre),
        }
    }
}

/// Ressources du processus, lues dans `/proc/self` (Linux) : temps processeur cumulé en tops
/// d'horloge et mémoire résidente en kio. `None` ailleurs que sous Linux.
#[derive(Serialize)]
pub struct Ressources {
    pub cpu_tops: Option<u64>,
    pub rss_kio: Option<u64>,
}

pub fn ressources_processus() -> Ressources {
    let cpu_tops = std::fs::read_to_string("/proc/self/stat").ok().and_then(|s| {
        // Le nom du processus (champ 2) est entre parenthèses ; utime et stime sont les
        // champs 14 et 15, soit les 12e et 13e après la parenthèse fermante.
        let apres = s.rsplit_once(')')?.1;
        let champs: Vec<&str> = apres.split_whitespace().collect();
        Some(champs.get(11)?.parse::<u64>().ok()? + champs.get(12)?.parse::<u64>().ok()?)
    });
    let rss_kio = std::fs::read_to_string("/proc/self/status").ok().and_then(|s| {
        s.lines().find(|l| l.starts_with("VmRSS:"))?.split_whitespace().nth(1)?.parse().ok()
    });
    Ressources { cpu_tops, rss_kio }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test] // @happy — aller-retour local
    async fn local_aller_retour() {
        let c = Local::new();
        let (cle, env) = c.nouvelle_cle().await.unwrap();
        let chiffre = c.chiffrer_champ(&cle, "personne:p1:nom", "Ada Lovelace").unwrap();
        let cle2 = c.desenvelopper(&env).await.unwrap();
        assert_eq!(c.dechiffrer_champ(&cle2, "personne:p1:nom", &chiffre).unwrap(), "Ada Lovelace");
    }

    #[tokio::test] // @security — la clé enveloppée ne contient pas la clé en clair
    async fn local_cle_seulement_enveloppee() {
        let c = Local::new();
        let (cle, env) = c.nouvelle_cle().await.unwrap();
        assert_eq!(cle.octets().len(), 32);
        assert_eq!(env.0.len(), NONCE + 32 + 16);
        assert!(!env.0.windows(32).any(|w| w == cle.octets()));
    }

    #[tokio::test] // @security — un champ déplacé ou altéré ne se déchiffre pas
    async fn local_contexte_et_alteration() {
        let c = Local::new();
        let (cle, _) = c.nouvelle_cle().await.unwrap();
        let mut chiffre = c.chiffrer_champ(&cle, "personne:p1:nom", "Ada").unwrap();
        assert!(c.dechiffrer_champ(&cle, "personne:p2:nom", &chiffre).is_err());
        assert!(c.dechiffrer_champ(&cle, "personne:p1:courriel", &chiffre).is_err());
        let dernier = chiffre.len() - 1;
        chiffre[dernier] ^= 1;
        assert!(matches!(
            c.dechiffrer_champ(&cle, "personne:p1:nom", &chiffre),
            Err(ChiffrementError::Integrite(_))
        ));
    }

    #[tokio::test] // @security — une autre clé maîtresse ne désenveloppe pas
    async fn local_autre_maitresse() {
        let (_, env) = Local::new().nouvelle_cle().await.unwrap();
        assert!(Local::new().desenvelopper(&env).await.is_err());
    }

    #[tokio::test] // @negative — OpenBao injoignable : Indisponible, jamais de clair
    async fn openbao_injoignable() {
        let c = OpenBao::new("http://127.0.0.1:9".into(), "x".into(), "k".into(), Duration::ZERO, Arc::default());
        assert!(matches!(
            c.desenvelopper(&CleEnveloppee(b"vault:v1:xx".to_vec())).await,
            Err(ChiffrementError::Indisponible(_))
        ));
        assert_eq!(c.compteurs.releve().openbao_echecs, 1);
    }

    #[test] // @edge — le choix par l'environnement
    fn choix_inconnu_refuse() {
        std::env::set_var("CHIFFREMENT", "rot13");
        assert!(ChiffreurChoisi::depuis_env(Arc::default()).is_err());
        std::env::remove_var("CHIFFREMENT");
        assert!(ChiffreurChoisi::depuis_env(Arc::default()).unwrap().is_none());
    }
}
