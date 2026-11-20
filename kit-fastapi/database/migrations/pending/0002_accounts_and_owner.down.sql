-- Réversion de 0002_accounts_and_owner.up.sql (gate plancher G2). Les todos redeviennent sans
-- propriétaire ; comptes, jetons et essais sont supprimés.
DROP INDEX IF EXISTS idx_todos_owner;
ALTER TABLE todos DROP COLUMN IF EXISTS owner_id;
DROP TABLE IF EXISTS login_attempts;
DROP TABLE IF EXISTS auth_tokens;
DROP TABLE IF EXISTS accounts;
