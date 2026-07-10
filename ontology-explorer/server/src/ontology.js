/**
 * Canonical ontology definition for the "messy healthcare data" demo.
 *
 * This is a hand-authored model derived from README.md + the sql/ source
 * scripts. It renders a meaningful, explorable graph TODAY, before the live
 * ontology layer (semantic view / KG tables) exists.
 *
 * When the real ontology is ready, replace `getOntology()` with a query that
 * reads nodes/edges from the ontology layer — the API shape below is all the
 * frontend depends on.
 */

import {
  EMR_DB, EMR_SCHEMA, CLAIMS_DB, CLAIMS_SCHEMA, RX_DB, RX_SCHEMA,
  ONTOLOGY_DB, ONTOLOGY_SCHEMA, EHR,
} from './dbconfig.js';

export const GROUPS = {
  person: { label: 'People', color: '#29B5E8' },
  clinical: { label: 'Clinical', color: '#7442BF' },
  medication: { label: 'Medication', color: '#2FA84F' },
  financial: { label: 'Financial', color: '#F59F3B' },
  place: { label: 'Place', color: '#11567F' },
};

const NODES = [
  {
    id: 'Patient',
    label: 'Patient',
    group: 'person',
    description:
      'A person receiving care. The same real-world person appears in all three source systems under different identifiers and name formats; the ontology resolves them into one Patient node.',
    properties: [
      { name: 'patientId', description: 'Canonical resolved identity' },
      { name: 'name', description: 'Reconciled from discrete parts, "LAST, FIRST M", and nicknames' },
      { name: 'dob', description: 'Date of birth (weak identity key when SSN is null)' },
      { name: 'sex', description: 'Canonicalized from M/F and 1/2 encodings' },
      { name: 'ssn', description: 'Medium-strength cross-system link (null for some members)' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PATIENT_MASTER', note: 'MRN; discrete name parts' },
      { system: CLAIMS_DB, table: 'MEMBER / SUBSCRIBER', note: '"LAST, FIRST M"' },
      { system: RX_DB, table: 'SUBSCRIBER', note: 'nicknames (Bob, Jim, Beth…)' },
      { system: RX_DB, table: 'PHARMACY_FILL', note: 'referenced — patient on the fill' },
    ],
    sampleQuery:
      'select MRN, FIRST_NAME, LAST_NAME, DOB, SEX, SSN from CLINICAL_EMR.EHR.PATIENT_MASTER limit 8',
  },
  {
    id: 'Practitioner',
    label: 'Practitioner',
    group: 'person',
    description:
      'A clinician. Keyed on NPI (the one universal join key), which resolves "Sarah Chen, MD" / "CHEN, SARAH" / "S CHEN" into a single provider.',
    properties: [
      { name: 'npi', description: 'National Provider Identifier — universal key' },
      { name: 'name', description: 'Varied formats treated as attributes' },
      { name: 'specialty', description: 'Normalized (e.g. "Internal Medicine" == "INTERNAL MED")' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PHYSICIAN', note: 'NPI + "Sarah Chen, MD"' },
      { system: CLAIMS_DB, table: 'RENDERING_PROVIDER', note: 'RENDERING_NPI + "CHEN, SARAH"' },
      { system: RX_DB, table: 'PRESCRIBER', note: 'PRESCRIBER_ID + "S CHEN"' },
      { system: EMR_DB, table: 'PATIENT_MASTER', note: 'referenced — PCP (PCP_NPI)' },
      { system: EMR_DB, table: 'VISIT', note: 'referenced — rendering provider on the encounter' },
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'referenced — rendering provider on the claim' },
      { system: RX_DB, table: 'PHARMACY_FILL', note: 'referenced — prescriber on the fill' },
    ],
    sampleQuery:
      'select PHYSICIAN_ID, NPI, FULL_NAME, SPECIALTY from CLINICAL_EMR.EHR.PHYSICIAN limit 8',
  },
  {
    id: 'RelatedPerson',
    label: 'Related Person',
    group: 'person',
    description:
      'Next-of-kin / emergency contact. Embedded as KIN_* columns inside the overloaded PATIENT_MASTER row and decomposed into its own node.',
    properties: [
      { name: 'name', description: 'KIN_NAME' },
      { name: 'relationship', description: 'Spouse / Parent / Child' },
      { name: 'phone', description: 'KIN_PHONE' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PATIENT_MASTER', note: 'KIN_NAME, KIN_RELATION, KIN_PHONE' },
    ],
    sampleQuery:
      'select MRN, KIN_NAME, KIN_RELATION, KIN_PHONE from CLINICAL_EMR.EHR.PATIENT_MASTER limit 8',
  },
  {
    id: 'Address',
    label: 'Address',
    group: 'place',
    description:
      'A postal address. Extracted from inline ADDR_* columns on the patient row into a first-class node.',
    properties: [
      { name: 'line1', description: 'ADDR_LINE1' },
      { name: 'city', description: 'CITY' },
      { name: 'state', description: 'STATE' },
      { name: 'zip', description: 'ZIP' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PATIENT_MASTER', note: 'ADDR_LINE1, CITY, STATE, ZIP' },
    ],
    sampleQuery:
      'select MRN, ADDR_LINE1, CITY, STATE, ZIP from CLINICAL_EMR.EHR.PATIENT_MASTER limit 8',
  },
  {
    id: 'Location',
    label: 'Location',
    group: 'place',
    description:
      'Where care is delivered. The EMR names it (DEPARTMENT); claims encode it as a numeric POS code (11 = Office). The ontology resolves POS → Location.',
    properties: [
      { name: 'name', description: 'Department / facility name' },
      { name: 'facility', description: 'FACILITY_NAME' },
      { name: 'posCode', description: 'Place-of-service code from claims' },
    ],
    mappings: [
      { system: EMR_DB, table: 'DEPARTMENT', note: 'named clinic + facility' },
      { system: CLAIMS_DB, table: 'PLACE_OF_SERVICE', note: 'numeric POS code' },
      { system: EMR_DB, table: 'VISIT', note: 'referenced — department of the encounter' },
    ],
    sampleQuery:
      'select DEPT_ID, DEPT_NAME, FACILITY_NAME, CITY, STATE from CLINICAL_EMR.EHR.DEPARTMENT limit 8',
  },
  {
    id: 'Encounter',
    label: 'Encounter',
    group: 'clinical',
    description:
      'A clinical visit. The VISIT row is heavily overloaded — it also carries provider, department, the primary diagnosis, and vital-sign observations as wide columns.',
    properties: [
      { name: 'encounterId', description: 'VISIT_ID' },
      { name: 'date', description: 'VISIT_DATE' },
      { name: 'type', description: 'VISIT_TYPE' },
      { name: 'status', description: 'Encounter status (Completed) — not to be confused with other STATUS columns' },
    ],
    mappings: [
      { system: EMR_DB, table: 'VISIT', note: 'Encounter + Provider + Location + Condition + Observation' },
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'aligned by patient + NPI + service date' },
    ],
    sampleQuery:
      'select VISIT_ID, MRN, PHYSICIAN_ID, DEPT_ID, VISIT_DATE, VISIT_TYPE, PRIMARY_ICD10, STATUS from CLINICAL_EMR.EHR.VISIT limit 8',
  },
  {
    id: 'Condition',
    label: 'Condition',
    group: 'clinical',
    description:
      'A diagnosis / problem. ICD-10 appears WITH decimals in the EMR (E11.9) and WITHOUT in claims (E119); the ontology canonicalizes so both match.',
    properties: [
      { name: 'icd10', description: 'Canonicalized ICD-10 code' },
      { name: 'description', description: 'ICD10_DESC' },
      { name: 'snomed', description: 'SNOMED_CODE (EMR only)' },
      { name: 'status', description: 'Problem status (Active)' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PROBLEM_LIST', note: 'ICD-10 with decimal + SNOMED' },
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'ICD-10 without decimal' },
      { system: EMR_DB, table: 'VISIT', note: 'referenced — primary dx of the encounter' },
    ],
    sampleQuery:
      'select PROBLEM_ID, MRN, ICD10_CODE, ICD10_DESC, SNOMED_CODE, STATUS from CLINICAL_EMR.EHR.PROBLEM_LIST limit 8',
  },
  {
    id: 'Observation',
    label: 'Observation',
    group: 'clinical',
    description:
      'A measurement (vital sign or lab). Stored WIDE — one column per analyte in LAB_RESULTS and per vital in VISIT. Each populated cell becomes one Observation node (unpivot).',
    properties: [
      { name: 'code', description: 'What was measured (e.g. HbA1c, LDL, systolic BP)' },
      { name: 'value', description: 'Numeric result' },
      { name: 'unit', description: 'Unit of measure' },
      { name: 'date', description: 'Collection / visit date' },
    ],
    mappings: [
      { system: EMR_DB, table: 'LAB_RESULTS', note: 'wide analyte columns' },
      { system: EMR_DB, table: 'VISIT', note: 'wide vital-sign columns' },
    ],
    sampleQuery:
      'select LAB_ID, MRN, COLLECT_DATE, GLUCOSE_MGDL, HBA1C_PCT, LDL_MGDL, CREATININE_MGDL, EGFR from CLINICAL_EMR.EHR.LAB_RESULTS limit 8',
  },
  {
    id: 'Medication',
    label: 'Medication',
    group: 'medication',
    description:
      'A drug concept. EMR uses generic name + RxNorm; pharmacy uses brand + NDC. NDC_PRODUCT is the crosswalk that normalizes both to a canonical RxNorm concept — even when RxNorm is null.',
    properties: [
      { name: 'rxnorm', description: 'Canonical RxNorm concept' },
      { name: 'ndc', description: 'NDC (pharmacy side)' },
      { name: 'genericName', description: 'e.g. Atorvastatin 20 mg' },
      { name: 'brandName', description: 'e.g. Lipitor 20mg' },
    ],
    mappings: [
      { system: EMR_DB, table: 'MEDICATION', note: 'generic + RxNorm (nullable)' },
      { system: RX_DB, table: 'NDC_PRODUCT', note: 'RxNorm ↔ NDC crosswalk + brand' },
      { system: RX_DB, table: 'PHARMACY_FILL', note: 'referenced — dispensed product' },
    ],
    sampleQuery:
      'select distinct DRUG_NAME, RXNORM_CODE from CLINICAL_EMR.EHR.MEDICATION order by DRUG_NAME limit 8',
  },
  {
    id: 'MedicationRequest',
    label: 'Medication Request',
    group: 'medication',
    description:
      'A prescription order written by a practitioner. Extracted from the overloaded PHARMACY_FILL row (request + dispense + medication + patient + prescriber).',
    properties: [
      { name: 'orderId', description: 'MED_ORDER_ID' },
      { name: 'orderDate', description: 'ORDER_DATE' },
      { name: 'sig', description: 'Dosing instructions' },
      { name: 'refills', description: 'Authorized refills' },
    ],
    mappings: [
      { system: EMR_DB, table: 'MEDICATION', note: 'the order itself' },
      { system: RX_DB, table: 'PHARMACY_FILL', note: 'MedicationRequest facet' },
    ],
    sampleQuery:
      'select MED_ORDER_ID, MRN, PHYSICIAN_ID, ORDER_DATE, DRUG_NAME, SIG, REFILLS from CLINICAL_EMR.EHR.MEDICATION limit 8',
  },
  {
    id: 'MedicationDispense',
    label: 'Medication Dispense',
    group: 'medication',
    description:
      'The actual fill / dispense event at the pharmacy. The path from an EMR order with a NULL RxNorm to the dispensed product runs through this node.',
    properties: [
      { name: 'fillStatus', description: 'Dispensed / Pending' },
      { name: 'quantity', description: 'Quantity dispensed' },
      { name: 'ndc', description: 'Product actually dispensed' },
    ],
    mappings: [
      { system: RX_DB, table: 'PHARMACY_FILL', note: 'MedicationDispense facet' },
    ],
  },
  {
    id: 'Coverage',
    label: 'Coverage',
    group: 'financial',
    description:
      'Insurance coverage. Embedded inline in the EMR patient row (INS_*) and modeled explicitly in claims (plan / group). INS_MEMBER_ID is the strong link between EMR and claims.',
    properties: [
      { name: 'payer', description: 'INS_PAYER_NAME (e.g. Buckeye Health Plan)' },
      { name: 'memberId', description: 'INS_MEMBER_ID == MEMBER.MEMBER_ID (strong key)' },
      { name: 'group', description: 'INS_GROUP' },
    ],
    mappings: [
      { system: EMR_DB, table: 'PATIENT_MASTER', note: 'INS_PAYER_NAME, INS_MEMBER_ID, INS_GROUP' },
      { system: CLAIMS_DB, table: 'MEMBER', note: 'plan / group' },
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'referenced — coverage on the claim' },
    ],
    sampleQuery:
      'select MRN, INS_PAYER_NAME, INS_MEMBER_ID, INS_GROUP from CLINICAL_EMR.EHR.PATIENT_MASTER limit 8',
  },
  {
    id: 'Claim',
    label: 'Claim',
    group: 'financial',
    description:
      'A billing claim submitted to the payer. Decomposed from the overloaded CLAIMS_LINE row along with its lines, procedures, diagnoses, provider, and coverage.',
    properties: [
      { name: 'claimId', description: 'Claim identifier' },
      { name: 'status', description: 'Adjudication status (Paid / Denied)' },
      { name: 'serviceDate', description: 'Date of service' },
    ],
    mappings: [
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'Claim facet' },
    ],
  },
  {
    id: 'ClaimLine',
    label: 'Claim Line',
    group: 'financial',
    description:
      'A single line item on a claim: one procedure, its diagnosis pointer, charge, and adjudication result.',
    properties: [
      { name: 'lineNumber', description: 'Line sequence' },
      { name: 'charge', description: 'Billed amount' },
      { name: 'claimStatus', description: 'Line-level Paid / Denied' },
    ],
    mappings: [
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'ClaimLine facet' },
    ],
  },
  {
    id: 'Procedure',
    label: 'Procedure',
    group: 'financial',
    description: 'A billed procedure (CPT / HCPCS) referenced by a claim line.',
    properties: [
      { name: 'cpt', description: 'CPT / HCPCS code' },
      { name: 'description', description: 'Procedure description' },
    ],
    mappings: [
      { system: CLAIMS_DB, table: 'CLAIMS_LINE', note: 'CPT / HCPCS' },
    ],
  },
];

