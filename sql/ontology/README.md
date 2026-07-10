# The ontology — `sql/ontology/`

The SQL that **builds** the `HEALTHCARE_ONTOLOGY` stack on top of the three source systems
loaded by [`../data/01_clinical_emr.sql`](../data/01_clinical_emr.sql),
[`../data/02_payer_claims.sql`](../data/02_payer_claims.sql), and
[`../data/03_pharmacy_ops.sql`](../data/03_pharmacy_ops.sql).

`./deploy.sh` runs these after the data loads. They build, by default, into
`CLINICAL_EMR.ONTOLOGY` — override the names in `config.env` (`deploy.sh render` substitutes
your configured names). It follows the *Ontology-on-Snowflake* Knowledge-Graph pattern: a
physical KG (`KG_NODE` / `KG_EDGE`) with cross-system entity resolution, ~26 metadata tables
that make the ontology self-describing, typed + abstract views, four Cortex Analyst semantic
views, and Cortex Agents that route across them.

> **To deploy:** run `./deploy.sh` from the repo root. To run by hand, `./deploy.sh render`
> writes ready-to-run copies (with your configured names) into `./build/`, or paste the files
> below into a worksheet. Build role needs `CREATE DATABASE` (e.g. `SYSADMIN`).

## Files & run order

Run in order — later phases depend on earlier ones.

| # | File | Phase | Creates |
|---|------|-------|---------|
| 1 | [`01_phase4_layers_1-3.sql`](01_phase4_layers_1-3.sql) | 4 — Layers 1–3 | `KG_NODE`/`KG_EDGE` + cross-system resolution load, `FN_ICD10_DOTTED`, 8 `STG_*` staging views, ~26 `ONT_*`/`ACT_*`/`OBJ_*` metadata tables + seed, 48 `V_*` concrete views, 20 `VW_ONT_*` + `REL_RESOLVED` + 4 hierarchy views, `SP_GENERATE_ONTOLOGY_VIEWS`, 5 inference SPs, 4 graph-traversal UDFs, `ONT_IDENTITY_RULE` + provenance |
| 2 | [`02_phase4.5_base_semantic_view.sql`](02_phase4.5_base_semantic_view.sql) | 4.5 — Base semantic view | `HEALTHCARE_ONTOLOGY_BASE` (15 raw source tables, 19 relationships) |
| 3 | [`03_phase5_ontology_layer_semantic_views.sql`](03_phase5_ontology_layer_semantic_views.sql) | 5 — Ontology-layer semantic views | `HEALTHCARE_ONTOLOGY_KG_MODEL` (entity star, 22 rels), `_ONTOLOGY_MODEL` (2 rels), `_METADATA_MODEL` (3 rels) |
| 4 | [`04_phase6_cortex_agents.sql`](04_phase6_cortex_agents.sql) | 6 — Cortex Agents | `HEALTHCARE_ONTOLOGY_AGENT` (8 tools) and `HEALTHCARE_BASE_AGENT` (baseline, 1 tool) |

Two helper scripts round out the folder (also rendered by `deploy.sh`):

| File | Purpose |
|------|---------|
| [`verify.sql`](verify.sql) | Post-deploy count assertions (KG_NODE, KG_EDGE, ONT_* tables) + `SHOW SEMANTIC VIEWS` / `SHOW AGENTS`. Run via `./deploy.sh verify`. |
| [`teardown.sql`](teardown.sql) | Drops the three demo databases. Run via `./deploy.sh teardown` (adds a confirmation prompt). |

---

# Reference: what you build

Object names below use the default schema `CLINICAL_EMR.ONTOLOGY`; substitute your `config.env`
values if you renamed things.

## Class model (22 classes)

