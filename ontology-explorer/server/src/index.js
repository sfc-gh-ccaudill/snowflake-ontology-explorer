import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { loadConnection } from './config.js';
import { ping, query } from './snowflake.js';
import {
  getOntology,
  getNodeDetail,
  getNodeSampleQuery,
  getSourceDatasets,
  isKnownObject,
  getOverview,
  classifyColumn,
  LINKAGE_KINDS,
} from './ontology.js';
import { streamChat } from './agent.js';
import { getKnowledgeGraph } from './knowledgeGraph.js';
import { DB_NAMES, ONTOLOGY } from './dbconfig.js';

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;

// --- Health / connection status --------------------------------------------
app.get('/api/health', async (_req, res) => {
  try {
    const conn = loadConnection();
    const info = await ping();
    res.json({
      ok: true,
      connection: conn.name,
      account: info?.ACCOUNT,
      user: info?.USER,
      role: info?.ROLE,
      warehouse: info?.WAREHOUSE,
      databases: DB_NAMES,
      agentConfigured: Boolean(process.env.CORTEX_AGENT_NAME),
    });
  } catch (err) {
    res.status(503).json({ ok: false, error: err.message });
  }
});

// --- Ontology graph ----------------------------------------------------------
app.get('/api/ontology', (_req, res) => {
  res.json(getOntology());
});

// --- Overview dashboard data -------------------------------------------------
app.get('/api/overview', (_req, res) => {
  res.json(getOverview());
});

// --- Instance-level knowledge graph (real data, resolved across systems) -----
app.get('/api/knowledge-graph', async (req, res) => {
  const patients = Number(req.query.patients) || 3;
  try {
    const graph = await getKnowledgeGraph(patients);
    res.json(graph);
  } catch (err) {
    res.status(503).json({ error: err.message });
  }
});

// --- Source-system schema diagram (curated meta + live columns) --------------
app.get('/api/source-schema', async (_req, res) => {
  const datasets = getSourceDatasets();

  // One INFORMATION_SCHEMA query per distinct (db, schema) across all datasets.
  const allSystems = datasets.flatMap((d) => d.systems);
  const pairs = [...new Set(allSystems.map((s) => `${s.db}|${s.schema}`))];
  const unions = pairs
    .map((p) => {
      const [db, schema] = p.split('|');
      return (
        `select '${db}' as db, TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION ` +
        `from ${db}.INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = '${schema}'`
      );
    })
    .join(' union all ');
  const sql = `${unions} order by db, TABLE_NAME, ORDINAL_POSITION`;

  let liveColumns = true;
  const byKey = new Map(); // `${db}.${table}` -> columns[]
  try {
    const rows = await query(sql);
    for (const r of rows) {
      const key = `${r.DB}.${r.TABLE_NAME}`;
      if (!byKey.has(key)) byKey.set(key, []);
      byKey.get(key).push({
        name: r.COLUMN_NAME,
        type: r.DATA_TYPE,
        ordinal: Number(r.ORDINAL_POSITION),
        link: classifyColumn(r.COLUMN_NAME),
      });
    }
  } catch {
    liveColumns = false; // objects not loaded yet — return curated meta only
  }

  const enrich = (systems) =>
    systems.map((s) => ({
      ...s,
      tables: s.tables.map((t) => ({ ...t, columns: byKey.get(`${s.db}.${t.name}`) || [] })),
    }));

  const out = datasets.map((d) => ({ ...d, systems: enrich(d.systems) }));
  res.json({ datasets: out, liveColumns, linkageKinds: LINKAGE_KINDS });
});

// --- Ad-hoc sample of 5 rows from a known table/view ------------------------
app.get('/api/sample', async (req, res) => {
  const { db, schema, table } = req.query;
  if (!db || !schema || !table) {
    return res.status(400).json({ available: false, error: 'db, schema and table are required' });
  }
  if (!isKnownObject(String(db), String(schema), String(table))) {
    return res.status(404).json({ available: false, error: 'Unknown object' });
  }
  const sql = `SELECT * FROM "${db}"."${schema}"."${table}" LIMIT 5`;
  try {
    const rows = await query(sql);
    const columns = rows.length ? Object.keys(rows[0]) : [];
    res.json({ available: true, sql, columns, rows });
  } catch (err) {
    res.json({ available: false, sql, error: err.message });
  }
});

// --- Single class detail (+ optional live sample rows) -----------------------
app.get('/api/node/:id', async (req, res) => {
  const detail = getNodeDetail(req.params.id);
  if (!detail) return res.status(404).json({ error: `Unknown class: ${req.params.id}` });
  res.json(detail);
});

app.get('/api/node/:id/sample', async (req, res) => {
  const sql = getNodeSampleQuery(req.params.id);
  if (!sql) return res.json({ available: false, reason: 'No source table mapped for a live sample yet.' });
  try {
    const rows = await query(sql);
    const columns = rows.length ? Object.keys(rows[0]) : [];
    res.json({ available: true, sql, columns, rows });
  } catch (err) {
    // Most likely the sql/ load scripts haven't been run yet — say so clearly.
    res.json({ available: false, sql, error: err.message });
  }
});

// --- Chat (Cortex Agent proxy, streamed over SSE) ----------------------------
app.post('/api/chat', async (req, res) => {
  const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
  if (!messages.length) return res.status(400).json({ error: 'messages[] required' });
  try {
    const conn = loadConnection();
    await streamChat({ conn, messages, res, agent: req.body?.agent });
  } catch (err) {
    if (!res.headersSent) res.status(500).json({ error: err.message });
    else res.end();
  }
});

app.listen(PORT, () => {
  console.log(`\n  ontology-explorer API  →  http://localhost:${PORT}`);
  console.log(`  connection: ${process.env.SNOWFLAKE_CONNECTION_NAME || 'DEMO'}`);
  console.log(
    `  cortex agent: ${process.env.CORTEX_AGENT_NAME || `${ONTOLOGY}.HEALTHCARE_ONTOLOGY_AGENT (default)`}\n`
  );
});
