import { useEffect, useState } from 'react';
import { api, type Overview, type Health } from '../api';
import type { View } from '../components/NavRail';

export default function OverviewView({ onOpen }: { onOpen: (v: View) => void }) {
  const [ov, setOv] = useState<Overview | null>(null);
  const [health, setHealth] = useState<Health | null>(null);

  useEffect(() => {
    api.overview().then(setOv).catch(() => {});
    api.health().then(setHealth).catch(() => {});
  }, []);

  return (
    <div className="overview">
      <div className="hero">
        <div className="hero-eyebrow">Healthcare data · ontology alignment demo</div>
        <h1>A unified ontology for healthcare data.</h1>
        <p>
          Three independent source systems describe the same patients, providers, and drugs in
          incompatible ways. Explore how a Snowflake ontology layer aligns them into one connected,
          queryable graph — then ask questions in plain language.
        </p>
        <div className="hero-actions">
          <button className="btn primary" onClick={() => onOpen('ontology')}>
            Explore the ontology
            <Arrow />
          </button>
          <button className="btn ghost" onClick={() => onOpen('source')}>
            Compare source tables
            <Arrow />
          </button>
        </div>
      </div>

      <div className="stat-grid">
        <Stat value={ov?.sourceSystems ?? '—'} label="Source systems" accent="#F59F3B" />
        <Stat value={ov?.sourceTables ?? '—'} label="Source tables" accent="#2FA84F" />
        <Stat value={ov?.classes ?? '—'} label="Ontology classes" accent="#29B5E8" />
        <Stat value={ov?.relationships ?? '—'} label="Relationships" accent="#7442BF" />
      </div>

      <div className="split-cards">
        <button className="feature-card" onClick={() => onOpen('source')}>
          <div className="feature-icon" style={{ background: 'rgba(245,159,59,0.14)', color: '#c47714' }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
              <ellipse cx="12" cy="5" rx="8" ry="3" /><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5" /><path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3" />
            </svg>
          </div>
          <div>
            <h3>The raw source data</h3>
            <p>Overloaded tables, clashing names and codes — exactly as the three systems store it.</p>
          </div>
        </button>
        <div className="split-connector">
          <span>aligns to</span>
          <svg width="34" height="16" viewBox="0 0 34 16" fill="none" stroke="var(--sf-blue)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M2 8h28M24 3l6 5-6 5" />
          </svg>
        </div>
        <button className="feature-card" onClick={() => onOpen('ontology')}>
          <div className="feature-icon" style={{ background: 'rgba(41,181,232,0.14)', color: '#1580ad' }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="5" cy="6" r="2.2" /><circle cx="19" cy="7" r="2.2" /><circle cx="6" cy="18" r="2.2" /><circle cx="18" cy="17" r="2.2" /><path d="M7 6.5l9 .5M6.2 8l-.2 8M7.7 17l8.6-.2M17 9l-9 7" />
            </svg>
          </div>
          <div>
            <h3>The unified ontology</h3>
            <p>One canonical model — Patient, Practitioner, Encounter, Medication — connected end to end.</p>
          </div>
        </button>
      </div>

      <div className="challenges">
        <h2>What makes this hard</h2>
        <div className="challenge-grid">
          {(ov?.challenges || []).map((c) => (
            <div className="challenge-card" key={c.id}>
              <div className="challenge-num">{String(c.id).padStart(2, '0')}</div>
              <div>
                <h4>{c.title}</h4>
                <p>{c.blurb}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="overview-foot">
        {health?.ok ? (
          <>
            Connected to <strong>{health.account}</strong> as <strong>{health.role}</strong> ·
            warehouse <strong>{health.warehouse}</strong>
          </>
        ) : (
          'Connecting to Snowflake…'
        )}
      </div>
    </div>
  );
}

function Stat({ value, label, accent }: { value: number | string; label: string; accent: string }) {
  return (
    <div className="stat-card">
      <div className="stat-bar" style={{ background: accent }} />
      <div className="stat-value">{value}</div>
      <div className="stat-label">{label}</div>
    </div>
  );
}

function Arrow() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12h14M13 5l7 7-7 7" />
    </svg>
  );
}