const LINKS = [
  { source: 'Patient', target: 'Coverage', label: 'has coverage' },
  { source: 'Patient', target: 'Address', label: 'has address' },
  { source: 'Patient', target: 'RelatedPerson', label: 'related to' },
  { source: 'Patient', target: 'Encounter', label: 'subject of' },
  { source: 'Patient', target: 'Claim', label: 'subject of' },
  { source: 'Patient', target: 'MedicationRequest', label: 'subject of' },
  { source: 'Encounter', target: 'Practitioner', label: 'performed by' },
  { source: 'Encounter', target: 'Location', label: 'at' },
  { source: 'Encounter', target: 'Condition', label: 'has diagnosis' },
  { source: 'Encounter', target: 'Observation', label: 'has observation' },
  { source: 'Claim', target: 'ClaimLine', label: 'has line' },
  { source: 'ClaimLine', target: 'Procedure', label: 'has procedure' },
  { source: 'ClaimLine', target: 'Condition', label: 'has diagnosis' },
  { source: 'ClaimLine', target: 'Coverage', label: 'covered by' },
  { source: 'ClaimLine', target: 'Practitioner', label: 'rendered by' },
  { source: 'MedicationRequest', target: 'Practitioner', label: 'prescribed by' },
  { source: 'MedicationRequest', target: 'Medication', label: 'of drug' },
  { source: 'MedicationRequest', target: 'MedicationDispense', label: 'fulfilled by' },
  { source: 'MedicationDispense', target: 'Medication', label: 'of drug' },
];

