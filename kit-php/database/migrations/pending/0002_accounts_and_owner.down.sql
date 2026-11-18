-- Réversion de 0002_accounts_and_owner.up.sql (gate plancher G2 : toute migration a son down).
-- Le propriétaire des tâches est perdu : les tâches redeviennent visibles de tous.
ALTER TABLE todos DROP KEY idx_todos_owner_created;

ALTER TABLE todos DROP COLUMN owner_id;

DROP TABLE access_tokens;

DROP TABLE accounts;
