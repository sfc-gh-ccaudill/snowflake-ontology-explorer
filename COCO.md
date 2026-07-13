# COCO.md — deploy guidance for Cortex Code

This repo deploys an **Ontology-on-Snowflake knowledge graph** (synthetic, messy
healthcare data across three source systems) into the user's own Snowflake
account, plus a local React + Express app to explore it. Nothing is hosted; the
user builds it in their account with `./deploy.sh`.

When a user asks you to "deploy this," follow the flow below. Do **not**
hand-author or reorder the SQL — the deploy is fully scripted.

## Deploy flow

1. **Pick the connection first.** The deploy defaults to a connection named
   `DEMO`, which usually does NOT exist in the user's setup. Run
   `snow connection list`, show the user their connections, and ask which to use.
   Never assume `DEMO`.
2. **Set config.** `cp config.env.example config.env`, then set
   `SNOWFLAKE_CONNECTION` to the chosen connection. Database-name defaults
   (`CLINICAL_EMR` / `PAYER_CLAIMS` / `PHARMACY_OPS`) reproduce the reference
   build — only change them if the user wants custom names.
3. **Deploy.** Run `./deploy.sh`. It renders the SQL with the config values,
   loads the three source systems, builds the ontology stack, and runs
   verification. The build role must be able to `CREATE DATABASE` (e.g.
   `SYSADMIN`) in a **Cortex-enabled region**.
4. **Report the verify output** so the user sees the count assertions passed.

## deploy.sh subcommands

| Command | What it does |
|---------|--------------|
| `./deploy.sh` | render + load sources + build ontology + verify (default) |
| `./deploy.sh render` | render SQL into `./build/` only — no Snowflake calls, no account needed |
| `./deploy.sh verify` | run the count assertions against the deployed ontology |
| `./deploy.sh teardown` | DROP the three demo databases (prompts for `yes`) |
| `./deploy.sh check` | prove render-with-defaults is byte-identical to source |

If `snow` is not installed, `./deploy.sh render` produces runnable SQL in
`./build/` that the user can paste into a Snowsight worksheet, run in the file
order below.

**File run order:** `sql/data/01 → 02 → 03`, then
`sql/ontology/01 → 02 → 03 → 04`, then `sql/ontology/verify.sql`. Always as a
`CREATE DATABASE`-capable role.

## Guardrails

- Deploy only via `./deploy.sh` or the rendered `./build/` SQL. Don't invent,
  edit, or reorder the SQL files.
- Confirm the connection with the user before running anything against an
  account. `render` and `check` are safe with no account.
- `teardown` is destructive (DROP DATABASE). Confirm with the user first.

## Explore the app (optional, after deploy)

```bash
cd ontology-explorer
npm install && npm run install:all
npm run dev            # backend :3001 + frontend :5173 -> http://localhost:5173
```

- The app needs **Node 18+** and a **key-pair** connection (the browser can't
  sign JWTs). It reads the connection named by `SNOWFLAKE_CONNECTION_NAME`
  (default `DEMO` — override to match the deploy connection).
- The graph renders from a hand-authored model even before deploy (placeholder
  mode). To wire chat to the real agent, set `CORTEX_AGENT_NAME`
  (default deploy creates `CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT`).
- If the user deployed under custom database names, set the matching
  `*_DB` / `*_SCHEMA` vars in `ontology-explorer/server/.env`.

## References

- `README.md` — full purpose, prerequisites, deploy walkthrough.
- `config.env.example` — every deploy knob, documented.
- `sql/data/README.md` — the data + its deliberate messiness.
- `sql/ontology/README.md` — class model, relationships, agent tools.
- `ADAPTING.md` — re-skinning this demo for another vertical.
