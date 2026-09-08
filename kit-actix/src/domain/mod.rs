//! Domaine Todo — **Rust pur** (std uniquement). Aucune dépendance à actix, sqlx, serde…
//! (gate H1). Les invariants sont garantis par le constructeur `Todo::new`.

pub const TITLE_MAX: usize = 255;

/// Erreurs métier — traduites en codes HTTP par l'adaptateur.
#[derive(Debug, Clone, PartialEq)]
pub enum TodoError {
    Validation(Vec<String>),
    NotFound(String),
}

/// Erreur de persistance (remontée par les adaptateurs, opaque au domaine).
#[derive(Debug)]
pub struct RepoError(pub String);

/// Entité agrégat Todo — immuable, invariants dans le constructeur.
/// Les horodatages sont des chaînes ISO-8601 (le domaine ignore toute lib de temps).
#[derive(Clone, Debug, PartialEq)]
pub struct Todo {
    id: String,
    title: String,
    done: bool,
    created_at: String,
    updated_at: String,
}

impl Todo {
    pub fn new(
        id: String,
        title: String,
        done: bool,
        created_at: String,
        updated_at: String,
    ) -> Result<Self, TodoError> {
        let errors = validate_title(&title);
        if !errors.is_empty() {
            return Err(TodoError::Validation(errors));
        }
        Ok(Self { id, title, done, created_at, updated_at })
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn title(&self) -> &str { &self.title }
    pub fn done(&self) -> bool { self.done }
    pub fn created_at(&self) -> &str { &self.created_at }
    pub fn updated_at(&self) -> &str { &self.updated_at }

    /// Copie avec le statut inversé (immuabilité).
    pub fn toggled(&self, now: String) -> Self {
        Self { done: !self.done, updated_at: now, ..self.clone() }
    }

    /// Copie avec un nouveau libellé (post-MVP).
    pub fn renamed(&self, title: String, now: String) -> Result<Self, TodoError> {
        Self::new(self.id.clone(), title, self.done, self.created_at.clone(), now)
    }
}

/// Validation du libellé — messages en français.
pub fn validate_title(title: &str) -> Vec<String> {
    let mut errors = Vec::new();
    let trimmed = title.trim();
    if trimmed.is_empty() {
        errors.push("Le libellé est obligatoire.".to_string());
    } else if trimmed.chars().count() > TITLE_MAX {
        errors.push(format!("Le libellé ne peut dépasser {TITLE_MAX} caractères."));
    }
    errors
}

pub fn normalize_title(title: &str) -> String {
    title.trim().to_string()
}

// --- Ports (interfaces) — implémentés par les adaptateurs ---

/// Port de persistance. Dispatch statique (générique) → pas besoin d'`async-trait`, domaine pur.
pub trait TodoRepository {
    async fn find(&self, id: &str) -> Result<Option<Todo>, RepoError>;
    async fn find_all(&self) -> Result<Vec<Todo>, RepoError>;
    async fn save(&self, todo: &Todo) -> Result<(), RepoError>;
    async fn delete(&self, id: &str) -> Result<(), RepoError>;
}

/// Port d'horloge — renvoie un horodatage ISO-8601 (testable).
pub trait Clock {
    fn now(&self) -> String;
}

/// Port de génération d'identifiant (testable).
pub trait IdGenerator {
    fn uuid(&self) -> String;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ts() -> String { "2026-01-01T00:00:00+00:00".to_string() }

    #[test] // @happy
    fn construct_valid_is_open() {
        let t = Todo::new("id-1".into(), "acheter du pain".into(), false, ts(), ts()).unwrap();
        assert_eq!(t.id(), "id-1");
        assert!(!t.done());
    }

    #[test] // @negative
    fn construct_empty_title_errors() {
        assert!(matches!(
            Todo::new("id-1".into(), "   ".into(), false, ts(), ts()),
            Err(TodoError::Validation(_))
        ));
    }

    #[test] // @edge
    fn toggle_inverts_and_is_immutable() {
        let t = Todo::new("id-1".into(), "tâche".into(), false, ts(), ts()).unwrap();
        let d = t.toggled(ts());
        assert!(d.done());
        assert!(!d.toggled(ts()).done());
        assert!(!t.done()); // original inchangé
    }

    #[test] // @security
    fn title_stored_verbatim() {
        let payload = "<script>alert(1)</script>";
        let t = Todo::new("id-1".into(), payload.into(), false, ts(), ts()).unwrap();
        assert_eq!(t.title(), payload);
    }

    #[test] // @edge — bornes de longueur
    fn title_boundaries() {
        assert!(validate_title(&"a".repeat(TITLE_MAX)).is_empty());
        assert!(!validate_title(&"a".repeat(TITLE_MAX + 1)).is_empty());
    }
}