/** Returns the ontology graph in the shape the frontend expects. */
export function getOntology() {
  const nodes = NODES.map((n) => ({
    id: n.id,
    label: n.label,
    group: n.group,
    color: GROUPS[n.group]?.color,
    degree: LINKS.filter((l) => l.source === n.id || l.target === n.id).length,
  }));
  return { nodes, links: LINKS, groups: GROUPS };
}

/** Returns full detail for a single class (used by the Inspector panel). */
export function getNodeDetail(id) {
  const node = NODES.find((n) => n.id === id);
  if (!node) return null;
  const relationships = LINKS.filter((l) => l.source === id || l.target === id).map((l) => ({
    label: l.label,
    direction: l.source === id ? 'out' : 'in',
    other: l.source === id ? l.target : l.source,
  }));
  return { ...node, color: GROUPS[node.group]?.color, groupLabel: GROUPS[node.group]?.label, relationships };
}

export function getNodeSampleQuery(id) {
  return NODES.find((n) => n.id === id)?.sampleQuery?.replaceAll('CLINICAL_EMR.EHR.', `${EHR}.`) || null;
}

/* =========================================================================
   Source-system model — the three ORIGINAL databases, for side-by-side
   comparison against the ontology above.
   ========================================================================= */

export const SOURCE_SYSTEMS = [
  {
    db: EMR_DB,
    schema: EMR_SCHEMA,
    label: 'Clinical EMR',
    color: '#29B5E8',
    description: 'Electronic medical record. Calls a person a PATIENT (MRN) and a clinician a PHYSICIAN.',
    tables: [
      { name: 'PATIENT_MASTER', description: 'One row overloaded with Patient + Address + PCP + Coverage + next-of-kin.', overloaded: true },
      { name: 'PHYSICIAN', description: 'Clinicians with a local id and NPI; free-text name "Sarah Chen, MD".' },
      { name: 'DEPARTMENT', description: 'Named clinics / facilities.' },
      { name: 'VISIT', description: 'Overloaded encounter: also carries provider, department, primary dx, and vitals as wide columns.', overloaded: true },
      { name: 'PROBLEM_LIST', description: 'Diagnoses — ICD-10 WITH decimals, plus a SNOMED code.' },
      { name: 'MEDICATION', description: 'Drug orders — generic name + RxNorm (sometimes NULL).' },
      { name: 'LAB_RESULTS', description: 'Wide labs — one column per analyte; each cell is really an Observation.' },
    ],
  },
  {
    db: CLAIMS_DB,
    schema: CLAIMS_SCHEMA,
    label: 'Payer Claims',
    color: '#F59F3B',
    description: 'Health plan / claims. Calls a person a MEMBER / SUBSCRIBER and a clinician a RENDERING_PROVIDER.',
    tables: [
      { name: 'MEMBER', description: 'Members / subscribers and their plan + group (coverage).' },
      { name: 'RENDERING_PROVIDER', description: 'Providers keyed on NPI; name as "CHEN, SARAH" (apostrophes dropped).' },
      { name: 'PLACE_OF_SERVICE', description: 'Numeric POS codes (11 = Office) — the claims notion of Location.' },
      { name: 'CLAIMS_LINE', description: 'Overloaded: Claim + ClaimLine + Procedure + Diagnosis + Provider + Coverage + Member.', overloaded: true },
    ],
  },
  {
    db: RX_DB,
    schema: RX_SCHEMA,
    label: 'Pharmacy Ops',
    color: '#2FA84F',
    description: 'Pharmacy / dispensing. Calls a person a SUBSCRIBER (Rx member) and a clinician a PRESCRIBER.',
    tables: [
      { name: 'SUBSCRIBER', description: 'Rx members stored under nicknames (Bob, Jim, Beth…); SSN null for some.' },
      { name: 'PRESCRIBER', description: 'Prescribers with a compact name "S CHEN"; id equals the NPI.' },
      { name: 'NDC_PRODUCT', description: 'The RxNorm ↔ NDC crosswalk + brand names.' },
      { name: 'PHARMACY_FILL', description: 'Overloaded: MedicationRequest + MedicationDispense + Medication + Patient + Prescriber.', overloaded: true },
    ],
  },
];

