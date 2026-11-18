-- Identité et cloisonnement (ADR-001) : comptes, jetons, essais de connexion, propriétaire des todos.
-- Réversible via 0002_accounts_and_owner.down.sql. SQL portable (dates fournies par l'application).
-- Aucun compte n'est posé ici : pas de compte de démonstration à mot de passe connu.
CREATE TABLE accounts (
  id VARCHAR(64) NOT NULL PRIMARY KEY,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

-- Sessions (cookie) et jetons porteurs : même table, colonne `kind`. Seule l'empreinte du jeton
-- est conservée ; supprimer la ligne révoque le jeton.
CREATE TABLE auth_tokens (
  token_hash CHAR(64) NOT NULL PRIMARY KEY,
  account_id VARCHAR(64) NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  kind VARCHAR(16) NOT NULL CHECK (kind IN ('session', 'bearer')),
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_auth_tokens_expires_at ON auth_tokens (expires_at);

-- Essais de connexion échoués ; `subject` est l'empreinte du courriel visé, pas le courriel.
CREATE TABLE login_attempts (
  id VARCHAR(64) NOT NULL PRIMARY KEY,
  subject CHAR(64) NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_login_attempts_subject ON login_attempts (subject, attempted_at);

-- Propriétaire. Un todo créé avant cette migration n'a pas de propriétaire : il reste en base,
-- visible de personne, jusqu'à ce que `python -m app.accounts adopt <courriel>` le rattache.
-- L'application, elle, n'écrit jamais de todo sans propriétaire (invariant du domaine).
ALTER TABLE todos ADD COLUMN owner_id VARCHAR(64) REFERENCES accounts (id) ON DELETE CASCADE;
CREATE INDEX idx_todos_owner ON todos (owner_id, created_at);