```
Entity (abstract)
├── Person (abstract)
│   ├── Patient          ← PATIENT_MASTER + MEMBER + SUBSCRIBER   (canonical key: PATIENT_KEY = MRN)
│   ├── Practitioner     ← PHYSICIAN + RENDERING_PROVIDER + PRESCRIBER   (canonical key: NPI)
│   └── RelatedPerson    ← PATIENT_MASTER.KIN_*   (≤ 1 per patient)
├── Organization (abstract)
│   ├── Payer            ← plan/product name (Buckeye, Aetna, Medicare, …)
│   └── Facility         ← DEPARTMENT.FACILITY_NAME
├── Act (abstract)
│   ├── Encounter        ← VISIT
│   ├── Claim            ← CLAIMS_LINE (grouped by CLAIM_ID)
│   ├── ClaimLine        ← CLAIMS_LINE (CLAIM_ID + LINE_NO)
│   ├── MedicationRequest← MEDICATION (order)
│   ├── MedicationDispense← PHARMACY_FILL (dispense)
│   └── Observation      ← VISIT vitals + LAB_RESULTS  (wide → unpivoted)
├── Concept (abstract)
│   ├── Condition        ← PROBLEM_LIST + VISIT + CLAIMS_LINE   (canonical: dotted ICD-10)
│   ├── Procedure        ← CLAIMS_LINE.CPT_CODE
│   ├── Medication       ← NDC_PRODUCT master + orders/fills   (canonical: RxNorm)
│   └── ServiceSetting   ← PLACE_OF_SERVICE  (CMS POS code — a *category*, not a place)
├── Location             ← DEPARTMENT (department/unit; within a Facility)
└── Coverage             ← EMR inline (PATIENT_MASTER) + MEMBER/CLAIMS_LINE
```

`Location` (a physical department) is deliberately kept distinct from `ServiceSetting` (a POS code category) so a claim's *"Office (POS 11)"* and an encounter's *"Endocrinology Clinic"* never collapse into one node.

## Relationships (33)

Two abstract parents — `act_involves_patient`, `act_involves_practitioner` — plus 31 concrete edges. The four **ontology-added edges** are the payoff: relationships the raw schema has no foreign key for.

| Edge | Link | How it's derived |
|------|------|------------------|
| **`claim_for_encounter`** ★ | Claim → Encounter | **Inferred** — no FK exists; matched on resolved patient + NPI + `SERVICE_DATE = VISIT_DATE`. The flagship clinical↔payer bridge. |
| **`medrequest_during_encounter`** ★ | MedicationRequest → Encounter | Inferred — patient + NPI + `ORDER_DATE = VISIT_DATE`. |
| **`dispense_fulfills_request`** | MedicationDispense → MedicationRequest | Patient + prescriber + date proximity + drug (RxNorm, else DRUG_NAME↔GENERIC/BRAND+STRENGTH text match for NULL-RxNorm orders). |
| **`related_person_resolves_to_patient`** ★ | RelatedPerson → Patient | Kin who are themselves patients (spousal cross-refs) via name-only match. |

Core traversal edges: `patient_has_pcp/coverage/condition/related_person`, `coverage_with_payer/subscriber_is`, `encounter_of_patient/performed_by/at_location/diagnoses_condition/has_observation`, `observation_of_patient`, `claim_for_patient/rendered_by/under_coverage/at_setting/has_line`, `claimline_involves_procedure/diagnoses_condition`, `medrequest_of_patient/ordered_by/for_medication`, `dispense_of_patient/prescribed_by/of_medication`, `practitioner_works_at`, `location_within_facility`.

## How identity is resolved (the ontology's core job)

| Entity | Canonical key | Resolution logic |
|--------|---------------|------------------|
| **Patient** | `PATIENT_KEY` (= EMR MRN) | `INS_MEMBER_ID = MEMBER_ID` (strong) → `SSN` (medium) → last-name + DOB, nickname-tolerant (weak). Unifies "Robert Smith" / "SMITH, ROBERT A" / "Bob Smith". |
| **Practitioner** | `NPI` | One node across three name spellings ("Sarah Chen, MD" / "CHEN, SARAH" / "S CHEN"); specialty normalized (EMR canonical). |
| **Medication** | `RxNorm` | `NDC_PRODUCT` crosswalk; NULL EMR RxNorm recovered via DRUG_NAME → GENERIC_NAME + STRENGTH. |
| **Condition** | dotted ICD-10 | Claims `E119` → `E11.9` (dot re-inserted after char 3), aligning with EMR/`PROBLEM_LIST`. |

