-- Périmètre Todo — création de la table. Réversible via 0001_create_todos.down.sql (gate plancher G2).
-- SQL portable : pas de NOW()/SERIAL (les id sont des UUID générés en application).
CREATE TABLE IF NOT EXISTS todos (
  id VARCHAR(64) NOT NULL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos (created_at);
