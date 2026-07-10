import { useEffect, useRef, useState } from 'react';
import Header from './components/Header';
import NavRail, { type View } from './components/NavRail';
import GraphCanvas from './components/GraphCanvas';
import Legend from './components/Legend';
import Inspector from './components/Inspector';
import ChatPanel from './components/ChatPanel';
import TableInspector from './components/TableInspector';
import OverviewView from './views/OverviewView';
import SourceView from './views/SourceView';
import KnowledgeGraphView from './views/KnowledgeGraphView';
import ArchitectureView from './views/ArchitectureView';
import { api, type Ontology, type SourceSchema } from './api';

type SideTab = 'primary' | 'chat';

const MIN_SIDEBAR = 320;
const MAX_SIDEBAR = 900;
const DEFAULT_SIDEBAR = 400;
const clampWidth = (w: number) => Math.max(MIN_SIDEBAR, Math.min(MAX_SIDEBAR, w));

export default function App() {
  const [ontology, setOntology] = useState<Ontology | null>(null);
  const [schema, setSchema] = useState<SourceSchema | null>(null);
  const [view, setView] = useState<View>('overview');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTableKey, setSelectedTableKey] = useState<string | null>(null);
  const [sourceDataset, setSourceDataset] = useState<string>('raw');
  const [sideTab, setSideTab] = useState<SideTab>('primary');
  const [sidebarWidth, setSidebarWidth] = useState<number>(() => {
    const saved = Number(localStorage.getItem('sidebarWidth'));
    return saved ? clampWidth(saved) : DEFAULT_SIDEBAR;
  });
  const [error, setError] = useState<string | null>(null);
  const dragStart = useRef<{ x: number; width: number } | null>(null);

  useEffect(() => {
    localStorage.setItem('sidebarWidth', String(sidebarWidth));
  }, [sidebarWidth]);

  // Drag the handle on the sidebar's left edge to resize it.
  const startResize = (e: React.MouseEvent) => {
    e.preventDefault();
    dragStart.current = { x: e.clientX, width: sidebarWidth };
    document.body.classList.add('resizing-x');
    const onMove = (ev: MouseEvent) => {
      if (!dragStart.current) return;
      // Sidebar is on the right, so dragging left (smaller clientX) widens it.
      const delta = dragStart.current.x - ev.clientX;
      setSidebarWidth(clampWidth(dragStart.current.width + delta));
    };
    const onUp = () => {
      dragStart.current = null;
      document.body.classList.remove('resizing-x');
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
    };
    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  };

  useEffect(() => {
    api.ontology().then(setOntology).catch((e) => setError(e.message));
    api.sourceSchema().then(setSchema).catch(() => {});
  }, []);

  // Cross-navigation between the two views.
  const openClass = (id: string | null) => {
    setSelectedId(id);
    if (id) {
      setView('ontology');
      setSideTab('primary');
    }
  };
  const openTable = (db: string, table: string) => {
    setSelectedTableKey(`${db}.${table}`);
    setView('source');
    setSideTab('primary');
  };

  const showSidebar = view === 'ontology' || view === 'source';
  const primaryLabel = view === 'source' ? 'Table' : 'Inspector';
  const activeSystems = schema?.datasets.find((d) => d.key === sourceDataset)?.systems ?? [];

  return (
    <div className="app">
      <Header />
      <div className="app-body">
        <NavRail view={view} onSelect={setView} />

        <main className="view-area">
          {view === 'overview' && <OverviewView onOpen={setView} />}

          {view === 'ontology' &&
            (ontology ? (
              <div className="canvas-outer">
                <GraphCanvas ontology={ontology} selectedId={selectedId} onSelect={openClass} />
                <Legend groups={ontology.groups} />
              </div>
            ) : (
              <div className="empty-state" style={{ height: '100%' }}>
                {error ? `Failed to load ontology: ${error}` : 'Loading ontology…'}
              </div>
            ))}

          {view === 'source' && (
            <div className="source-scroll">
              <SourceView
                schema={schema}
                dataset={sourceDataset}
                onDatasetChange={(k) => {
                  setSourceDataset(k);
                  setSelectedTableKey(null);
                }}
                selectedKey={selectedTableKey}
                onSelectTable={(db, t) => {
                  setSelectedTableKey(`${db}.${t}`);
                  setSideTab('primary');
                }}
                onOpenClass={openClass}
              />
            </div>
          )}

          {view === 'data' && (
            <div className="canvas-outer">
              <KnowledgeGraphView />
            </div>
          )}

          {view === 'architecture' && (
            <div className="arch-outer">
              <ArchitectureView />
            </div>
          )}
        </main>

        {showSidebar && (
          <aside className="sidebar" style={{ width: sidebarWidth }}>
            <div
              className="sidebar-resizer"
              onMouseDown={startResize}
              onDoubleClick={() => setSidebarWidth(DEFAULT_SIDEBAR)}
              role="separator"
              aria-orientation="vertical"
              title="Drag to resize · double-click to reset"
            />
            <div className="tabs">
              <button className={`tab ${sideTab === 'primary' ? 'active' : ''}`} onClick={() => setSideTab('primary')}>
                {primaryLabel}
              </button>
              <button className={`tab ${sideTab === 'chat' ? 'active' : ''}`} onClick={() => setSideTab('chat')}>
                Agent Chat
              </button>
            </div>
            <div className="tab-body" style={sideTab === 'chat' ? { padding: 0 } : undefined}>
              {sideTab === 'chat' ? (
                <ChatPanel />
              ) : view === 'source' ? (
                <TableInspector systems={activeSystems} selectedKey={selectedTableKey} onOpenClass={openClass} />
              ) : (
                <Inspector nodeId={selectedId} onSelect={openClass} onOpenTable={openTable} />
              )}
            </div>
          </aside>
        )}
      </div>
    </div>
  );
}
