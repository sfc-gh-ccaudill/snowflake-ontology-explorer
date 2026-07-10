-- ===========================================================================
-- teardown.sql — remove the entire demo from your account.
--
-- Rendered by deploy.sh (database names come from config.env). Prefer:
--   ./deploy.sh teardown      (adds a confirmation prompt)
--
-- Dropping CLINICAL_EMR also removes the ONTOLOGY schema, since the ontology is
-- built as a schema inside the EMR database. If you deployed the ontology into
-- a SEPARATE database (ONTOLOGY_DB != EMR_DB), drop that database too.
-- ===========================================================================
DROP DATABASE IF EXISTS CLINICAL_EMR;   -- source EMR + ontology schema
DROP DATABASE IF EXISTS PAYER_CLAIMS;   -- source claims
DROP DATABASE IF EXISTS PHARMACY_OPS;   -- source pharmacy
