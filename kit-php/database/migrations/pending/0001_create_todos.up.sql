-- Périmètre Todo — création de la table. Réversible via 0001_create_todos.down.sql (gate plancher G2).
-- SQL portable : pas de NOW()/AUTO_INCREMENT (les id sont des UUID générés en application).
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