/** Colour + label for each kind of cross-system linkage key. */
export const LINKAGE_KINDS = {
  patient: { label: 'Patient id (system-local)', color: '#8595a6' },
  person: { label: 'SSN — person link (medium)', color: '#7442BF' },
  coverage: { label: 'Member id — EMR↔claims (strong)', color: '#F59F3B' },
  provider: { label: 'NPI — provider link (universal)', color: '#11567F' },
  drug: { label: 'RxNorm / NDC — drug crosswalk', color: '#2FA84F' },
};

/** Tags a column as a cross-system linkage key (or null). */
export function classifyColumn(name) {
  const u = String(name).toUpperCase();
  if (u.includes('SSN')) return { kind: 'person', label: 'SSN · person link across all 3 systems (null for some)' };
  if (u.includes('NPI') || u === 'PRESCRIBER_ID') return { kind: 'provider', label: 'NPI · universal provider key' };
  if (u === 'INS_MEMBER_ID' || u === 'MEMBER_ID') return { kind: 'coverage', label: 'Member id · strong EMR↔claims link' };
  if (u === 'RX_MEMBER_ID') return { kind: 'coverage', label: 'Rx member id · NOT the claims member id' };
  if (u.includes('RXNORM')) return { kind: 'drug', label: 'RxNorm · drug crosswalk key' };
  if (u.includes('NDC')) return { kind: 'drug', label: 'NDC · drug crosswalk key' };
  if (u === 'MRN') return { kind: 'patient', label: 'MRN · EMR patient id' };
  return null;
}

