export type View = 'overview' | 'ontology' | 'source' | 'data' | 'architecture';

const ICONS: Record<View, JSX.Element> = {
  overview: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="7" rx="1.5" />
      <rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" />
      <rect x="14" y="14" width="7" height="7" rx="1.5" />
    </svg>
  ),
  ontology: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="5" cy="6" r="2.2" />
      <circle cx="19" cy="7" r="2.2" />
      <circle cx="6" cy="18" r="2.2" />
      <circle cx="18" cy="17" r="2.2" />
      <path d="M7 6.5l9 .5M6.2 8l-.2 8M7.7 17l8.6-.2M17 9l-9 7" />
    </svg>
  ),
  source: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
      <ellipse cx="12" cy="5" rx="8" ry="3" />
      <path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5" />
      <path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" />
    </svg>
  ),
  data: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="2.4" />
      <circle cx="5" cy="6" r="2" />
      <circle cx="19" cy="6" r="2" />
      <circle cx="6" cy="19" r="2" />
      <circle cx="18" cy="18" r="2" />
      <path d="M10.3 10.6 6.6 7.4M13.7 10.6l3.6-3.1M10.4 13.5l-2.8 3.8M13.6 13.5l3.2 3.1" />
    </svg>
  ),
  architecture: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3 3 7.5l9 4.5 9-4.5L12 3z" />
      <path d="M3 12l9 4.5L21 12" />
      <path d="M3 16.5 12 21l9-4.5" />
    </svg>
  ),
};

const LABELS: Record<View, string> = {
  overview: 'Overview',
  ontology: 'Ontology',
  source: 'Source Data',
  data: 'Knowledge Graph',
  architecture: 'Architecture',
};

export default function NavRail({ view, onSelect }: { view: View; onSelect: (v: View) => void }) {
  return (
    <nav className="nav-rail">
      {(Object.keys(LABELS) as View[]).map((v) => (
        <button
          key={v}
          className={`nav-item ${view === v ? 'active' : ''}`}
          onClick={() => onSelect(v)}
          title={LABELS[v]}
        >
          {ICONS[v]}
          <span>{LABELS[v]}</span>
        </button>
      ))}
    </nav>
  );
}
