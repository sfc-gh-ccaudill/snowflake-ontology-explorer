# Messy Healthcare Data — Ontology Alignment Demo

Synthetic, deliberately *messy* healthcare data spread across **three independent source systems**, built to demonstrate how a Snowflake ontology layer aligns and traverses relationships that a naive `table = class` mapping cannot.

The data is intentionally **not** clean: tables are overloaded (one table → many entity types), the same real-world entity is named differently in each system, and code conventions diverge. This is what makes the ontology earn its keep.

> **Internal Snowflake enablement asset** — synthetic data only, not for external distribution (see [LICENSE](LICENSE)). To re-skin it for another industry, see [ADAPTING.md](ADAPTING.md).

## Prerequisites

- A Snowflake account in a **Cortex-enabled region** (the semantic views + agent use Cortex Analyst).
- A role that can `CREATE DATABASE` (e.g. `SYSADMIN`) and a warehouse (e.g. `COMPUTE_WH`).
- **Snowflake CLI** (`snow`) with a connection in `~/.snowflake/connections.toml`.
- For the Ontology Explorer app only: **Node 18+** and a **key-pair** connection (the browser cannot sign JWTs).

## Deploy in one command

```bash
# Optional: deploy under your OWN database names (defaults reproduce the reference build).
cp config.env.example config.env      # then edit the names/connection

./deploy.sh                 # load sources -> build ontology -> verify, via `snow`
./deploy.sh render          # only render SQL into ./build (to paste into a worksheet)
./deploy.sh verify          # re-run the count assertions against a deployment
./deploy.sh teardown        # DROP the demo databases (asks to confirm)
./deploy.sh check           # prove render-with-defaults == source (no account needed)
```

Everything is parameterized through `config.env` — no code edits needed to rename:

| Variable | Default | Names |
|----------|---------|-------|
| `SNOWFLAKE_CONNECTION` | `DEMO` | which `connections.toml` entry to deploy with |
| `BUILD_ROLE` / `WAREHOUSE` | `SYSADMIN` / `COMPUTE_WH` | role + warehouse for the build |
| `EMR_DB` / `EMR_SCHEMA` | `CLINICAL_EMR` / `EHR` | clinical EMR source |
| `CLAIMS_DB` / `CLAIMS_SCHEMA` | `PAYER_CLAIMS` / `CLAIMS` | payer claims source |
| `RX_DB` / `RX_SCHEMA` | `PHARMACY_OPS` / `RX` | pharmacy source |
| `ONTOLOGY_DB` / `ONTOLOGY_SCHEMA` | `=EMR_DB` / `ONTOLOGY` | where the ontology is built |

Defaults are byte-for-byte identical to the reference deployment, so `./deploy.sh` works out of the box. The Ontology Explorer app reads the same names (via `server/.env`); see its [README](ontology-explorer/README.md).

## The three source systems

| Script | Database.Schema | Represents | "Person" is called | "Clinician" is called |
|--------|-----------------|------------|--------------------|-----------------------|
| `sql/01_clinical_emr.sql` | `CLINICAL_EMR.EHR` | Electronic medical record | `PATIENT` (MRN) | `PHYSICIAN` |
| `sql/02_payer_claims.sql` | `PAYER_CLAIMS.CLAIMS` | Health plan / claims | `MEMBER` / `SUBSCRIBER` | `RENDERING_PROVIDER` |
| `sql/03_pharmacy_ops.sql` | `PHARMACY_OPS.RX` | Pharmacy / dispensing | `SUBSCRIBER` (Rx member) | `PRESCRIBER` |

**Scale:** 50 patients, 12 providers, 14 drugs, spread across ~700 rows total. Every patient appears in all three systems under three different identifiers.

**Run order:** `01 → 02 → 03`, with a role that can `CREATE DATABASE` (e.g., `SYSADMIN`). Scripts are independent at load time.

---

## Challenge 1 — Overloaded tables (one table → many ontology classes)

