-- Module de mesure du chiffrement par personne (foyer#28). Hors de migrations/pending/ : il n'entre
-- pas dans le gabarit dont héritent les projets. Réversible via 0001_create_personnes.down.sql.
-- Aucun champ personnel en clair : uniquement des octets chiffrés et la clé de données enveloppée.
CREATE TABLE IF NOT EXISTS personnes (
  id VARCHAR(64) NOT NULL PRIMARY KEY,
  cle_enveloppee BYTEA NOT NULL,
  nom BYTEA NOT NULL,
  courriel BYTEA NOT NULL,
  telephone BYTEA NOT NULL
)
