import type { Ontology } from '../api';

export default function Legend({ groups }: { groups: Ontology['groups'] }) {
  return (
    <div className="legend">
      <h4>Ontology domains</h4>
      {Object.entries(groups).map(([key, g]) => (
        <div className="legend-row" key={key}>
          <span className="legend-swatch" style={{ background: g.color }} />
          {g.label}
        </div>
      ))}
    </div>
  );
}
