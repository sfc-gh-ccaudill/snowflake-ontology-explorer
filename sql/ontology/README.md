# Ontology SQL — `CLINICAL_EMR.ONTOLOGY`

The SQL that builds the **HEALTHCARE_ONTOLOGY** stack on top of the three source systems
loaded by [`../01_clinical_emr.sql`](../01_clinical_emr.sql),
[`../02_payer_claims.sql`](../02_payer_claims.sql), and
[`../03_pharmacy_ops.sql`](../03_pharmacy_ops.sql).

One file per phase of the ontology-stack-builder workflow. These files are a **faithful
reproduction of the ontology as currently deployed** — every object was validated against
the live account (see *Validation* below), not just the build-time output.

> **Deploying:** run `./deploy.sh` from the repo root — it renders these files with the
> database names from `config.env` and runs them in order. The files below use the default
> names (`CLINICAL_EMR.ONTOLOGY`, etc.); `deploy.sh render` substitutes your configured names.

> Target: `CLINICAL_EMR.ONTOLOGY` · Path: Knowledge Graph · Build role: `SYSADMIN` ·
> Sources read from `CLINICAL_EMR.EHR`, `PAYER_CLAIMS.CLAIMS`, `PHARMACY_OPS.RX`.

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

Phases 1–3 (input gathering, ontology design, visualization) produced no SQL — the design
lives in the class/relation model realized by Phase 4. Phase 7 was read-only validation.

## What each phase file is sourced from

- **Phase 4** — the exact build sub-scripts executed to create the live objects, concatenated
  in deploy order (`01`→`08`), with section headers. Section 01 is the **hand-authored**
  cross-system entity-resolution load (canonical `PATIENT_KEY`, NPI-unified `Practitioner`,
  RxNorm recovery, dotted ICD-10) that a generic table→class generator cannot express;
  sections 02–08 are generator output (`05` is the KG-correct view regenerator).
- **Phases 4.5 & 5** — captured from the **live** semantic views via
  `GET_DDL('SEMANTIC_VIEW', …)`, so they reflect the final deployed definitions (including the
  relationship-cardinality corrections and the KG entity-star rebuild).
- **Phase 6** — the exact deployed `CREATE OR REPLACE AGENT … FROM SPECIFICATION $$…$$`
  statements (spec is YAML; JSON is valid YAML).

## Key design notes baked into the SQL

- **Identity resolution** is a degrading hierarchy, stored two ways: declaratively in
  `ONT_IDENTITY_RULE` (priority · id_system · match_keys · confidence) and executably in the
  `STG_*` views (e.g. `STG_MAP_RX` = `COALESCE(ssn_match, name_dob_match)` with a `MATCH_BASIS`).
- **TBox in the graph**: `KG_NODE` holds 22 `OntologyClass` nodes + `subClassOf` edges so the
  graph-traversal UDFs work; instance views filter these out by `NODE_TYPE`.
- **KG semantic view is an entity star** (facts carry inline FKs → dimension entities), not
  edge views — this is what lets Cortex Analyst answer multi-hop cross-system questions correctly.

## Validation status (as of last sync)

Validated against the live account **without executing these files** (read-only
`GET_DDL` / `DESCRIBE` / `COUNT`):

| Check | Result |
|-------|--------|
| Base tables declared vs live | 29 = 29 ✓ |
| Views declared vs live | 83 = 83 ✓ |
| Functions / procedures | 5 = 5 · 6 = 6 ✓ |
| `KG_NODE` / `KG_EDGE` rows | 883 · 2,260 ✓ |
| `ONT_CLASS` / `ONT_RELATION_DEF` / `ONT_OBJECT_SOURCE` / `ONT_IDENTITY_RULE` / `ONT_CLASS_MAP` | 22 · 33 · 46 · 9 · 17 ✓ |
| Semantic views present | 4 ✓ (files are live `GET_DDL`) |
| Agents — tools, tool_resources, instructions vs live | both match exactly ✓ |

> ⚠️ These files are a **snapshot** of the deployed ontology. Re-running them against the
> existing deployment would recreate the objects; they were **not** executed during capture so
> the live ontology is unchanged. If the ontology is later modified in Snowflake, re-capture
> the semantic views (`GET_DDL('SEMANTIC_VIEW', …)`) and agents (`DESCRIBE AGENT`) to keep
> these files in sync.
