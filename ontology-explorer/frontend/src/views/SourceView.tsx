import type { SourceSchema, SourceTable, ClassRef } from '../api';

interface Props {
  schema: SourceSchema | null;
  dataset: string;
  onDatasetChange: (key: string) => void;
  selectedKey: string | null; // `${db}.${table}`
  onSelectTable: (db: string, table: string) => void;
  onOpenClass: (id: string) => void;
}

export default function SourceView({ schema, dataset, onDatasetChange, selectedKey, onSelectTable, onOpenClass }: Props) {
  if (!schema) {
    return <div className="empty-state" style={{ height: '100%' }}>Loading source systems…</div>;
  }

  const active = schema.datasets.find((d) => d.key === dataset) || schema.datasets[0];

  return (
    <div className="source-view">
      <div className="source-head">
        <div>
          <div className="ds-select-row">
            <label className="ds-select-label" htmlFor="ds-select">Dataset</label>
            <select
              id="ds-select"
              className="ds-select"
              value={active.key}
              onChange={(e) => onDatasetChange(e.target.value)}
            >
              {schema.datasets.map((d) => (
                <option key={d.key} value={d.key}>{d.label}</option>
              ))}
            </select>
          </div>
          <p>
            {active.description}{' '}
            {active.key === 'raw' && (
              <>Click any <span className="inline-chip">class</span> chip to jump to the ontology.</>
            )}
          </p>
        </div>
        <LinkageLegend schema={schema} />
      </div>

      {!schema.liveColumns && (
        <div className="note-box" style={{ marginBottom: 16 }}>
          Showing the curated model. Live column details will appear once the underlying objects
          exist in your account.
        </div>
      )}

      <div className="lanes">
        {active.systems.map((sys) => (
          <div className="lane" key={`${sys.db}.${sys.schema}.${sys.label}`}>
            <div className="lane-head" style={{ borderColor: sys.color }}>
              <span className="lane-dot" style={{ background: sys.color }} />
              <div>
                <div className="lane-title">{sys.label}</div>
                <div className="lane-sub">
                  {sys.db}.{sys.schema}
                </div>
              </div>
            </div>
            <div className="lane-desc">{sys.description}</div>

            {sys.tables.map((t) => (
              <TableCard
                key={t.name}
                table={t}
                accent={sys.color}
                linkColor={(kind) => schema.linkageKinds[kind]?.color || '#8595a6'}
                selected={selectedKey === `${sys.db}.${t.name}`}
                onSelect={() => onSelectTable(sys.db, t.name)}
                onOpenClass={onOpenClass}
              />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

function TableCard({
  table,
  accent,
  linkColor,
  selected,
  onSelect,
  onOpenClass,
}: {
  table: SourceTable;
  accent: string;
  linkColor: (kind: string) => string;
  selected: boolean;
  onSelect: () => void;
  onOpenClass: (id: string) => void;
}) {
  return (
    <div className={`table-card ${selected ? 'selected' : ''}`} onClick={onSelect} style={selected ? { borderColor: accent } : undefined}>
      <div className="tc-head">
        <span className="tc-name">{table.name}</span>
        {table.overloaded && <span className="tc-badge">overloaded · {table.classes.length} classes</span>}
      </div>
      <div className="tc-desc">{table.description}</div>

      {table.columns.length > 0 && (
        <div className="tc-cols">
          {table.columns.map((c) => (
            <div className="tc-col" key={c.name} title={c.link?.label || ''}>
              <span
                className="tc-col-dot"
                style={{ background: c.link ? linkColor(c.link.kind) : 'transparent', borderColor: c.link ? linkColor(c.link.kind) : 'var(--border-strong)' }}
              />
              <span className={`tc-col-name ${c.link ? 'is-link' : ''}`}>{c.name}</span>
              <span className="tc-col-type">{c.type.toLowerCase()}</span>
            </div>
          ))}
        </div>
      )}

      {table.classes.length > 0 && (
        <div className="tc-chips">
          {table.classes.map((cl: ClassRef) => (
            <button
              key={cl.id}
              className="class-chip"
              style={{ borderColor: cl.color, color: cl.color }}
              onClick={(e) => {
                e.stopPropagation();
                onOpenClass(cl.id);
              }}
            >
              {cl.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function LinkageLegend({ schema }: { schema: SourceSchema }) {
  return (
    <div className="link-legend">
      {Object.entries(schema.linkageKinds).map(([kind, info]) => (
        <div className="link-legend-row" key={kind}>
          <span className="legend-swatch" style={{ background: info.color }} />
          {info.label}
        </div>
      ))}
    </div>
  );
}
