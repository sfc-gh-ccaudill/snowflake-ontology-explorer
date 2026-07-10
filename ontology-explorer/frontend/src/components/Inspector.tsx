import { useEffect, useState } from 'react';
import { api, type NodeDetail, type SampleData } from '../api';

interface Props {
  nodeId: string | null;
  onSelect: (id: string) => void;
  onOpenTable?: (db: string, table: string) => void;
}

export default function Inspector({ nodeId, onSelect, onOpenTable }: Props) {
  const [detail, setDetail] = useState<NodeDetail | null>(null);
  const [sample, setSample] = useState<SampleData | null>(null);
  const [loadingSample, setLoadingSample] = useState(false);

  useEffect(() => {
    setSample(null);
    if (!nodeId) {
      setDetail(null);
      return;
    }
    let alive = true;
    api.node(nodeId).then((d) => alive && setDetail(d));
    return () => {
      alive = false;
    };
  }, [nodeId]);

  if (!nodeId || !detail) {
    return (
      <div className="empty-state">
        <div className="glyph">
          <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="7" />
            <path d="M21 21l-4.3-4.3" />
          </svg>
        </div>
        <div style={{ fontWeight: 600, color: 'var(--text-2)' }}>Select a class</div>
        <div style={{ fontSize: 13 }}>
          Click any node in the graph to see how it maps across the three source systems.
        </div>
      </div>
    );
  }

  const loadSample = async () => {
    setLoadingSample(true);
    try {
      setSample(await api.sample(detail.id));
    } finally {
      setLoadingSample(false);
    }
  };

  return (
    <div>
      <div className="node-title">
        <h2>{detail.label}</h2>
      </div>
      <span className="node-chip" style={{ background: detail.color }}>
        {detail.groupLabel}
      </span>
      <p className="node-desc">{detail.description}</p>

      <div className="section">
        <h3>Properties</h3>
        <div className="kv">
          {detail.properties.map((p) => (
            <div className="kv-row" key={p.name}>
              <span className="k">{p.name}</span>
              <span className="v">{p.description}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="section">
        <h3>Relationships</h3>
        {detail.relationships.map((r, i) => (
          <button className="rel" key={i} onClick={() => onSelect(r.other)}>
            {r.direction === 'out' ? (
              <>
                <span className="rel-label">{r.label}</span>
                <span className="arrow">→</span>
                <span className="rel-other">{r.other}</span>
              </>
            ) : (
              <>
                <span className="rel-other">{r.other}</span>
                <span className="arrow">→</span>
                <span className="rel-label">{r.label}</span>
              </>
            )}
          </button>
        ))}
      </div>

      <div className="section">
        <h3>Source mappings</h3>
        {detail.mappings.map((m, i) => {
          const firstTable = m.table.split(/[/,]/)[0].trim();
          return (
            <div className="map-card" key={i}>
              <div className="map-sys">{m.system}</div>
              {onOpenTable ? (
                <button className="map-table-link" onClick={() => onOpenTable(m.system, firstTable)}>
                  {m.table} <span className="arrow">→</span>
                </button>
              ) : (
                <div className="map-table">{m.table}</div>
              )}
              {m.note && <div className="map-note">{m.note}</div>}
            </div>
          );
        })}
      </div>

      {detail.sampleQuery && (
        <div className="section">
          <h3>Live sample</h3>
          {!sample && (
            <button className="sample-btn" onClick={loadSample} disabled={loadingSample}>
              {loadingSample ? 'Querying Snowflake…' : 'Query sample rows'}
            </button>
          )}
          {sample && <SampleTable sample={sample} />}
        </div>
      )}
    </div>
  );
}

function SampleTable({ sample }: { sample: SampleData }) {
  if (!sample.available) {
    return (
      <div className="note-box">
        Couldn't fetch live rows. The source tables may not be loaded yet — run the{' '}
        <code>sql/</code> scripts against your account.
        {sample.error && (
          <div style={{ marginTop: 6, opacity: 0.8 }}>
            <code>{sample.error}</code>
          </div>
        )}
      </div>
    );
  }
  const cols = sample.columns || [];
  return (
    <div className="table-scroll">
      <table className="data">
        <thead>
          <tr>
            {cols.map((c) => (
              <th key={c}>{c}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {(sample.rows || []).map((row, i) => (
            <tr key={i}>
              {cols.map((c) => (
                <td key={c}>{fmt(row[c])}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function fmt(v: unknown): string {
  if (v === null || v === undefined) return '∅';
  if (v instanceof Object) return JSON.stringify(v);
  return String(v);
}