This resolution is stored two ways: declaratively in `ONT_IDENTITY_RULE` (priority · id_system · match_keys · confidence) and executably in the `STG_*` views (e.g. `STG_MAP_RX` = `COALESCE(ssn_match, name_dob_match)` with a `MATCH_BASIS`). Because the rules live in `ONT_IDENTITY_RULE` and each class's contributing source tables/columns live in `ONT_OBJECT_SOURCE`, the ontology can answer questions *about itself*.

## The five layers the build creates

| Layer | Objects (in `CLINICAL_EMR.ONTOLOGY`) |
|-------|-------------------------------------|
| **L1 — Physical KG** | `KG_NODE` (883 = 861 instances + 22 TBox class nodes), `KG_EDGE` (2,260 = instance + `subClassOf` + inferred), `FN_ICD10_DOTTED`, 8 `STG_*` resolution views |
| **L2 — Metadata** | ~26 `ONT_*`/`ACT_*`/`OBJ_*` tables — `ONT_CLASS`, `ONT_RELATION_DEF`, `ONT_CLASS_MAP`, `ONT_OBJECT_SOURCE`, `ONT_IDENTITY_RULE`, `ONT_RULE`, `REL_EDGE_INFERRED`, `ONT_CONSTRAINT_VIOLATION`, … |
| **L3 — Views** | 48 typed `V_{CLASS}`/`V_{REL}` · 20 abstract `VW_ONT_*` · `REL_RESOLVED` · `VW_ONT_SUBCLASS_OF` / `VW_ANCESTORS` / `VW_DESCENDANTS` / `VW_ONT_HIERARCHY_STATS` |
| **L4 — Semantic Views** | `HEALTHCARE_ONTOLOGY_BASE`, `_KG_MODEL`, `_ONTOLOGY_MODEL`, `_METADATA_MODEL` (see below) |
| **L5 — Cortex Agents** | `HEALTHCARE_ONTOLOGY_AGENT` — 8 intent-routed tools · plus `HEALTHCARE_BASE_AGENT` — a 1-tool **baseline** over the base view only, for comparison |
| **Inference / graph** | SPs `SP_INFER_TRANSITIVE`, `SP_INFER_INVERSE`, `SP_RUN_ONTOLOGY_INFERENCE`, `SP_CHECK_*`; UDFs `EXPAND_DESCENDANTS_TOOL`, `GET_ANCESTORS_TOOL`, `GET_DIRECT_CHILDREN_TOOL`, `GET_HIERARCHY_PATH_TOOL` |

**Design notes:** the KG holds TBox too — `KG_NODE` carries 22 `OntologyClass` nodes + `subClassOf` edges so the graph-traversal UDFs work (instance views filter these out by `NODE_TYPE`). The KG semantic view is an **entity star** (facts carry inline FKs → dimension entities), not edge views — this is what lets Cortex Analyst answer multi-hop cross-system questions correctly.

### The four semantic views (Cortex Analyst)

| Semantic view | Covers | Use for |
|---------------|--------|---------|
| `HEALTHCARE_ONTOLOGY_BASE` | 15 raw source tables (19 relationships) | Concrete per-system attribute lookups & aggregations |
| `HEALTHCARE_ONTOLOGY_KG_MODEL` | 17 typed entity views as an **entity star** (facts carry inline FKs → Patient/Practitioner/Medication/… dims) | Cross-system multi-hop: who treated/prescribed/dispensed to whom |
| `HEALTHCARE_ONTOLOGY_ONTOLOGY_MODEL` | `VW_ONT_ALL_ENTITIES` + `REL_RESOLVED` + hierarchy | Cross-type / abstract reasoning, entity & relationship counts |
| `HEALTHCARE_ONTOLOGY_METADATA_MODEL` | `ONT_CLASS` hub + provenance/identity/mapping tables | Questions *about the ontology itself* |

