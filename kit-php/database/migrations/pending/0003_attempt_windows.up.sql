-- Compteurs d'essais (connexion, inscription) à fenêtre glissante (ADR-001). Réversible via
-- 0003_attempt_windows.down.sql (gate plancher G2). SQL portable MySQL 8 / MariaDB.
-- En base plutôt qu'en fichiers : le dossier du compte d'un hébergeur peut être un partage réseau
-- où le verrou de fichier n'est pas sûr ; ici le verrou est celui de la base (GET_LOCK).
-- La clé (courriel normalisé, adresse) n'est stockée qu'en empreinte SHA-256.
CREATE TABLE attempt_windows (
  key_hash CHAR(64) NOT NULL,
  stamps TEXT NOT NULL,
  updated_at INT NOT NULL,
  PRIMARY KEY (key_hash),
  KEY idx_attempt_windows_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
