-- Comptes, jetons porteurs et propriétaire des tâches (ADR-001). Réversible via
-- 0002_accounts_and_owner.down.sql (gate plancher G2). SQL portable MySQL 8 / MariaDB.
-- Le courriel est comparé OCTET POUR OCTET (collation binaire) : avec la collation par défaut,
-- « é » vaut « e » et un courriel accentué désignerait le compte d'un autre.
-- Seul un HACHAGE du mot de passe est stocké ; seule l'EMPREINTE SHA-256 d'un jeton l'est.
CREATE TABLE accounts (
  id VARCHAR(64) NOT NULL,
  email VARCHAR(190) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounts_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE access_tokens (
  token_hash CHAR(64) NOT NULL,
  account_id VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  PRIMARY KEY (token_hash),
  KEY idx_access_tokens_account (account_id),
  KEY idx_access_tokens_expires (expires_at),
  CONSTRAINT fk_access_tokens_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Les tâches d'avant cette migration n'ont pas de propriétaire ('') : plus personne ne les voit.
ALTER TABLE todos ADD COLUMN owner_id VARCHAR(64) NOT NULL DEFAULT '';

ALTER TABLE todos ADD KEY idx_todos_owner_created (owner_id, created_at);