The biggest reason `table = class` fails. A single table smears across multiple entity types, so the ontology must *decompose* one row into several class instances.

| Table | Entity types crammed into one row |
|-------|-----------------------------------|
| `CLINICAL_EMR.PATIENT_MASTER` | **Patient** + **Address** + **Provider** (PCP) + **Coverage** (insurance) + **RelatedPerson** (next of kin) |
| `CLINICAL_EMR.VISIT` | **Encounter** + **Provider** + **Location** (dept) + **Condition** (primary dx) + **Observation** (vitals: BP, weight, A1c) |
| `PAYER_CLAIMS.CLAIMS_LINE` | **Claim** + **ClaimLine** + **Procedure** (CPT) + **Diagnosis** (ICD) + **Provider** + **Coverage** + **Member** |
| `PHARMACY_OPS.PHARMACY_FILL` | **MedicationRequest** + **MedicationDispense** + **Medication** + **Patient** + **Prescriber** |

**Ontology assists by:** projecting each overloaded table into clean class instances (e.g., the `PCP_NPI`, `INS_*`, and `KIN_*` columns of `PATIENT_MASTER` become separate `Practitioner`, `Coverage`, and `RelatedPerson` nodes linked to one `Patient`).

---

## Challenge 2 — Same entity, different names across systems

The classic alignment problem. The ontology defines one canonical class; the mappings collapse the synonyms.

| Ontology class | CLINICAL_EMR | PAYER_CLAIMS | PHARMACY_OPS |
|----------------|--------------|--------------|--------------|
| **Patient** | `PATIENT_MASTER` (MRN) | `MEMBER` / `SUBSCRIBER` | `SUBSCRIBER` (Rx member) |
| **Practitioner** | `PHYSICIAN` | `RENDERING_PROVIDER` | `PRESCRIBER` |
| **Location** | `DEPARTMENT` | `PLACE_OF_SERVICE` (POS code) | — |
| **Encounter** | `VISIT` | `CLAIMS_LINE` | — |
| **Medication** | `MEDICATION` (generic + RxNorm) | (CPT/HCPCS n/a) | `NDC_PRODUCT` (NDC + brand) |
| **Coverage** | inline in `PATIENT_MASTER` | `MEMBER` (plan/group) | — |

**Ontology assists by:** mapping `PATIENT` / `MEMBER` / `SUBSCRIBER` → `Patient`, and `PHYSICIAN` / `RENDERING_PROVIDER` / `PRESCRIBER` → `Practitioner`, so an agent can answer cross-system questions without knowing the local vocabulary.

---

## Challenge 3 — Identity resolution with imperfect keys

There is no single shared patient key. The ontology has to resolve identity from a *hierarchy* of keys, degrading gracefully as they disappear.

| Link strength | Key | Where |
|---------------|-----|-------|
| Strong (direct) | `PATIENT_MASTER.INS_MEMBER_ID = MEMBER.MEMBER_ID` | EMR ↔ claims |
| Medium | `SSN` | all three systems |
| Weak (fallback) | `name + DOB` | required when SSN is NULL |

**Intentional degradations:**
- `MEMBER.MEMBER_SSN` is **NULL for every 5th member** (and originally for Linda Williams, Jennifer Davis).
- `SUBSCRIBER.PATIENT_SSN` is **NULL for every 6th subscriber** (and originally Michael Brown, Elizabeth Moore).
- Pharmacy stores **nicknames**: `Bob Smith` (Robert), `Jim Johnson` (James), `Beth Moore` (Elizabeth), plus generated ones (`Tony`, `Ben`, `Greg`, `Kim`, `Becky`…). Claims store `LAST, FIRST M`. The EMR stores discrete name parts.
- The pharmacy `RX_MEMBER_ID` is **not** the claims `MEMBER_ID` — they only reconcile via SSN or name+DOB.

**Ontology assists by:** defining identifier systems and match logic so `Patient` nodes merge across systems even when the strongest key is missing.

---

## Challenge 4 — Provider identity across name formats

All three systems share the **NPI** as a universal key, but nothing else lines up.

