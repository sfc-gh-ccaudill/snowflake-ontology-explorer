import { useEffect, useRef, useState, useMemo } from 'react';
import ForceGraph2D, { type ForceGraphMethods } from 'react-force-graph-2d';
import type { GraphNode, GraphLink, Ontology } from '../api';
import { roundRect, hexA, lighten, darken } from './graphDraw';

interface Props {
  ontology: Ontology;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}

export default function GraphCanvas({ ontology, selectedId, onSelect }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const fgRef = useRef<ForceGraphMethods<GraphNode, GraphLink> | undefined>(undefined);
  const [size, setSize] = useState({ w: 0, h: 0 });
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [showEdgeLabels, setShowEdgeLabels] = useState(false);
  const didFit = useRef(false);

  // Keep the canvas sized to its container.
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }));
    ro.observe(el);
    setSize({ w: el.clientWidth, h: el.clientHeight });
    return () => ro.disconnect();
  }, []);

  // Spread the layout out: strong repulsion + long links so nodes get room.
  useEffect(() => {
    const fg = fgRef.current;
    if (!fg) return;
    didFit.current = false;
    fg.d3Force('charge')?.strength(-430).distanceMax(1000);
    fg.d3Force('link')?.distance(115).strength(0.32);
    fg.d3ReheatSimulation();
  }, [ontology]);

  const fit = () => fgRef.current?.zoomToFit(600, 100);

  // Safety refit in case the engine never reports a stop.
  useEffect(() => {
    const t = setTimeout(fit, 2200);
    return () => clearTimeout(t);
  }, [ontology]);

  // Neighbor lookup for highlight-on-select/hover.
  const neighbors = useMemo(() => {
    const map = new Map<string, Set<string>>();
    ontology.nodes.forEach((n) => map.set(n.id, new Set()));
    ontology.links.forEach((l) => {
      const s = typeof l.source === 'string' ? l.source : l.source.id;
      const t = typeof l.target === 'string' ? l.target : l.target.id;
      map.get(s)?.add(t);
      map.get(t)?.add(s);
    });
    return map;
  }, [ontology]);

  const focusId = hoverId || selectedId;
  const isActive = (id: string) => !focusId || id === focusId || neighbors.get(focusId)?.has(id);
  const radius = (n: GraphNode) => 7 + Math.min(n.degree, 6) * 1.15;

  const graphData = useMemo(
    () => ({ nodes: ontology.nodes, links: ontology.links }),
    [ontology]
  );

  return (
    <div className="canvas-wrap" ref={wrapRef}>
      <div className="canvas-hint">Click a class to inspect · drag to pan · scroll to zoom</div>

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

      {size.w > 0 && (
        <ForceGraph2D
          ref={fgRef}
          width={size.w}
          height={size.h}
          graphData={graphData}
          backgroundColor="rgba(0,0,0,0)"
          cooldownTicks={160}
          warmupTicks={40}
          d3VelocityDecay={0.28}
          minZoom={0.4}
          maxZoom={6}
          onEngineStop={() => {
            if (didFit.current) return;
            didFit.current = true;
            fit();
          }}
          linkColor={(l) => {
            const s = typeof l.source === 'string' ? l.source : (l.source as GraphNode).id;
            const t = typeof l.target === 'string' ? l.target : (l.target as GraphNode).id;
            const active = !focusId || s === focusId || t === focusId;
            return active ? 'rgba(74,91,110,0.32)' : 'rgba(74,91,110,0.07)';
          }}
          linkWidth={(l) => {
            const s = typeof l.source === 'string' ? l.source : (l.source as GraphNode).id;
            const t = typeof l.target === 'string' ? l.target : (l.target as GraphNode).id;
            return focusId && (s === focusId || t === focusId) ? 2.2 : 1;
          }}
          linkDirectionalArrowLength={4.5}
          linkDirectionalArrowRelPos={0.99}
          linkDirectionalArrowColor={() => 'rgba(74,91,110,0.45)'}
          linkCanvasObjectMode={() => (showEdgeLabels ? 'after' : undefined)}
          linkCanvasObject={(link, ctx, scale) => {
            if (!showEdgeLabels) return;
            const s = link.source as GraphNode;
            const t = link.target as GraphNode;
            if (typeof s !== 'object' || typeof t !== 'object') return;
            const label = (link as GraphLink).label;
            if (!label) return;
            const active = !focusId || s.id === focusId || t.id === focusId;
            const mx = ((s.x ?? 0) + (t.x ?? 0)) / 2;
            const my = ((s.y ?? 0) + (t.y ?? 0)) / 2;
            const fontSize = Math.max(9 / scale, 2.4);
            ctx.font = `500 ${fontSize}px Inter, sans-serif`;
            const w = ctx.measureText(label).width;
            const padX = 4 / scale;
            const padY = 2.4 / scale;
            const h = fontSize + padY * 2;
            ctx.globalAlpha = active ? 1 : 0.28;
            // pill background
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
          onNodeClick={(n) => onSelect((n as GraphNode).id === selectedId ? null : (n as GraphNode).id)}
          onNodeHover={(n) => setHoverId(n ? (n as GraphNode).id : null)}
          onBackgroundClick={() => onSelect(null)}
          nodeCanvasObject={(node, ctx, scale) => {
            const n = node as GraphNode;
            const active = isActive(n.id);
            const selected = n.id === selectedId;
            const r = radius(n);
            const x = n.x ?? 0;
            const y = n.y ?? 0;

            // soft outer glow / selected halo
            if (active) {
              ctx.beginPath();
              ctx.arc(x, y, r + (selected ? 7 : 4), 0, 2 * Math.PI);
              ctx.fillStyle = hexA(n.color, selected ? 0.22 : 0.1);
              ctx.fill();
            }

            // glossy sphere via radial gradient (light from upper-left)
            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            if (active) {
              const grad = ctx.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.1, x, y, r);
              grad.addColorStop(0, lighten(n.color, 0.28));
              grad.addColorStop(0.6, n.color);
              grad.addColorStop(1, darken(n.color, 0.08));
              ctx.fillStyle = grad;
            } else {
              ctx.fillStyle = hexA(n.color, 0.16);
            }
            ctx.fill();
            ctx.lineWidth = selected ? 2 : 1.2;
            ctx.strokeStyle = selected ? darken(n.color, 0.3) : 'rgba(255,255,255,0.9)';
            ctx.stroke();

            // label
            const fontSize = Math.max(11 / scale, 3);
            ctx.font = `${selected ? 700 : 500} ${fontSize}px Inter, sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'top';
            ctx.fillStyle = active ? '#0f2438' : 'rgba(133,149,166,0.55)';
            ctx.fillText(n.label, x, y + r + 3);
          }}
          nodePointerAreaPaint={(node, color, ctx) => {
            const n = node as GraphNode;
            const r = radius(n);
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.arc(n.x ?? 0, n.y ?? 0, r + 4, 0, 2 * Math.PI);
            ctx.fill();
          }}
        />
      )}
    </div>
  );
}
