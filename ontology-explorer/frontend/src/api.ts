// Typed client for the ontology-explorer backend (proxied at /api).

export interface GraphNode {
  id: string;
  label: string;
  group: string;
  color: string;
  degree: number;
  // react-force-graph mutates these at runtime:
  x?: number;
  y?: number;
}

export interface GraphLink {
  source: string | GraphNode;
  target: string | GraphNode;
  label: string;
}

export interface GroupInfo {
  label: string;
  color: string;
}

export interface Ontology {
  nodes: GraphNode[];
  links: GraphLink[];
  groups: Record<string, GroupInfo>;
}

export interface NodeMapping {
  system: string;
  table: string;
  note?: string;
}

export interface NodeProperty {
  name: string;
  description: string;
}

export interface NodeRelationship {
  label: string;
  direction: 'in' | 'out';
  other: string;
}

export interface NodeDetail {
  id: string;
  label: string;
  group: string;
  groupLabel: string;
  color: string;
  description: string;
  properties: NodeProperty[];
  mappings: NodeMapping[];
  relationships: NodeRelationship[];
  sampleQuery?: string;
}

export interface SampleData {
  available: boolean;
  sql?: string;
  columns?: string[];
  rows?: Record<string, unknown>[];
  reason?: string;
  error?: string;
}

export interface Health {
  ok: boolean;
  connection?: string;
  account?: string;
  user?: string;
  role?: string;
  warehouse?: string;
  agentConfigured?: boolean;
  error?: string;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

// ---- Overview + Source-schema types ---------------------------------------

export interface Challenge {
  id: number;
  title: string;
  blurb: string;
}

export interface Overview {
  sourceSystems: number;
  sourceTables: number;
  classes: number;
  relationships: number;
  challenges: Challenge[];
}

export interface ColumnLink {
  kind: string;
  label: string;
}

export interface SourceColumn {
  name: string;
  type: string;
  ordinal: number;
  link: ColumnLink | null;
}

export interface ClassRef {
  id: string;
  label: string;
  color: string;
}

export interface SourceTable {
  name: string;
  description: string;
  overloaded?: boolean;
  classes: ClassRef[];
  columns: SourceColumn[];
}

export interface SourceSystem {
  db: string;
  schema: string;
  label: string;
  color: string;
  description: string;
  tables: SourceTable[];
}

export interface SourceDataset {
  key: string; // 'raw' | 'metadata' | 'views'
  label: string;
  description: string;
  systems: SourceSystem[];
}

export interface SourceSchema {
  datasets: SourceDataset[];
  liveColumns: boolean;
  linkageKinds: Record<string, { label: string; color: string }>;
}

// ---- Knowledge graph (instance-level, real data) --------------------------

export interface KGNode {
  id: string;
  label: string;
  cls: string;
  group: string;
  color: string;
  degree: number;
  detail?: string;
  // react-force-graph mutates these at runtime:
  x?: number;
  y?: number;
}

export interface KGLink {
  source: string | KGNode;
  target: string | KGNode;
  label: string;
}

export interface KnowledgeGraph {
  nodes: KGNode[];
  links: KGLink[];
  groups: Record<string, GroupInfo>;
  stats: { patients: number; nodes: number; links: number };
}

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url} → ${res.status}`);
  return res.json() as Promise<T>;
}

export const api = {
  health: () => getJson<Health>('/api/health'),
  ontology: () => getJson<Ontology>('/api/ontology'),
  node: (id: string) => getJson<NodeDetail>(`/api/node/${id}`),
  sample: (id: string) => getJson<SampleData>(`/api/node/${id}/sample`),
  sampleTable: (db: string, schema: string, table: string) =>
    getJson<SampleData>(
      `/api/sample?db=${encodeURIComponent(db)}&schema=${encodeURIComponent(schema)}&table=${encodeURIComponent(table)}`
    ),
  overview: () => getJson<Overview>('/api/overview'),
  sourceSchema: () => getJson<SourceSchema>('/api/source-schema'),
  knowledgeGraph: (patients: number) =>
    getJson<KnowledgeGraph>(`/api/knowledge-graph?patients=${patients}`),
};

/**
 * POSTs the conversation and streams the assistant reply.
 * Calls onDelta for each text chunk and onMeta once (if the server sends it).
 */
export async function streamChat(
  messages: ChatMessage[],
  handlers: {
    onDelta: (text: string) => void;
    onMeta?: (meta: { mode?: string; agent?: string }) => void;
    onThinking?: (text: string) => void;
    onStatus?: (message: string) => void;
    onTool?: (tool: { name?: string; sql?: string | null }) => void;
    onSuggestions?: (queries: string[]) => void;
  },
  agent?: string
): Promise<void> {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages, agent }),
  });
  if (!res.body) throw new Error('No response stream');

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const parts = buffer.split('\n\n');
    buffer = parts.pop() || '';
    for (const part of parts) {
      const line = part.split('\n').find((l) => l.startsWith('data:'));
      if (!line) continue;
      try {
        const evt = JSON.parse(line.slice(5).trim());
        if (evt.delta) handlers.onDelta(evt.delta);
        if (evt.meta && handlers.onMeta) handlers.onMeta(evt.meta);
        if (evt.thinking && handlers.onThinking) handlers.onThinking(evt.thinking);
        if (evt.status && handlers.onStatus) handlers.onStatus(evt.status);
        if (evt.tool && handlers.onTool) handlers.onTool(evt.tool);
        if (evt.suggestions && handlers.onSuggestions) handlers.onSuggestions(evt.suggestions);
        if (evt.done) return;
      } catch {
        /* ignore */
      }
    }
  }
}
