# Ontology Explorer

An interactive web app to **visualize the healthcare ontology as a network**, **inspect how each class maps across the three messy source systems**, and **chat with a Snowflake Cortex Agent** to query the data behind it.

Built to run locally and authenticate against your Snowflake account using a connection from `~/.snowflake/connections.toml` (key-pair / `SNOWFLAKE_JWT`). Defaults to the **`DEMO`** connection; override with `SNOWFLAKE_CONNECTION_NAME`.

> Status: the graph renders from a hand-authored ontology model (derived from the source SQL) so the app is fully usable even before any Snowflake objects exist. The Inspector queries live source tables when they're loaded. Chat runs in a clearly-labelled **placeholder mode** until you point it at a deployed agent — set `CORTEX_AGENT_NAME` (e.g. `CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT`, or your renamed equivalent) to wire it to the live Cortex Agent built by `sql/ontology/`.

---

## Architecture

```
┌─────────────────────┐        /api/*         ┌──────────────────────────┐
│  frontend (React)   │  ───────────────────► │  server (Express)        │
│  Vite · TypeScript  │   (Vite dev proxy)    │  reads DEMO connection   │
│  force-graph canvas │                       │  snowflake-sdk (keypair) │
│  Inspector + Chat   │ ◄─────────────────── │  Cortex Agent proxy      │
└─────────────────────┘     JSON / SSE        └──────────────────────────┘
                                                         │ key-pair JWT / SQL
                                                         ▼
                                                   Snowflake account
```

The browser cannot read `connections.toml` or sign JWTs, so a thin local **Express backend** owns the Snowflake connection and exposes a small API. The React frontend only ever talks to `/api`.

---

## Prerequisites

- Node.js 18+ (tested on 25)
- A `DEMO` connection in `~/.snowflake/connections.toml` (key-pair auth). This app reads it automatically.
- (Optional, for live sample rows) the demo data loaded via the repo's `sql/data/01–03` scripts.

## Run it

```bash
cd ontology-explorer
npm install                # installs the root dev tool (concurrently)
npm run install:all        # installs server/ and frontend/ deps
npm run dev                # starts backend (:3001) + frontend (:5173)
```

Then open **http://localhost:5173**.

The connection badge (top-right) turns green once the backend authenticates with your `DEMO` connection.

---

## Configuration

Backend config is optional — copy `server/.env.example` to `server/.env` to override defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `3001` | API port (frontend proxies here) |
| `SNOWFLAKE_CONNECTION_NAME` | `DEMO` | Which connection to read from `connections.toml` |
| `SNOWFLAKE_CONNECTIONS_TOML` | `~/.snowflake/connections.toml` | Override the file path |
| `CORTEX_AGENT_NAME` | _(unset)_ | Fully-qualified agent `DB.SCHEMA.AGENT`. When set, chat calls the real agent. |
| `EMR_DB` / `EMR_SCHEMA` | `CLINICAL_EMR` / `EHR` | Clinical EMR source (only set if you renamed it at deploy time) |
| `CLAIMS_DB` / `CLAIMS_SCHEMA` | `PAYER_CLAIMS` / `CLAIMS` | Payer claims source |
| `RX_DB` / `RX_SCHEMA` | `PHARMACY_OPS` / `RX` | Pharmacy source |
| `ONTOLOGY_DB` / `ONTOLOGY_SCHEMA` | `=EMR_DB` / `ONTOLOGY` | Where the ontology (semantic views + agents) lives |

> If you deployed the demo under custom database names (via the repo's `config.env`), set the matching `*_DB` / `*_SCHEMA` variables here so the app queries the right objects. Leave them unset to use the defaults.

---

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Connection status (account, role, warehouse, agent configured?) |
| `GET /api/ontology` | Graph: `{ nodes, links, groups }` |
| `GET /api/node/:id` | Full class detail: properties, relationships, source mappings |
| `GET /api/node/:id/sample` | Live sample rows from the mapped source table |
| `POST /api/chat` | Streams the agent reply over SSE (`{ delta }` … `{ done }`) |

---

## Wiring in the real ontology & agent (later)

Both integration points are isolated and clearly marked:

1. **Ontology graph** — replace the hand-authored model in `server/src/ontology.js` (`getOntology` / `getNodeDetail`) with a query against your semantic view or KG node/edge tables. The frontend depends only on the JSON shape.
2. **Cortex Agent** — set `CORTEX_AGENT_NAME`. The key-pair JWT signing (`server/src/jwt.js`) and REST call + SSE parsing (`server/src/agent.js`) are already implemented; verify the request/response shape against the agent once it exists.

---

## Project layout

```
ontology-explorer/
├── package.json              # root scripts (dev / install:all)
├── server/                   # Express API
│   └── src/
│       ├── index.js          # routes
│       ├── config.js         # connections.toml parser
│       ├── snowflake.js      # snowflake-sdk query layer (keypair)
│       ├── ontology.js       # ontology model  ← swap for live layer later
│       ├── jwt.js            # key-pair JWT signer for REST
│       └── agent.js          # Cortex Agent proxy + placeholder mode
└── frontend/                 # React + Vite + TypeScript
    └── src/
        ├── App.tsx
        ├── api.ts            # typed client + SSE stream reader
        ├── theme.css         # Snowflake-branded light theme
        └── components/       # Header, GraphCanvas, Legend, Inspector, ChatPanel
```
