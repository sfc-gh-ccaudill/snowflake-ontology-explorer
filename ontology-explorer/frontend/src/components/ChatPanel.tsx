import { useEffect, useRef, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { streamChat, type ChatMessage } from '../api';

interface ToolCall {
  name?: string;
  sql?: string | null;
}

interface UiMessage extends ChatMessage {
  mode?: string;
  thinking?: string;
  steps?: string[];
  tools?: ToolCall[];
}

const SUGGESTIONS = [
  'How many distinct patients did Dr. Chen treat, and what were they prescribed?',
  'Which patients are on Atorvastatin across the EMR and pharmacy systems?',
  'Show diabetic patients (E11.9) with their most recent HbA1c.',
];

const AGENTS = [
  {
    key: 'ontology',
    label: 'Ontology agent',
  },
  {
    key: 'base',
    label: 'Base agent (raw tables)',
  },
];

function ThoughtTrace({ msg, live }: { msg: UiMessage; live: boolean }) {
  // Open while the agent is still working; collapse once the answer arrives.
  const [open, setOpen] = useState(true);
  const hasContent = !!msg.thinking || (msg.steps?.length ?? 0) > 0 || (msg.tools?.length ?? 0) > 0;
  useEffect(() => {
    if (!live && msg.content) setOpen(false);
  }, [live, msg.content]);
  if (!hasContent) return null;

  const lastStep = msg.steps?.[msg.steps.length - 1];
  return (
    <div className="thought">
      <button className="thought-head" onClick={() => setOpen((o) => !o)}>
        <span className={`thought-caret ${open ? 'open' : ''}`}>▸</span>
        <span className="thought-title">
          {live ? (lastStep || 'Thinking…') : 'Agent reasoning'}
        </span>
        {live && <span className="thought-spinner" />}
      </button>
      {open && (
        <div className="thought-body">
          {msg.thinking && <div className="thought-text">{msg.thinking}</div>}
          {msg.steps && msg.steps.length > 0 && (
            <ul className="thought-steps">
              {msg.steps.map((s, i) => (
                <li key={i} className={i === msg.steps!.length - 1 && live ? 'active' : ''}>
                  {s}
                </li>
              ))}
            </ul>
          )}
          {msg.tools?.map((t, i) =>
            t.sql ? (
              <div className="thought-sql" key={i}>
                <div className="thought-sql-label">{t.name || 'query'}</div>
                <pre>{t.sql}</pre>
              </div>
            ) : null
          )}
        </div>
      )}
    </div>
  );
}

export default function ChatPanel() {
  const [messages, setMessages] = useState<UiMessage[]>([]);
  const [input, setInput] = useState('');
  const [streaming, setStreaming] = useState(false);
  const [agent, setAgent] = useState(AGENTS[0].key);
  const scrollRef = useRef<HTMLDivElement>(null);
  const taRef = useRef<HTMLTextAreaElement>(null);

  // Switching agents starts a fresh conversation (new thread).
  const changeAgent = (key: string) => {
    if (key === agent) return;
    setAgent(key);
    setMessages([]);
    setInput('');
  };

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  const autosize = () => {
    const ta = taRef.current;
    if (!ta) return;
    ta.style.height = 'auto';
    ta.style.height = Math.min(ta.scrollHeight, 120) + 'px';
  };

  const patchLast = (fn: (m: UiMessage) => UiMessage) =>
    setMessages((m) => {
      const next = [...m];
      next[next.length - 1] = fn(next[next.length - 1]);
      return next;
    });

  const send = async (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || streaming) return;

    const history: ChatMessage[] = [
      ...messages.map((m) => ({ role: m.role, content: m.content })),
      { role: 'user', content: trimmed },
    ];
    setMessages((m) => [...m, { role: 'user', content: trimmed }, { role: 'assistant', content: '' }]);
    setInput('');
    setTimeout(autosize, 0);
    setStreaming(true);

    try {
      await streamChat(history, {
        onMeta: (meta) => patchLast((last) => ({ ...last, mode: meta.mode })),
        onThinking: (t) => patchLast((last) => ({ ...last, thinking: (last.thinking || '') + t })),
        onStatus: (s) =>
          patchLast((last) => {
            const steps = last.steps ? [...last.steps] : [];
            if (steps[steps.length - 1] !== s) steps.push(s);
            return { ...last, steps };
          }),
        onTool: (tool) =>
          patchLast((last) => ({ ...last, tools: [...(last.tools || []), tool] })),
        onDelta: (delta) => patchLast((last) => ({ ...last, content: last.content + delta })),
      }, agent);
    } catch (err) {
      patchLast((last) => ({ ...last, content: last.content + `\n\n⚠️ ${(err as Error).message}` }));
    } finally {
      setStreaming(false);
    }
  };

  return (
    <div className="chat">
      <div className="chat-agentbar">
        <label className="chat-agent-label" htmlFor="agent-select">Agent</label>
        <select
          id="agent-select"
          className="chat-agent-select"
          value={agent}
          disabled={streaming}
          onChange={(e) => changeAgent(e.target.value)}
        >
          {AGENTS.map((a) => (
            <option key={a.key} value={a.key}>{a.label}</option>
          ))}
        </select>
      </div>
      <div className="chat-scroll" ref={scrollRef}>
        {messages.length === 0 ? (
          <div className="chat-empty">
            <div style={{ fontWeight: 600, color: 'var(--text-2)' }}>Ask the ontology agent</div>
            <div style={{ fontSize: 13, marginTop: 4 }}>
              Natural-language questions answered across all three source systems.
            </div>
            <div className="suggestions">
              {SUGGESTIONS.map((s) => (
                <button className="suggestion" key={s} onClick={() => send(s)}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        ) : (
          messages.map((m, i) => {
            const isLast = i === messages.length - 1;
            const live = streaming && isLast && m.role === 'assistant';
            return (
              <div className={`msg ${m.role}`} key={i}>
                <div className="avatar">{m.role === 'user' ? 'You' : 'AI'}</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                  {m.mode === 'placeholder' && <span className="mode-tag">preview · agent not connected</span>}
                  {m.role === 'assistant' && <ThoughtTrace msg={m} live={live} />}
                  {(m.content || !live) && (
                    <div className={`bubble ${live && m.content ? 'cursor' : ''}`}>
                      {m.role === 'assistant' ? (
                        <div className="md">
                          <ReactMarkdown remarkPlugins={[remarkGfm]}>{m.content}</ReactMarkdown>
                        </div>
                      ) : (
                        m.content
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="composer">
        <textarea
          ref={taRef}
          value={input}
          placeholder="Ask about patients, providers, medications…"
          rows={1}
          onChange={(e) => {
            setInput(e.target.value);
            autosize();
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              send(input);
            }
          }}
        />
        <button className="send-btn" disabled={!input.trim() || streaming} onClick={() => send(input)}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" />
          </svg>
        </button>
      </div>
    </div>
  );
}
