-- Snapshot du schéma (état courant). Régénéré à partir des migrations appliquées.
CREATE TABLE IF NOT EXISTS todos (
  id VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  done TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_todos_created_at (created_at),
  KEY idx_todos_done (done)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