### The agent's 8 tools

`base_query_tool`, `kg_query_tool`, `ontology_query_tool`, `metadata_query_tool` (Cortex Analyst over the four semantic views) + `expand_descendants_tool`, `get_ancestors_tool`, `get_direct_children_tool`, `get_hierarchy_path_tool` (SQL UDFs over the class hierarchy). Orchestration instructions map user vocabulary (doctor→Practitioner, drug→Medication, member→Patient…) and route each question to the right tool.

### Baseline agent (for comparison)

`HEALTHCARE_BASE_AGENT` is a deliberately limited **baseline**: a single `base_query_tool` over `HEALTHCARE_ONTOLOGY_BASE` (raw source tables), with no ontology vocabulary or resolution hints. It's there to show the contrast on cross-system questions.

The instructive contrast: on a **single-entity** lookup ("list Robert Smith's pharmacy fills") the baseline can still land the right answer — but only because its orchestration LLM *brute-forces* the resolution at query time (it runs ~5 exploratory queries and matches SSN/DOB in its own reasoning, since the base view has no patient↔pharmacy relationship). On a **population/aggregate** question it breaks: asked how many metformin-dispensed patients are also diabetic, the baseline returns **7** (bridging on SSN only, silently dropping the 2 NULL-SSN patients) while the ontology agent returns the correct **9** (SSN → name+DOB fallback). A semantic view can only join on keys that already exist; the ontology bakes the *degrading-hierarchy resolution* into a governed, deterministic layer.

## Business questions the ontology answers

Each is designed to *require* the ontology — a naive `table = class` join gives a wrong or empty answer.

**A. Same entity, different references across systems**
1. **How many DISTINCT patients did Dr. Chen treat, and what medications were they prescribed?** (Chen = "Sarah Chen, MD" / "CHEN, SARAH" / "S CHEN"; patients = PATIENT/MEMBER/SUBSCRIBER.) → *9 patients, resolved by NPI.*
2. Which patients appear under a **nickname** in pharmacy but their legal name in the EMR (e.g. "Bob Smith" vs "Robert Smith"), and confirm they are the same person?
3. For each provider, reconcile the three name/specialty spellings into one identity and report total patients seen across EMR visits, claims, and pharmacy fills.

**B. Entities nested inside overloaded tables**
4. List each patient's **next-of-kin** (RelatedPerson) name, relationship, and phone. (Nested in `PATIENT_MASTER.KIN_*`.)
5. What insurance **Coverage** does each patient have, and does the EMR's inline coverage agree with the claims plan? (Coverage nested in both `PATIENT_MASTER` and `CLAIMS_LINE`.)
6. Show blood-pressure and A1c **Observations** from visits, and lab HbA1c from `LAB_RESULTS`, as one uniform observation set. (Wide vitals + wide labs → unpivoted.)

**C. Questions about the ontology itself**
7. How is **Physician related to Rendering_Provider and Prescriber** in the ontology? (All three → `Practitioner`, keyed on NPI.)
8. Which **source tables and columns map to the Patient class**, and which identifier systems (INS_MEMBER_ID, SSN, name+DOB) resolve them?
9. What relationship **path connects Patient to Medication**, and which classes/edges lie on it?

**D. Multi-hop graph traversal**
10. For patients diagnosed with **Type 2 diabetes** (E11.9 / E119), which drugs were actually **dispensed**, by which prescriber, and which health plan paid the claim? (Three cross-system branches.)
11. For each **family policy** (SUBFAM1/2/3), list every member, the providers they saw, and the medications they filled.
12. Find patients whose EMR medication order has a **NULL RxNorm** code, and recover the canonical drug by traversing to the pharmacy fill's NDC and back through the NDC↔RxNorm crosswalk.

