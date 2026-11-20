-- Snapshot du schéma (état courant, après 0001, 0002 et 0003). Pour mémoire : le schéma se pose par
-- `php bin/migrate.php up`, pas par ce fichier.
CREATE TABLE IF NOT EXISTS todos (
  id VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  done TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  owner_id VARCHAR(64) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY idx_todos_created_at (created_at),
  KEY idx_todos_done (done),
  KEY idx_todos_owner_created (owner_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounts (
  id VARCHAR(64) NOT NULL,
  email VARCHAR(190) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounts_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS access_tokens (
  token_hash CHAR(64) NOT NULL,
  account_id VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  PRIMARY KEY (token_hash),
  KEY idx_access_tokens_account (account_id),
  KEY idx_access_tokens_expires (expires_at),
  CONSTRAINT fk_access_tokens_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(191) NOT NULL,
  checksum CHAR(64) NOT NULL,
  applied_at DATETIME NOT NULL,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attempt_windows (
  key_hash CHAR(64) NOT NULL,
  stamps TEXT NOT NULL,
  updated_at INT NOT NULL,
  PRIMARY KEY (key_hash),
  KEY idx_attempt_windows_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
