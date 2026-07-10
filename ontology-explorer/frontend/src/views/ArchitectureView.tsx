import { useEffect, useRef, useState } from 'react';

/**
 * Architecture view — a static, color-coded diagram of the ontology stack,
 * laid out left→right as five layers. Data flows from raw storage on the left
 * through the ontology (metadata + generated views) into semantic models and,
 * finally, the agent + its knowledge-graph tools on the right.
 *
 * Object names are the real deployed objects in CLINICAL_EMR.ONTOLOGY (+ the
 * three source databases).
 */

interface Card {
  name: string;
  sub?: string;
  tag?: string; // small corner tag, e.g. system name
}

/** A faint decorative node/edge network drawn behind Layers 2 & 3. */
function OntologyNetwork() {
  // Positions are in % of the zone box.
  const nodes = [
    { x: 12, y: 22 }, { x: 30, y: 12 }, { x: 48, y: 26 }, { x: 66, y: 14 },
    { x: 86, y: 24 }, { x: 20, y: 52 }, { x: 40, y: 62 }, { x: 58, y: 50 },
    { x: 78, y: 60 }, { x: 92, y: 48 }, { x: 14, y: 82 }, { x: 34, y: 88 },
    { x: 52, y: 78 }, { x: 72, y: 86 }, { x: 88, y: 78 },
  ];
  const edges = [
    [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [2, 6], [3, 7], [4, 9],
    [5, 6], [6, 7], [7, 8], [8, 9], [5, 10], [6, 12], [7, 12],
    [8, 13], [10, 11], [11, 12], [12, 13], [13, 14],
  ];
  return (
    <svg className="arch-net" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden>
      {edges.map(([a, b], i) => (
        <line key={i} x1={nodes[a].x} y1={nodes[a].y} x2={nodes[b].x} y2={nodes[b].y} />
      ))}
      {nodes.map((n, i) => (
        <circle key={i} cx={n.x} cy={n.y} r={i % 3 === 0 ? 1.6 : 1.1} />
      ))}
    </svg>
  );
}

function LayerCol({
  cls,
  n,
  title,
  children,
}: {
  cls: string;
  n: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className={`arch-layer ${cls}`}>
      <header className="arch-head">
        <span className="arch-head-n">{n}</span>
        <span className="arch-head-t">{title}</span>
      </header>
      <div className="arch-body">{children}</div>
    </section>
  );
}

function Cards({ items }: { items: Card[] }) {
  return (
    <>
      {items.map((c) => (
        <div className="arch-card" key={c.name}>
          {c.tag && <span className="arch-card-tag">{c.tag}</span>}
          <div className="arch-card-name">{c.name}</div>
          {c.sub && <div className="arch-card-sub">{c.sub}</div>}
        </div>
      ))}
    </>
  );
}

const Flow = () => <div className="arch-flow" aria-hidden>→</div>;

export default function ArchitectureView() {
  // Fade the diagram in once mounted (nice on tab switch).
  const [ready, setReady] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const t = setTimeout(() => setReady(true), 30);
    return () => clearTimeout(t);
  }, []);

  return (
    <div className={`arch ${ready ? 'ready' : ''}`} ref={ref}>
      <div className="arch-intro">
        <h2>Ontology architecture</h2>
        <p>
          Five layers, left to right — raw source data is resolved into a knowledge graph,
          described by ontology metadata, exposed as generated views &amp; semantic models, and
          finally reasoned over by the agent.
        </p>
      </div>

      <div className="arch-scroll">
        <div className="arch-stage">
          {/* ---------- Layer 1: Physical Storage (raw + KG tables) ---------- */}
          <section className="arch-layer l1 arch-l1">
            <header className="arch-head">
              <span className="arch-head-n">Layer 1</span>
              <span className="arch-head-t">Physical Storage</span>
            </header>
            <div className="arch-body arch-l1-body">
              <div className="arch-group">
                <div className="arch-group-title">Raw source tables</div>
                <Cards
                  items={[
                    { name: 'PATIENT_MASTER', sub: 'VISIT · MEDICATION · PROBLEM_LIST', tag: 'EMR' },
                    { name: 'MEMBER', sub: 'CLAIMS_LINE · RENDERING_PROVIDER', tag: 'Claims' },
                    { name: 'SUBSCRIBER', sub: 'PHARMACY_FILL · NDC_PRODUCT', tag: 'Pharmacy' },
                  ]}
                />
              </div>
              <div className="arch-inner-flow" aria-hidden>→</div>
              <div className="arch-group kg">
                <div className="arch-group-title">Knowledge graph</div>
                <Cards
                  items={[
                    { name: 'KG_NODE', sub: 'canonical entities' },
                    { name: 'KG_EDGE', sub: 'typed relationships' },
                  ]}
                />
              </div>
            </div>
          </section>

          <Flow />

          {/* ---------- Ontology zone wraps Layers 2 & 3 ---------- */}
          <div className="arch-onto-zone">
            <OntologyNetwork />
            <div className="arch-onto-ribbon">The ontology lives here</div>
            <div className="arch-onto-inner">
              <LayerCol cls="l2 arch-l2" n="Layer 2" title="Ontology Metadata">
                <Cards
                  items={[
                    { name: 'ONT_CLASS', sub: 'classes & hierarchy' },
                    { name: 'ONT_PROPERTY', sub: 'attributes' },
                    { name: 'ONT_RELATION_DEF', sub: 'relationships' },
                    { name: 'ONT_OBJECT_SOURCE', sub: 'class → source table' },
                    { name: 'ONT_IDENTITY_RULE', sub: 'entity resolution' },
                    { name: 'OBJ_VIEW_DEF', sub: 'view generation spec' },
                  ]}
                />
              </LayerCol>

              <Flow />

              <LayerCol cls="l3 arch-l3" n="Layer 3" title="Generated Views">
                <div className="arch-subhead">Entities</div>
                <Cards
                  items={[
                    { name: 'V_PATIENT' },
                    { name: 'V_PRACTITIONER' },
                    { name: 'V_ENCOUNTER' },
                    { name: 'V_MEDICATION' },
                  ]}
                />
                <div className="arch-subhead">Relationships</div>
                <Cards
                  items={[
                    { name: 'V_ENCOUNTER_PERFORMED_BY' },
                    { name: 'V_PATIENT_HAS_CONDITION' },
                    { name: 'V_DISPENSE_OF_MEDICATION' },
                  ]}
                />
                <div className="arch-subhead">Resolved graph</div>
                <Cards
                  items={[
                    { name: 'REL_RESOLVED' },
                    { name: 'VW_ONT_ALL_ENTITIES' },
                  ]}
                />
              </LayerCol>
            </div>
          </div>

          <Flow />

          {/* ---------- Layer 4: Semantic Models ---------- */}
          <LayerCol cls="l4 arch-l4" n="Layer 4" title="Semantic Models">
            <Cards
              items={[
                { name: 'Base', sub: 'HEALTHCARE_ONTOLOGY_BASE', tag: 'raw' },
                { name: 'Ontology', sub: 'HEALTHCARE_ONTOLOGY_ONTOLOGY_MODEL', tag: 'resolved' },
                { name: 'Governance', sub: 'HEALTHCARE_ONTOLOGY_METADATA_MODEL', tag: 'metadata' },
                { name: 'Knowledge Graph', sub: 'HEALTHCARE_ONTOLOGY_KG_MODEL', tag: 'star' },
              ]}
            />
          </LayerCol>

          <Flow />

          {/* ---------- Layer 5: Intelligent Orchestration ---------- */}
          <LayerCol cls="l5 arch-l5" n="Layer 5" title="Intelligent Orchestration">
            <div className="arch-agent">
              <div className="arch-agent-icon">✦</div>
              <div>
                <div className="arch-agent-name">HEALTHCARE_ONTOLOGY_AGENT</div>
                <div className="arch-agent-sub">Cortex Agent · plans &amp; routes</div>
              </div>
            </div>
            <div className="arch-subhead">Analyst tools → models</div>
            <div className="arch-chips">
              {['base_query_tool', 'kg_query_tool', 'ontology_query_tool', 'metadata_query_tool'].map((t) => (
                <span className="arch-chip" key={t}>{t}</span>
              ))}
            </div>
            <div className="arch-subhead">KG traversal tools</div>
            <div className="arch-chips">
              {['get_ancestors', 'expand_descendants', 'get_direct_children', 'get_hierarchy_path'].map((t) => (
                <span className="arch-chip alt" key={t}>{t}</span>
              ))}
            </div>
          </LayerCol>
        </div>
      </div>
    </div>
  );
}