## Using the ontology

Names below assume the default `CLINICAL_EMR.ONTOLOGY`; use your `config.env` names if you renamed them.

**Chat with the agent** (Cortex Analyst / Snowflake Intelligence, or REST `DATA_AGENT_RUN`):

```sql
-- The agent picks the right semantic view / graph tool automatically
DESCRIBE AGENT CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT;
```

**Query a semantic view directly** via Cortex Analyst, e.g. `CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_KG_MODEL`.

**Traverse the class hierarchy** with the SQL UDFs:

```sql
SELECT * FROM TABLE(CLINICAL_EMR.ONTOLOGY.EXPAND_DESCENDANTS_TOOL('Act'));      -- all subtypes of Act
SELECT * FROM TABLE(CLINICAL_EMR.ONTOLOGY.GET_ANCESTORS_TOOL('Patient'));       -- Person, Entity
```

**Explore the KG directly**:

```sql
SELECT NODE_TYPE, COUNT(*) FROM CLINICAL_EMR.ONTOLOGY.KG_NODE GROUP BY 1;       -- entities by class
SELECT * FROM CLINICAL_EMR.ONTOLOGY.REL_RESOLVED WHERE REL_NAME = 'claim_for_encounter';
```

**Regenerate abstract views** after reloading data: `CALL CLINICAL_EMR.ONTOLOGY.SP_GENERATE_ONTOLOGY_VIEWS();`

**Compare the two agents** on the same question to see the ontology earn its keep:

```sql
DESCRIBE AGENT CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT;  -- full ontology (8 tools)
DESCRIBE AGENT CLINICAL_EMR.ONTOLOGY.HEALTHCARE_BASE_AGENT;      -- baseline (base view only)
```

---

## How these files were produced

These scripts are the exact, tested DDL for the stack — not a from-scratch sketch:

- **Phase 4** — the build sub-scripts that create the objects, concatenated in deploy order
  (`01`→`08`) with section headers. Section 01 is the **hand-authored** cross-system
  entity-resolution load (canonical `PATIENT_KEY`, NPI-unified `Practitioner`, RxNorm recovery,
  dotted ICD-10) that a generic table→class generator cannot express; sections 02–08 are
  generator output (`05` is the KG-correct view regenerator).
- **Phases 4.5 & 5** — the semantic-view definitions, captured via `GET_DDL('SEMANTIC_VIEW', …)`
  from a reference build, so they include the relationship-cardinality corrections and the KG
  entity-star rebuild.
- **Phase 6** — the `CREATE OR REPLACE AGENT … FROM SPECIFICATION $$…$$` statements (spec is
  YAML; JSON is valid YAML).

Re-running is safe: everything uses `CREATE OR REPLACE` / `IF NOT EXISTS`, so `./deploy.sh` is
idempotent. If you later modify the ontology in Snowflake and want these files to match, re-capture
the semantic views (`GET_DDL('SEMANTIC_VIEW', …)`) and agents (`DESCRIBE AGENT`).

## Expected results after deploy

`verify.sql` (run by `./deploy.sh verify`) checks your build against these known-good counts:

| Check | Expected |
|-------|----------|
| Base tables | 29 |
| Views | 83 |
| Functions / procedures | 5 / 6 |
| `KG_NODE` / `KG_EDGE` rows | 883 · 2,260 |
| `ONT_CLASS` / `ONT_RELATION_DEF` / `ONT_OBJECT_SOURCE` / `ONT_IDENTITY_RULE` / `ONT_CLASS_MAP` | 22 · 33 · 46 · 9 · 17 |
| Semantic views | 4 |
| Agents | 2 |

If a count differs, re-run the matching phase file (or the whole `./deploy.sh`).
