/**
 * Database / schema names for every object the app reads.
 *
 * Single source of truth — mirrors the repo's config.env so the app and the SQL
 * deploy scripts agree. Defaults reproduce the reference deployment; override any
 * of them with the matching environment variable (e.g. in server/.env) to point
 * the app at a differently-named deployment in your own account.
 */

export const EMR_DB = process.env.EMR_DB || 'CLINICAL_EMR';
export const EMR_SCHEMA = process.env.EMR_SCHEMA || 'EHR';

// The ontology lives as a schema inside the EMR database by default.
export const ONTOLOGY_DB = process.env.ONTOLOGY_DB || EMR_DB;
export const ONTOLOGY_SCHEMA = process.env.ONTOLOGY_SCHEMA || 'ONTOLOGY';

export const CLAIMS_DB = process.env.CLAIMS_DB || 'PAYER_CLAIMS';
export const CLAIMS_SCHEMA = process.env.CLAIMS_SCHEMA || 'CLAIMS';

export const RX_DB = process.env.RX_DB || 'PHARMACY_OPS';
export const RX_SCHEMA = process.env.RX_SCHEMA || 'RX';

// Fully-qualified DB.SCHEMA prefixes for building queries.
export const EHR = `${EMR_DB}.${EMR_SCHEMA}`;
export const CLAIMS = `${CLAIMS_DB}.${CLAIMS_SCHEMA}`;
export const RX = `${RX_DB}.${RX_SCHEMA}`;
export const ONTOLOGY = `${ONTOLOGY_DB}.${ONTOLOGY_SCHEMA}`;

/** Compact object handy for /api/health and logging. */
export const DB_NAMES = { EMR_DB, EMR_SCHEMA, ONTOLOGY_DB, ONTOLOGY_SCHEMA, CLAIMS_DB, CLAIMS_SCHEMA, RX_DB, RX_SCHEMA };
