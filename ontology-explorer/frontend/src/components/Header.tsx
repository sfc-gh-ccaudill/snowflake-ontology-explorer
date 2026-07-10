import { useEffect, useState } from 'react';
import { api, type Health } from '../api';

function ConnectionBadge() {
  const [health, setHealth] = useState<Health | null>(null);
  const [state, setState] = useState<'loading' | 'ok' | 'err'>('loading');

  useEffect(() => {
    let alive = true;
    api
      .health()
      .then((h) => {
        if (!alive) return;
        setHealth(h);
        setState(h.ok ? 'ok' : 'err');
      })
      .catch(() => alive && setState('err'));
    return () => {
      alive = false;
    };
  }, []);

  const text =
    state === 'loading'
      ? 'Connecting…'
      : state === 'ok'
      ? `${health?.connection} · ${health?.role}`
      : 'Not connected';

  return (
    <span className={`badge ${state}`} title={health?.account || health?.error || ''}>
      <span className="dot" />
      {text}
    </span>
  );
}

export default function Header() {
  return (
    <header className="header">
      <div className="brand-mark" aria-hidden>
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="6" cy="6" r="2.4" />
          <circle cx="18" cy="7" r="2.4" />
          <circle cx="7" cy="18" r="2.4" />
          <circle cx="17" cy="17" r="2.4" />
          <path d="M8 7l8 0M7 8l0 8M8.5 16.5l7-8M8.5 8.5l7 8" />
        </svg>
      </div>
      <div>
        <div className="brand-title">Ontology Explorer</div>
        <div className="brand-sub">EHR + Claims + Pharmacy · unified view</div>
      </div>
      <div className="header-spacer" />
      <ConnectionBadge />
    </header>
  );
}
