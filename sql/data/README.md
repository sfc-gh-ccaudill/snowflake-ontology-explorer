# The source data — three messy systems

These three scripts **load synthetic, deliberately messy healthcare data** into three
independent source databases. `./deploy.sh` runs them first (order `01 → 02 → 03`), before
building the ontology on top. Database names come from `config.env` — the defaults below
(`CLINICAL_EMR`, `PAYER_CLAIMS`, `PHARMACY_OPS`) are what you get out of the box.

The data is **synthetic** — no real patient, member, provider, or claims information. It is
intentionally *not* clean: tables are overloaded (one table → many entity types), the same
real-world entity is named differently in each system, and code conventions diverge. That
messiness is the whole point — it's what a naive `table = class` mapping gets wrong, and what
the ontology layer (see [`../ontology/`](../ontology/)) is built to resolve.

## The three source systems

| Script | Database.Schema (default) | Represents | "Person" is called | "Clinician" is called |
|--------|---------------------------|------------|--------------------|-----------------------|
| [`01_clinical_emr.sql`](01_clinical_emr.sql) | `CLINICAL_EMR.EHR` | Electronic medical record | `PATIENT` (MRN) | `PHYSICIAN` |
| [`02_payer_claims.sql`](02_payer_claims.sql) | `PAYER_CLAIMS.CLAIMS` | Health plan / claims | `MEMBER` / `SUBSCRIBER` | `RENDERING_PROVIDER` |
| [`03_pharmacy_ops.sql`](03_pharmacy_ops.sql) | `PHARMACY_OPS.RX` | Pharmacy / dispensing | `SUBSCRIBER` (Rx member) | `PRESCRIBER` |

**Scale:** 50 patients, 12 providers, 14 drugs, spread across ~700 rows total. Every patient
appears in all three systems under three different identifiers.

Each script's header comments describe its local vocabulary, the intentional messiness, and
the cross-system linkage keys. The scripts are independent at load time; run order only
matters because the ontology build depends on all three.

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
