import { useEffect, useState } from 'react';
import { api, type SampleData, type SourceSystem, type SourceTable } from '../api';

interface Props {
  systems: SourceSystem[];
  selectedKey: string | null; // `${db}.${table}`
  onOpenClass: (id: string) => void;
}

export default function TableInspector({ systems, selectedKey, onOpenClass }: Props) {
  const found = resolve(systems, selectedKey);

  const [sample, setSample] = useState<SampleData | null>(null);
  const [loading, setLoading] = useState(false);

  // Reset any loaded sample whenever the selected object changes.
  useEffect(() => {
    setSample(null);
    setLoading(false);
  }, [selectedKey]);

  if (!found) {
    return (
      <div className="empty-state">
        <div className="glyph">
          <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <ellipse cx="12" cy="5" rx="8" ry="3" /><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5" /><path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3" />
          </svg>
        </div>
        <div style={{ fontWeight: 600, color: 'var(--text-2)' }}>Select a table</div>
        <div style={{ fontSize: 13 }}>Click any object to see its columns and which ontology classes it maps to.</div>
      </div>
    );
  }

  const { table, systemLabel, accent, db, schema } = found;
  const keys = table.columns.filter((c) => c.link);

  const runSample = async () => {
    setLoading(true);
    try {
      const data = await api.sampleTable(db, schema, table.name);
      setSample(data);
    } catch (err) {
      setSample({ available: false, error: (err as Error).message });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="node-title">
        <h2>{table.name}</h2>
      </div>
      <span className="node-chip" style={{ background: accent }}>
        {systemLabel}
      </span>
      <p className="node-desc">{table.description}</p>

      <div className="section">
        <button className="sample-btn" onClick={runSample} disabled={loading}>
          {loading ? 'Querying…' : sample ? 'Re-run sample' : 'Sample 5 rows'}
        </button>
        <div className="sample-hint">{db}.{schema}.{table.name}</div>
      </div>

      {sample && <SampleResult data={sample} />}

      {table.overloaded && (
        <div className="note-box" style={{ marginTop: 12 }}>
          This single table is <strong>overloaded</strong> — the ontology decomposes each row into{' '}
          <strong>{table.classes.length}</strong> distinct classes.
        </div>
      )}

      {table.classes.length > 0 && (
        <div className="section">
          <h3>Decomposes into</h3>
          {table.classes.map((c) => (
            <button className="rel" key={c.id} onClick={() => onOpenClass(c.id)}>
              <span className="legend-swatch" style={{ background: c.color }} />
              <span className="rel-other" style={{ marginLeft: 0 }}>{c.label}</span>
              <span className="arrow" style={{ marginLeft: 'auto' }}>open →</span>
            </button>
          ))}
        </div>
      )}

      {keys.length > 0 && (
        <div className="section">
          <h3>Cross-system keys</h3>
          {keys.map((c) => (
            <div className="map-card" key={c.name}>
              <div className="map-table">{c.name}</div>
              <div className="map-note">{c.link?.label}</div>
            </div>
          ))}
        </div>
      )}

      {table.columns.length > 0 && (
        <div className="section">
          <h3>Columns ({table.columns.length})</h3>
          <div className="kv">
            {table.columns.map((c) => (
              <div className="kv-row" key={c.name}>
                <span className="k">{c.name}</span>
                <span className="v">{c.type.toLowerCase()}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SampleResult({ data }: { data: SampleData }) {
  if (!data.available) {
    return (
      <div className="note-box" style={{ marginBottom: 12 }}>
        Couldn’t load a sample{data.error ? `: ${data.error}` : '.'}
      </div>
    );
  }
  const cols = data.columns || [];
  const rows = data.rows || [];
  if (!rows.length) {
    return <div className="note-box" style={{ marginBottom: 12 }}>No rows returned.</div>;
  }
  return (
    <div className="section">
      <div className="sample-table-wrap">
        <table className="sample-table">
          <thead>
            <tr>{cols.map((c) => <th key={c}>{c}</th>)}</tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i}>
                {cols.map((c) => (
                  <td key={c} title={fmt(r[c])}>{fmt(r[c])}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function fmt(v: unknown): string {
  if (v === null || v === undefined) return '∅';
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
}

function resolve(
  systems: SourceSystem[],
  key: string | null
): { table: SourceTable; systemLabel: string; accent: string; db: string; schema: string } | null {
  if (!key) return null;
  for (const sys of systems) {
    for (const t of sys.tables) {
      if (`${sys.db}.${t.name}` === key) {
        return { table: t, systemLabel: sys.label, accent: sys.color, db: sys.db, schema: sys.schema };
      }
    }
  }
  return null;
}
