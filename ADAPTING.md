# Adapting this demo to another vertical

This demo is healthcare, but the *shape* of the problem — the same real-world
entity showing up under different names, keys, and code systems across
independent source systems — is universal. Financial services, retail, supply
chain, telco, and manufacturing all have the same messiness. Here's how to
re-skin it for a customer conversation.

## What makes this demo work (keep these)

The narrative lands because the synthetic data has **deliberate, specific
messiness** that a naive `table = class` join gets wrong:

1. **Overloaded tables** — one row carries several entity types.
2. **Same entity, different names** — `PATIENT` / `MEMBER` / `SUBSCRIBER`.
3. **Imperfect identity keys** — a degrading hierarchy (strong → medium → weak).
4. **Divergent code systems** — ICD-10 with vs. without the decimal, NDC vs. RxNorm.
5. **A "killer question"** that is wrong/empty without the ontology and correct with it.

When you move to a new vertical, **preserve these five properties** — they are
what makes the ontology earn its keep. A clean dataset makes a boring demo.

## The fastest path to a new vertical

1. **Rename the databases** via `config.env` (no code edits) — see the README's
   setup section. That handles the plumbing; the *story* is the real work.
2. **Rewrite the three source-system load scripts** (`sql/data/01`–`03`) with your
   domain's tables and the same intentional messiness. Keep ~50 core entities so
   the graph stays legible.
3. **Re-run the ontology-stack-builder** (the skill that generated `sql/ontology/`)
   against your new sources, or hand-edit the resolution logic in
   `sql/ontology/01_phase4_layers_1-3.sql` (section 01 is the hand-authored
   cross-system entity resolution).
4. **Update the Explorer's hand-authored model** in
   `ontology-explorer/server/src/ontology.js` (classes, mappings, sample queries)
   so the graph and Inspector reflect your domain. The frontend depends only on
   the JSON shape, so no React changes are needed.
5. **Rewrite the agent orchestration** vocabulary in
   `sql/ontology/04_phase6_cortex_agents.sql` to map your domain's synonyms.

## Worked analogies

| Healthcare here | Financial services | Retail / CPG |
|-----------------|--------------------|--------------|
| Patient (MRN / member id / SSN) | Customer (CIF / account / SSN-TIN) | Customer (loyalty id / email / card) |
| Practitioner (NPI) | Advisor (rep id / CRD) | Store / associate |
| Medication (RxNorm / NDC) | Instrument (CUSIP / ISIN / ticker) | Product (SKU / UPC / GTIN) |
| Claim ↔ Encounter (inferred) | Trade ↔ Order (inferred) | Return ↔ Sale (inferred) |
| ICD-10 dotted vs. undotted | Currency / country code variants | Category taxonomy variants |

Keep the identity-resolution hierarchy and the inferred cross-system edge — those
are the two things customers remember.
