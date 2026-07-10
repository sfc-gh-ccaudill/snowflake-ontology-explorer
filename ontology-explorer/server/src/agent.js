import { generateJwt } from './jwt.js';
import { resolveHost } from './config.js';
import { ONTOLOGY } from './dbconfig.js';

/**
 * Streams an assistant reply over Server-Sent Events (SSE).
 *
 * Two modes:
 *  1. CORTEX_AGENT_NAME is set  -> call the real Cortex Agent REST API and
 *     forward its text deltas. (The agent does not exist yet in this demo, so
 *     this path is wired but untested against a live agent.)
 *  2. Not set (today's default) -> stream a clearly-labelled placeholder so the
 *     chat UI is fully interactive while the ontology + agent are being built.
 *
 * The frontend consumes: `data: {"delta":"..."}` events, then `data: {"done":true}`.
 */
// The ontology agents this app can talk to, by short UI key. Names are built
// from the configured ontology schema so a renamed deployment still resolves.
const AGENTS = {
    ontology: `${ONTOLOGY}.HEALTHCARE_ONTOLOGY_AGENT`,
    base: `${ONTOLOGY}.HEALTHCARE_BASE_AGENT`,
};
const DEFAULT_AGENT = AGENTS.ontology;

function resolveAgent(agent) {
    if (agent && AGENTS[agent]) return AGENTS[agent];                       // short key from the UI
    if (agent && Object.values(AGENTS).includes(agent)) return agent;       // already fully-qualified
    return process.env.CORTEX_AGENT_NAME || DEFAULT_AGENT;
}

export async function streamChat({ conn, messages, res, agent }) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const agentName = resolveAgent(agent);
    const question = messages[messages.length - 1]?.content || '';

    try {
        if (agentName) {
            await streamFromCortexAgent({ conn, agentName, messages, res });
        } else {
            await streamPlaceholder({ question, res });
        }
    } catch (err) {
        send(res, { delta: `\n\n⚠️ Agent error: ${err.message}` });
    } finally {
        send(res, { done: true });
        res.end();
    }
}

function send(res, obj) {
    res.write(`data: ${JSON.stringify(obj)}\n\n`);
}

// --- Placeholder mode (runs today) -----------------------------------------

async function streamPlaceholder({ question, res }) {
    send(res, { meta: { mode: 'placeholder' } });
    const reply =
        `I'm the ontology's data agent — but I'm not connected to a live Cortex Agent yet. ` +
        `Once the agent is created and CORTEX_AGENT_NAME is set, I'll answer this by querying the ` +
        `resolved ontology (Patients, Practitioners, Encounters, Medications…) across all three ` +
        `source systems.\n\n` +
        `You asked: "${question}"\n\n` +
        `A good first question to try then: "How many distinct patients did Dr. Chen treat, and what were they prescribed?"`;

    for (const token of reply.match(/\S+\s*/g) || []) {
        send(res, { delta: token });
        await sleep(18);
    }
}

// --- Live Cortex Agent mode (integration point) ----------------------------

async function streamFromCortexAgent({ conn, agentName, messages, res }) {
    const host = resolveHost(conn);
    const [database, schema, name] = agentName.split('.');
    if (!database || !schema || !name) {
        throw new Error('CORTEX_AGENT_NAME must be fully qualified: DB.SCHEMA.AGENT');
    }

    const token = generateJwt(conn);
    const url = `https://${host}/api/v2/databases/${database}/schemas/${schema}/agents/${name}:run`;

    const resp = await fetch(url, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${token}`,
            'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT',
            'Content-Type': 'application/json',
            Accept: 'text/event-stream',
        },
        body: JSON.stringify({
            messages: messages.map((m) => ({
                role: m.role,
                content: [{ type: 'text', text: m.content }],
            })),
        }),
    });

    if (!resp.ok || !resp.body) {
        const detail = await resp.text().catch(() => '');
        throw new Error(`Cortex Agent returned ${resp.status}. ${detail.slice(0, 300)}`);
    }

    send(res, { meta: { mode: 'agent', agent: agentName } });

    // The Cortex Agent SSE stream is a sequence of `event: <type>` + `data: <json>`
    // blocks. We forward:
    //   response.thinking.delta   -> { thinking }   (the agent's streamed reasoning)
    //   response.status           -> { status }     (step labels: planning, running SQL…)
    //   response.tool_use         -> { tool }       (tool name + generated SQL)
    //   response.text.delta       -> { delta }      (the actual answer text)
    //   response.suggested_queries-> { suggestions }(follow-up prompts)
    const reader = resp.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const chunks = buffer.split('\n\n');
        buffer = chunks.pop() || '';
        for (const chunk of chunks) {
            let event = null;
            let dataLine = null;
            for (const l of chunk.split('\n')) {
                if (l.startsWith('event:')) event = l.slice(6).trim();
                else if (l.startsWith('data:')) dataLine = l.slice(5).trim();
            }
            if (!dataLine || dataLine === '[DONE]') continue;
            let data;
            try {
                data = JSON.parse(dataLine);
            } catch {
                continue; // keep-alive / non-JSON
            }

            switch (event) {
                case 'response.thinking.delta':
                    if (data.text) send(res, { thinking: data.text });
                    break;
                case 'response.status':
                    if (data.message) send(res, { status: data.message });
                    break;
                case 'response.tool_use': {
                    const sql = data?.input?.sql;
                    send(res, { tool: { name: data.name, sql: sql || null } });
                    break;
                }
                case 'response.text.delta':
                    if (data.text) send(res, { delta: data.text });
                    break;
                case 'response.suggested_queries':
                    if (Array.isArray(data.suggested_queries)) {
                        send(res, { suggestions: data.suggested_queries.map((q) => q.query).filter(Boolean) });
                    }
                    break;
                default:
                    break; // response.tool_result.status, response.text, response, done…
            }
        }
    }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