/** Ontology classes that a given source table decomposes into. */
function classesForTable(systemDb, tableName) {
  return NODES.filter((n) =>
    n.mappings.some(
      (m) =>
        m.system === systemDb &&
        m.table.split(/[/,]/).map((t) => t.trim()).includes(tableName)
    )
  ).map((n) => ({ id: n.id, label: n.label, color: GROUPS[n.group]?.color }));
}

/** The source model with each table annotated with the ontology classes it maps to. */
export function getSourceModel() {
  return SOURCE_SYSTEMS.map((sys) => ({
    ...sys,
    tables: sys.tables.map((t) => ({
      ...t,
      classes: classesForTable(sys.db, t.name),
    })),
  }));
}

/**
 * Layer-2 ontology metadata objects (all in CLINICAL_EMR.ONTOLOGY), grouped into
 * lanes by purpose. These are the tables that DEFINE the ontology.
 */
export const ONTOLOGY_METADATA = [
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Classes & properties', color: '#8b5cf6',
    description: 'The class hierarchy and the attributes each class carries.',
    tables: [
      { name: 'ONT_CLASS', description: 'Every ontology class + its parent (the type hierarchy).' },
      { name: 'ONT_PROPERTY', description: 'Scalar attributes declared on a class.' },
      { name: 'ONT_SHARED_PROPERTY', description: 'Properties shared across multiple classes.' },
      { name: 'ONT_DERIVED_PROPERTY', description: 'Computed / derived attributes.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Relations & mappings', color: '#7c3aed',
    description: 'How classes relate, and how each maps back to source tables.',
    tables: [
      { name: 'ONT_RELATION_DEF', description: 'Typed relationships between classes (treated, prescribed…).' },
      { name: 'ONT_REL_MAP', description: 'Maps a relation to the source join that populates it.' },
      { name: 'ONT_CLASS_MAP', description: 'Maps a class to its backing source object(s).' },
      { name: 'ONT_LINK_SOURCE', description: 'Source columns that link entities across systems.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Sources & identity', color: '#a855f7',
    description: 'Provenance + the rules that resolve one entity across systems.',
    tables: [
      { name: 'ONT_OBJECT_SOURCE', description: 'Which source table/column each class draws from.' },
      { name: 'ONT_IDENTITY_RULE', description: 'Entity-resolution rules (NPI, member id, SSN→DOB…).' },
      { name: 'ONT_RULE', description: 'Declarative constraints / logic rules.' },
      { name: 'ONT_CONSTRAINT_VIOLATION', description: 'Rows that violated an ontology constraint.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'View & action defs', color: '#6d5bd0',
    description: 'The specs the generator reads to emit Layer-3 views.',
    tables: [
      { name: 'OBJ_VIEW_DEF', description: 'Definition of each generated view.' },
      { name: 'OBJ_VIEW_FIELD', description: 'Column-level spec for each generated view.' },
      { name: 'ACT_DEF', description: 'Action / function definitions.' },
      { name: 'ACT_TYPE', description: 'Action type catalog.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Knowledge-graph store', color: '#0ea5a4',
    description: 'The resolved graph the ontology is materialized into.',
    tables: [
      { name: 'KG_NODE', description: 'Canonical resolved entities (one row per real-world thing).' },
      { name: 'KG_EDGE', description: 'Typed relationships between canonical nodes.' },
      { name: 'REL_EDGE_INFERRED', description: 'Edges inferred by resolution rules.' },
    ],
  },
];

/** Layer-3 generated views (CLINICAL_EMR.ONTOLOGY), grouped by kind. */
export const GENERATED_VIEWS = [
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Entity views', color: '#29b5e8',
    description: 'One resolved view per ontology class.',
    tables: [
      { name: 'V_PATIENT', description: 'Canonical patients (one row per person across systems).' },
      { name: 'V_PRACTITIONER', description: 'Canonical clinicians keyed by NPI.' },
      { name: 'V_ENCOUNTER', description: 'Resolved clinical encounters.' },
      { name: 'V_MEDICATION', description: 'Canonical drugs keyed by RxNorm.' },
      { name: 'V_CONDITION', description: 'Diagnoses on canonical (dotted) ICD-10.' },
      { name: 'V_CLAIM', description: 'Resolved claims.' },
      { name: 'V_COVERAGE', description: 'Coverage / plan membership.' },
      { name: 'V_PROCEDURE', description: 'Procedures keyed by CPT.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Relationship views', color: '#1e9fd0',
    description: 'Resolved edges between entities.',
    tables: [
      { name: 'V_ENCOUNTER_PERFORMED_BY', description: 'Encounter → Practitioner.' },
      { name: 'V_ENCOUNTER_OF_PATIENT', description: 'Encounter → Patient.' },
      { name: 'V_PATIENT_HAS_CONDITION', description: 'Patient → Condition.' },
      { name: 'V_MEDREQUEST_FOR_MEDICATION', description: 'MedicationRequest → Medication.' },
      { name: 'V_DISPENSE_OF_MEDICATION', description: 'MedicationDispense → Medication.' },
      { name: 'V_CLAIM_RENDERED_BY', description: 'Claim → rendering Practitioner.' },
    ],
  },
  {
    db: ONTOLOGY_DB, schema: ONTOLOGY_SCHEMA, label: 'Resolved & hierarchy', color: '#11567f',
    description: 'Unified entity/edge feeds and class-hierarchy helpers.',
    tables: [
      { name: 'VW_ONT_ALL_ENTITIES', description: 'All resolved entities across every class.' },
      { name: 'REL_RESOLVED', description: 'All resolved edges (src/dst joined to entities).' },
      { name: 'VW_ONT_HIERARCHY_STATS', description: 'Per-class instance + relationship counts.' },
      { name: 'VW_ANCESTORS', description: 'Transitive superclasses of each class.' },
      { name: 'VW_DESCENDANTS', description: 'Transitive subclasses of each class.' },
    ],
  },
];

/** All three selectable datasets for the Source Data page. */
export function getSourceDatasets() {
  return [
    { key: 'raw', label: 'Raw tables', description: 'The three original source databases, exactly as each stores its data.', systems: getSourceModel() },
    { key: 'metadata', label: 'Ontology metadata', description: 'The metadata tables that DEFINE the ontology — classes, relations, identity rules, view specs.', systems: withEmptyClasses(ONTOLOGY_METADATA) },
    { key: 'views', label: 'Generated views', description: 'The views the ontology generates from its metadata — resolved entities and relationships.', systems: withEmptyClasses(GENERATED_VIEWS) },
  ];
}

function withEmptyClasses(model) {
  return model.map((s) => ({ ...s, tables: s.tables.map((t) => ({ ...t, classes: [] })) }));
}

/** True if db.schema.table is one of the objects we expose (guards ad-hoc sampling). */
export function isKnownObject(db, schema, table) {
  const all = [SOURCE_SYSTEMS, ONTOLOGY_METADATA, GENERATED_VIEWS].flat();
  return all.some(
    (s) => s.db === db && s.schema === schema && s.tables.some((t) => t.name === table)
  );
}


/** Alignment challenges (condensed from README) for the overview dashboard. */
export const CHALLENGES = [
  { id: 1, title: 'Overloaded tables', blurb: 'One table smears across many classes — PATIENT_MASTER→5, VISIT→5, CLAIMS_LINE→7, PHARMACY_FILL→5. The ontology decomposes each row into clean class instances.' },
  { id: 2, title: 'Same entity, different names', blurb: 'Patient = MEMBER = SUBSCRIBER; Practitioner = RENDERING_PROVIDER = PRESCRIBER. One canonical class collapses the synonyms.' },
  { id: 3, title: 'Identity with imperfect keys', blurb: 'No single patient key: SSN is null for some, pharmacy uses nicknames, and RX_MEMBER_ID ≠ claims MEMBER_ID. Resolve from a hierarchy of keys.' },
  { id: 4, title: 'Provider name formats', blurb: '"Sarah Chen, MD" vs "CHEN, SARAH" vs "S CHEN". NPI is the one universal key; the varied names become attributes.' },
  { id: 5, title: 'Drug identity via crosswalk', blurb: 'EMR uses generic + RxNorm; pharmacy uses brand + NDC. NDC_PRODUCT stitches them — even when RxNorm is NULL.' },
  { id: 6, title: 'Divergent conventions', blurb: 'ICD-10 with vs without the decimal (E11.9 / E119), sex M/F vs 1/2, named department vs numeric POS. Canonicalize so filters match.' },
  { id: 7, title: 'Overloaded column names', blurb: 'STATUS means problem status, encounter status, adjudication, or dispense status depending on the table — a trap for keyword agents.' },
  { id: 8, title: 'Different grain (wide vs long)', blurb: 'Wide LAB_RESULTS / VISIT columns become individual Observation nodes with a common (code, value, unit, date) shape.' },
];

export function getOverview() {
  const graph = getOntology();
  return {
    sourceSystems: SOURCE_SYSTEMS.length,
    sourceTables: SOURCE_SYSTEMS.reduce((n, s) => n + s.tables.length, 0),
    classes: graph.nodes.length,
    relationships: graph.links.length,
    challenges: CHALLENGES,
  };
}