| System | Column | Example (Dr. Chen) | Example (Dr. O'Brien) |
|--------|--------|--------------------|-----------------------|
| CLINICAL_EMR | `PHYSICIAN.NPI` / `FULL_NAME` | `Sarah Chen, MD` | `John O'Brien, MD` |
| PAYER_CLAIMS | `RENDERING_PROVIDER.RENDERING_NPI` / `PROVIDER_NAME` | `CHEN, SARAH` | `OBRIEN, JOHN` (apostrophe dropped) |
| PHARMACY_OPS | `PRESCRIBER.PRESCRIBER_ID` / `PRESCRIBER_NAME` | `S CHEN` | `J OBRIEN` |

Specialty is also inconsistent: `Internal Medicine` vs `INTERNAL MED`, `Family Medicine` vs `FAMILY PRACTICE`.

**Ontology assists by:** keying `Practitioner` on NPI and treating the varied name/specialty strings as attributes, so provider-level questions aggregate correctly.

---

## Challenge 5 — Drug identity via code crosswalk

The EMR and pharmacy describe the same drug with **different code systems and different names**.

| Aspect | CLINICAL_EMR.MEDICATION | PHARMACY_OPS.PHARMACY_FILL |
|--------|-------------------------|----------------------------|
| Code | `RXNORM_CODE` (e.g., `617312`) | `NDC` (e.g., `00071-0155-23`) |
| Name | generic (`Atorvastatin 20 mg`) | brand (`Lipitor 20mg`) |

`NDC_PRODUCT` is the **RxNorm ↔ NDC crosswalk** that stitches them together.

**Extra difficulty:** `MEDICATION.RXNORM_CODE` is **NULL for every 7th patient's last drug** (originally Dave Miller's atorvastatin, Richard Taylor's sertraline). For those, the *only* path from an EMR order to a dispensed fill is: EMR drug name → (no RxNorm) → match the fill by patient + prescriber, then recover the canonical drug from the fill's `NDC → NDC_PRODUCT.RXNORM_CODE`.

**Ontology assists by:** normalizing every medication to a canonical concept (RxNorm) regardless of whether the source row provided RxNorm, NDC, or only a brand name.

---

## Challenge 6 — Divergent code & value conventions

Same concept, different encodings — silent wrong answers if joined naively.

| Concept | CLINICAL_EMR | PAYER_CLAIMS |
|---------|--------------|--------------|
| ICD-10 diagnosis | **with** decimal: `E11.9`, `I50.9`, `I48.91` | **without** decimal: `E119`, `I509`, `I4891` |
| Diagnosis coding | also carries `SNOMED_CODE` | ICD only |
| Gender / sex | `M` / `F` | `1` (Male) / `2` (Female) |
| Location | named `DEPARTMENT` | numeric POS code (`11` = Office) |

**Ontology assists by:** canonicalizing codes (strip/format ICD, map gender codes, resolve POS → Location) so a filter like "diabetic patients" matches `E11.9` and `E119` alike.

---

## Challenge 7 — Overloaded column *names* (same name, different meaning)

`STATUS` appears in many tables and means something different each time — a trap for keyword-driven agents.

| Table.Column | What `STATUS` actually means |
|--------------|------------------------------|
| `PROBLEM_LIST.STATUS` | problem/condition status (Active) |
| `VISIT.STATUS` | encounter status (Completed) |
| `CLAIMS_LINE.CLAIM_STATUS` | adjudication status (Paid/Denied) |
| `PHARMACY_FILL.FILL_STATUS` | dispense status (Dispensed/Pending) |

**Ontology assists by:** binding each column to a typed property on the correct class, removing the ambiguity of the shared name.

---

## Challenge 8 — Different grain (wide vs. long)

`CLINICAL_EMR.LAB_RESULTS` is a **wide** table: one row per collection, with `GLUCOSE_MGDL`, `HBA1C_PCT`, `LDL_MGDL`, `CREATININE_MGDL`, `EGFR` as columns (NULL when not ordered). `VISIT` likewise stores vitals (`BP_SYSTOLIC`, `BP_DIASTOLIC`, `WEIGHT_KG`, `A1C_PCT`) as columns.

Ontologically, each populated cell is a distinct **Observation** instance.

**Ontology assists by:** unpivoting wide columns into individual `Observation` nodes with a common shape (code, value, unit, date), so labs and vitals are queryable uniformly.

---

## Relationships available to traverse (for demo queries)

Once aligned, the ontology exposes a connected graph:

```
Patient ──has coverage──> Coverage (Plan)
   │
   ├── subject of ──> Encounter ──performed by──> Practitioner ──at──> Location
   │                     └── has ──> Condition (diagnosis)
   │                     └── has ──> Observation (vitals / labs)
   │
   ├── subject of ──> Claim / ClaimLine ──> Procedure + Diagnosis + Coverage
   │
   └── subject of ──> MedicationRequest ──> MedicationDispense ──> Medication
                          (prescribed by Practitioner)
```

**"Killer" demo question:** *"How many distinct patients did Dr. Chen treat, and what were they prescribed?"*
- Naive SQL fails: `PHYSICIAN` ≠ `RENDERING_PROVIDER` ≠ `PRESCRIBER`; `PATIENT` ≠ `MEMBER` ≠ `SUBSCRIBER`; EMR drug names ≠ pharmacy brand names.
- With the ontology: `Practitioner` (NPI `1003000001`) → resolves all three name forms; `Patient` dedup across systems; `Medication` normalized via the RxNorm↔NDC crosswalk — including the NULL-RxNorm cases.

Built-in family/coverage cases for relationship demos: `SUBFAM1` (James Johnson self + Linda Williams spouse), `SUBFAM2` (MBR0013 self + MBR0014 spouse), `SUBFAM3` (MBR0027 self + MBR0028 child).

---

# The Ontology Layer (deployed)

The ontology is built **on top of** the three source databases and lives in **`CLINICAL_EMR.ONTOLOGY`**. It follows the *Ontology-on-Snowflake* Knowledge-Graph pattern: a physical KG (`KG_NODE` / `KG_EDGE`) with cross-system entity resolution, ~26 metadata tables that make the ontology self-describing, typed + abstract views, four Cortex Analyst semantic views, and a Cortex Agent that routes across them.

Ontology name: **`HEALTHCARE_ONTOLOGY`** · Path: **Knowledge Graph** · Build role: `SYSADMIN`.

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

The resolution rules are themselves stored in `ONT_IDENTITY_RULE`, and each class's contributing source tables/columns in `ONT_OBJECT_SOURCE` — so the ontology can answer questions *about itself*.

## The five deployed layers

| Layer | Objects in `CLINICAL_EMR.ONTOLOGY` |
|-------|-------------------------------------|
| **L1 — Physical KG** | `KG_NODE` (883 = 861 instances + 22 TBox class nodes), `KG_EDGE` (2,260 = instance + `subClassOf` + inferred), `FN_ICD10_DOTTED`, 8 `STG_*` resolution views |
| **L2 — Metadata** | ~26 `ONT_*`/`ACT_*`/`OBJ_*` tables — `ONT_CLASS`, `ONT_RELATION_DEF`, `ONT_CLASS_MAP`, `ONT_OBJECT_SOURCE`, `ONT_IDENTITY_RULE`, `ONT_RULE`, `REL_EDGE_INFERRED`, `ONT_CONSTRAINT_VIOLATION`, … |
| **L3 — Views** | 48 typed `V_{CLASS}`/`V_{REL}` · 20 abstract `VW_ONT_*` · `REL_RESOLVED` · `VW_ONT_SUBCLASS_OF` / `VW_ANCESTORS` / `VW_DESCENDANTS` / `VW_ONT_HIERARCHY_STATS` |
| **L4 — Semantic Views** | `HEALTHCARE_ONTOLOGY_BASE`, `_KG_MODEL`, `_ONTOLOGY_MODEL`, `_METADATA_MODEL` (see below) |
| **L5 — Cortex Agents** | `HEALTHCARE_ONTOLOGY_AGENT` — 8 intent-routed tools · plus `HEALTHCARE_BASE_AGENT` — a 1-tool **baseline** over the base view only, for comparison |
| **Inference / graph** | SPs `SP_INFER_TRANSITIVE`, `SP_INFER_INVERSE`, `SP_RUN_ONTOLOGY_INFERENCE`, `SP_CHECK_*`; UDFs `EXPAND_DESCENDANTS_TOOL`, `GET_ANCESTORS_TOOL`, `GET_DIRECT_CHILDREN_TOOL`, `GET_HIERARCHY_PATH_TOOL` |

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

Key finding from testing both: on a **single-entity** lookup ("list Robert Smith's pharmacy fills") the baseline can still land the right answer — but only because its orchestration LLM *brute-forces* the resolution at query time (it runs ~5 exploratory queries and matches SSN/DOB in its own reasoning, since the base view has no patient↔pharmacy relationship). On a **population/aggregate** question it breaks: asked how many metformin-dispensed patients are also diabetic, the baseline returned **7** (bridging on SSN only, silently dropping the 2 NULL-SSN patients) while the ontology agent returned the correct **9** (SSN → name+DOB fallback). The lesson: a semantic view can only join on keys that already exist; the ontology bakes the *degrading-hierarchy resolution* into a governed, deterministic layer.

---

# Business questions the ontology answers

Each is designed to *require* the ontology — a naive `table = class` join gives a wrong or empty answer. All verified against the deployed agent.

### A. Same entity, different references across systems
1. **How many DISTINCT patients did Dr. Chen treat, and what medications were they prescribed?** (Chen = "Sarah Chen, MD" / "CHEN, SARAH" / "S CHEN"; patients = PATIENT/MEMBER/SUBSCRIBER.) → *9 patients, resolved by NPI.*
2. Which patients appear under a **nickname** in pharmacy but their legal name in the EMR (e.g. "Bob Smith" vs "Robert Smith"), and confirm they are the same person?
3. For each provider, reconcile the three name/specialty spellings into one identity and report total patients seen across EMR visits, claims, and pharmacy fills.

### B. Entities nested inside overloaded tables
4. List each patient's **next-of-kin** (RelatedPerson) name, relationship, and phone. (Nested in `PATIENT_MASTER.KIN_*`.)
5. What insurance **Coverage** does each patient have, and does the EMR's inline coverage agree with the claims plan? (Coverage nested in both `PATIENT_MASTER` and `CLAIMS_LINE`.)
6. Show blood-pressure and A1c **Observations** from visits, and lab HbA1c from `LAB_RESULTS`, as one uniform observation set. (Wide vitals + wide labs → unpivoted.)

### C. Questions about the ontology itself
7. How is **Physician related to Rendering_Provider and Prescriber** in the ontology? (All three → `Practitioner`, keyed on NPI.)
8. Which **source tables and columns map to the Patient class**, and which identifier systems (INS_MEMBER_ID, SSN, name+DOB) resolve them?
9. What relationship **path connects Patient to Medication**, and which classes/edges lie on it?

### D. Multi-hop graph traversal
10. For patients diagnosed with **Type 2 diabetes** (E11.9 / E119), which drugs were actually **dispensed**, by which prescriber, and which health plan paid the claim? (Three cross-system branches.)
11. For each **family policy** (SUBFAM1/2/3), list every member, the providers they saw, and the medications they filled.
12. Find patients whose EMR medication order has a **NULL RxNorm** code, and recover the canonical drug by traversing to the pharmacy fill's NDC and back through the NDC↔RxNorm crosswalk.

---

# Using the ontology

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

## Recreate the ontology from SQL

The fastest path is `./deploy.sh` (see [Deploy in one command](#deploy-in-one-command)). Under the hood it renders and runs, in order, the source loads and then the full deployed ontology — captured one file per build phase in [`sql/ontology/`](sql/ontology/) and validated to match the live account:

```
sql/ontology/
├── 01_phase4_layers_1-3.sql                    # KG tables + resolution load, metadata, views, SPs, UDFs
├── 02_phase4.5_base_semantic_view.sql          # HEALTHCARE_ONTOLOGY_BASE
├── 03_phase5_ontology_layer_semantic_views.sql # KG / Ontology / Metadata semantic views
├── 04_phase6_cortex_agents.sql                 # both Cortex Agents
├── verify.sql                                  # post-deploy count assertions
└── teardown.sql                                # drop the demo databases
```

To run by hand instead, `./deploy.sh render` writes ready-to-run copies (with your configured names) into `./build/`. See [`sql/ontology/README.md`](sql/ontology/README.md) for run order, sourcing, and validation status.

## Ontology Explorer app

[`ontology-explorer/`](ontology-explorer/) is a local React + Express app that **visualizes the ontology as a network graph**, inspects each class's cross-system source mappings, and **chats with a Cortex Agent**. It authenticates with the `DEMO` connection from `~/.snowflake/connections.toml` (key-pair). Set `CORTEX_AGENT_NAME` to `CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT` (or `…HEALTHCARE_BASE_AGENT` to demo the baseline) to wire chat to a live agent. See its [README](ontology-explorer/README.md).

---

## File layout

```
messy-data-ontology/
├── README.md                 # this file
├── LICENSE                   # internal-only enablement asset notice
├── ADAPTING.md               # how to re-skin this demo for another vertical
├── config.env.example        # deploy config (copy to config.env to rename databases)
├── deploy.sh                 # one-command render + deploy + verify + teardown
├── scripts/
│   └── render.pl             # parameterization engine (default names <-> config.env)
├── sql/
│   ├── 01_clinical_emr.sql   # CLINICAL_EMR.EHR   — PATIENT_MASTER, PHYSICIAN, DEPARTMENT,
│   │                         #                      VISIT, PROBLEM_LIST, MEDICATION, LAB_RESULTS
│   ├── 02_payer_claims.sql   # PAYER_CLAIMS.CLAIMS — MEMBER, RENDERING_PROVIDER,
│   │                         #                      PLACE_OF_SERVICE, CLAIMS_LINE
│   ├── 03_pharmacy_ops.sql   # PHARMACY_OPS.RX     — SUBSCRIBER, PRESCRIBER,
│   │                         #                      NDC_PRODUCT, PHARMACY_FILL
│   └── ontology/             # the deployed ontology, one SQL file per build phase
│       ├── 01_phase4_layers_1-3.sql                     # L1 KG + resolution, L2 metadata, L3 views, SPs, UDFs
│       ├── 02_phase4.5_base_semantic_view.sql           # base semantic view
│       ├── 03_phase5_ontology_layer_semantic_views.sql  # KG / Ontology / Metadata semantic views
│       ├── 04_phase6_cortex_agents.sql                  # ontology agent + baseline agent
│       ├── verify.sql                                   # post-deploy count assertions
│       ├── teardown.sql                                 # drop the demo databases
│       └── README.md                                    # run order + validation status
└── ontology-explorer/        # local React + Express app: graph viz, class inspector,
                              # and Cortex Agent chat (auth via a key-pair connection)
```

**Run order:** `./deploy.sh` handles it. Manually: `sql/01 → 02 → 03` (source systems) → `sql/ontology/01 → 02 → 03 → 04` (ontology), all as a `CREATE DATABASE`-capable role.

Each `sql/` source script includes header comments describing its local vocabulary, the intentional messiness, and the cross-system linkage keys.

The **ontology layer is deployed on top of** these three databases in `CLINICAL_EMR.ONTOLOGY` (see [The Ontology Layer](#the-ontology-layer-deployed) above). It was generated with the Ontology-on-Snowflake stack builder; the exact deployed objects are reproduced in [`sql/ontology/`](sql/ontology/) (captured from the live account and validated to match).
