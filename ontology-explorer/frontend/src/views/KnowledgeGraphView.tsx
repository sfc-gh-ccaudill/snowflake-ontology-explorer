import { useEffect, useMemo, useRef, useState } from 'react';
import ForceGraph2D, { type ForceGraphMethods } from 'react-force-graph-2d';
import { api, type KnowledgeGraph, type KGNode, type KGLink } from '../api';
import { roundRect, hexA, lighten, darken } from '../components/graphDraw';
import Legend from '../components/Legend';

const PRESETS: { label: string; value: number }[] = [
  { label: '3', value: 3 },
  { label: '5', value: 5 },
  { label: '10', value: 10 },
  { label: '20', value: 20 },
  { label: 'All', value: 50 },
];

export default function KnowledgeGraphView() {
  const wrapRef = useRef<HTMLDivElement>(null);
  const fgRef = useRef<ForceGraphMethods<KGNode, KGLink> | undefined>(undefined);
  const didFit = useRef(false);

  const [count, setCount] = useState(3);
  const [graph, setGraph] = useState<KnowledgeGraph | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [showEdgeLabels, setShowEdgeLabels] = useState(false);

  // Size the canvas to its container.
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }));
    ro.observe(el);
    setSize({ w: el.clientWidth, h: el.clientHeight });
    return () => ro.disconnect();
  }, []);

  // Fetch the graph whenever the patient count changes.
  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    didFit.current = false;
    api
      .knowledgeGraph(count)
      .then((g) => {
        if (!alive) return;
        setGraph(g);
        setSelectedId(null);
      })
      .catch((e) => alive && setError(e.message))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [count]);

  // Spread the layout; scale the forces with graph size so big graphs breathe.
  useEffect(() => {
    const fg = fgRef.current;
    if (!fg || !graph) return;
    const big = graph.nodes.length > 120;
    fg.d3Force('charge')?.strength(big ? -160 : -300).distanceMax(big ? 600 : 900);
    fg.d3Force('link')?.distance(big ? 55 : 90).strength(0.22);
    fg.d3ReheatSimulation();
  }, [graph]);

  const fit = () => fgRef.current?.zoomToFit(600, 90);

  const neighbors = useMemo(() => {
    const map = new Map<string, Set<string>>();
    if (!graph) return map;
    graph.nodes.forEach((n) => map.set(n.id, new Set()));
    graph.links.forEach((l) => {
      const s = typeof l.source === 'string' ? l.source : l.source.id;
      const t = typeof l.target === 'string' ? l.target : l.target.id;
      map.get(s)?.add(t);
      map.get(t)?.add(s);
    });
    return map;
  }, [graph]);

  const focusId = hoverId || selectedId;
  const isActive = (id: string) => !focusId || id === focusId || neighbors.get(focusId)?.has(id);
  const radius = (n: KGNode) => 5 + Math.min(n.degree, 10) * 1.1;

  const graphData = useMemo(
    () => ({ nodes: graph?.nodes ?? [], links: graph?.links ?? [] }),
    [graph]
  );

  const selectedNode = graph?.nodes.find((n) => n.id === selectedId) || null;

  return (
    <div className="canvas-wrap" ref={wrapRef}>
      <div className="canvas-hint">Real records, resolved across EHR + Claims + Pharmacy · shared doctors &amp; drugs connect patients</div>

      {/* patient-count presets */}
      <div className="kg-count">
        <span className="kg-count-label">Patients</span>
        <div className="kg-seg">
          {PRESETS.map((p) => (
            <button
              key={p.value}
              className={`kg-seg-btn ${count === p.value ? 'on' : ''}`}
              onClick={() => setCount(p.value)}
              disabled={loading}
            >
              {p.label}
            </button>
          ))}
        </div>
        {graph && (
          <span className="kg-stat">
            {graph.stats.nodes} nodes · {graph.stats.links} links
          </span>
        )}
      </div>

      {/* top-right controls */}
      <div className="canvas-controls">
        <button
          className={`gc-toggle ${showEdgeLabels ? 'on' : ''}`}
          onClick={() => setShowEdgeLabels((v) => !v)}
          title="Show relationship names on the edges"
        >
          <span className="gc-switch" />
          Edge labels
        </button>
        <button className="gc-btn" onClick={fit} title="Fit graph to view">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M8 3H5a2 2 0 0 0-2 2v3M16 3h3a2 2 0 0 1 2 2v3M8 21H5a2 2 0 0 1-2-2v-3M16 21h3a2 2 0 0 0 2-2v-3" />
          </svg>
          Fit
        </button>
      </div>

      {loading && <div className="kg-loading">Building graph…</div>}
      {error && <div className="kg-loading kg-error">Failed to load: {error}</div>}

      {size.w > 0 && graph && (
        <ForceGraph2D
          ref={fgRef}
          width={size.w}
          height={size.h}
          graphData={graphData}
          backgroundColor="rgba(0,0,0,0)"
          cooldownTicks={180}
          warmupTicks={graph.nodes.length > 120 ? 80 : 40}
          d3VelocityDecay={0.3}
          minZoom={0.2}
          maxZoom={8}
          onEngineStop={() => {
            if (didFit.current) return;
            didFit.current = true;
            fit();
          }}
          linkColor={(l) => {
            const s = typeof l.source === 'string' ? l.source : (l.source as KGNode).id;
            const t = typeof l.target === 'string' ? l.target : (l.target as KGNode).id;
            const active = !focusId || s === focusId || t === focusId;
            return active ? 'rgba(74,91,110,0.28)' : 'rgba(74,91,110,0.06)';
          }}
          linkWidth={(l) => {
            const s = typeof l.source === 'string' ? l.source : (l.source as KGNode).id;
            const t = typeof l.target === 'string' ? l.target : (l.target as KGNode).id;
            return focusId && (s === focusId || t === focusId) ? 2 : 0.8;
          }}
          linkDirectionalArrowLength={3.5}
          linkDirectionalArrowRelPos={0.99}
          linkDirectionalArrowColor={() => 'rgba(74,91,110,0.4)'}
          linkCanvasObjectMode={() => (showEdgeLabels ? 'after' : undefined)}
          linkCanvasObject={(link, ctx, scale) => {
            if (!showEdgeLabels) return;
            const s = link.source as KGNode;
            const t = link.target as KGNode;
            if (typeof s !== 'object' || typeof t !== 'object') return;
            const active = !focusId || s.id === focusId || t.id === focusId;
            // At scale, only draw labels for the focused node's edges to avoid clutter.
            if (focusId ? !active : scale < 1.6) return;
            const label = (link as KGLink).label;
            if (!label) return;
            const mx = ((s.x ?? 0) + (t.x ?? 0)) / 2;
            const my = ((s.y ?? 0) + (t.y ?? 0)) / 2;
            const fontSize = Math.max(9 / scale, 2.2);
            ctx.font = `500 ${fontSize}px Inter, sans-serif`;
            const w = ctx.measureText(label).width;
            const padX = 4 / scale;
            const padY = 2.2 / scale;
            const h = fontSize + padY * 2;
            ctx.globalAlpha = active ? 1 : 0.3;
            ctx.fillStyle = 'rgba(255,255,255,0.92)';
            roundRect(ctx, mx - w / 2 - padX, my - h / 2, w + padX * 2, h, 3 / scale);
            ctx.fill();
            ctx.strokeStyle = 'rgba(74,91,110,0.18)';
            ctx.lineWidth = 0.6 / scale;
            ctx.stroke();
            ctx.fillStyle = '#4a5b6e';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(label, mx, my);
            ctx.globalAlpha = 1;
          }}
          onNodeClick={(n) => setSelectedId((n as KGNode).id === selectedId ? null : (n as KGNode).id)}
          onNodeHover={(n) => setHoverId(n ? (n as KGNode).id : null)}
          onBackgroundClick={() => setSelectedId(null)}
          nodeCanvasObject={(node, ctx, scale) => {
            const n = node as KGNode;
            const active = isActive(n.id);
            const selected = n.id === selectedId;
            const r = radius(n);
            const x = n.x ?? 0;
            const y = n.y ?? 0;

            if (active && (selected || n.degree >= 6)) {
              ctx.beginPath();
              ctx.arc(x, y, r + (selected ? 6 : 3), 0, 2 * Math.PI);
              ctx.fillStyle = hexA(n.color, selected ? 0.22 : 0.08);
              ctx.fill();
            }

            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            if (active) {
              const grad = ctx.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.1, x, y, r);
              grad.addColorStop(0, lighten(n.color, 0.28));
              grad.addColorStop(0.6, n.color);
              grad.addColorStop(1, darken(n.color, 0.08));
              ctx.fillStyle = grad;
            } else {
              ctx.fillStyle = hexA(n.color, 0.14);
            }
            ctx.fill();
            ctx.lineWidth = selected ? 2 : 1;
            ctx.strokeStyle = selected ? darken(n.color, 0.3) : 'rgba(255,255,255,0.85)';
            ctx.stroke();

            // Labels: only hubs, the focused node, and its neighbors (keeps big graphs legible).
            const showLabel = selected || n.id === focusId || (focusId && active) || n.degree >= 6 || scale > 2.2;
            if (showLabel) {
              const fontSize = Math.max(10 / scale, 2.6);
              ctx.font = `${selected ? 700 : 500} ${fontSize}px Inter, sans-serif`;
              ctx.textAlign = 'center';
              ctx.textBaseline = 'top';
              ctx.fillStyle = active ? '#0f2438' : 'rgba(133,149,166,0.5)';
              ctx.fillText(n.label, x, y + r + 2);
            }
          }}
          nodePointerAreaPaint={(node, color, ctx) => {
            const n = node as KGNode;
            const r = radius(n);
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.arc(n.x ?? 0, n.y ?? 0, r + 3, 0, 2 * Math.PI);
            ctx.fill();
          }}
        />
      )}

      {selectedNode && (
        <div className="kg-detail">
          <div className="kg-detail-cls" style={{ color: selectedNode.color }}>
            <span className="kg-dot" style={{ background: selectedNode.color }} />
            {prettyClass(selectedNode.cls)}
          </div>
          <div className="kg-detail-label">{selectedNode.label}</div>
          {selectedNode.detail && <div className="kg-detail-sub">{selectedNode.detail}</div>}
          <div className="kg-detail-sub">
            {neighbors.get(selectedNode.id)?.size || 0} connection
            {(neighbors.get(selectedNode.id)?.size || 0) === 1 ? '' : 's'}
          </div>
        </div>
      )}

      {graph && <Legend groups={graph.groups} />}
    </div>
  );
}

function prettyClass(cls: string): string {
  return cls.replace(/([a-z])([A-Z])/g, '$1 $2');
}
