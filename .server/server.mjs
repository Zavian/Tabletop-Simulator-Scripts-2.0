// MCP server (stdio, zero deps) bridging Claude to a running Tabletop Simulator
// through the External Editor API: https://api.tabletopsimulator.com/externaleditorapi/
import net from 'node:net';
import path from 'node:path';
import readline from 'node:readline';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HOST = '127.0.0.1';
const SEND_PORT = Number(process.env.TTS_SEND_PORT) || 39999; // TTS listens here
const LISTEN_PORT = Number(process.env.TTS_LISTEN_PORT) || 39998; // TTS connects here
const CAPTURE = path.join(path.dirname(fileURLToPath(import.meta.url)), 'capture.ps1');
const EXEC_TIMEOUT_MS = 10000;

const log = (...a) => console.error('[tts-mcp]', ...a);

// ---- TTS side -------------------------------------------------------------

const pending = new Map(); // returnID -> {resolve, reject, timer}
const collectors = new Set(); // arrays receiving incoming messageID 0 script states
const messages = []; // ring buffer of print / error / custom messages
let listening = false;
let lastReturnID = 100000 + Math.floor(Math.random() * 900000);

function record(entry) {
  messages.push({ time: new Date().toISOString(), ...entry });
  if (messages.length > 200) messages.shift();
}

function onIncoming(msg) {
  switch (msg.messageID) {
    case 0: // object pushed
    case 1: // reply to Get Lua Scripts (whole game)
      for (const c of collectors) c.push(...(msg.scriptStates || []));
      break;
    case 2:
      record({ type: 'print', message: msg.message });
      break;
    case 3:
      record({ type: 'error', error: msg.error, guid: msg.guid, prefix: msg.errorMessagePrefix });
      break;
    case 4:
      record({ type: 'custom', message: msg.customMessage });
      break;
    case 5: {
      const p = pending.get(String(msg.returnID));
      if (!p) {
        record({ type: 'unmatched-return', returnID: msg.returnID, returnValue: msg.returnValue });
        break;
      }
      clearTimeout(p.timer);
      pending.delete(String(msg.returnID));
      p.resolve(msg.returnValue);
      break;
    }
  }
}

function startListener() {
  const server = net.createServer((sock) => {
    let buf = '';
    const flush = () => {
      if (!buf) return;
      try {
        onIncoming(JSON.parse(buf));
        buf = '';
      } catch {} // partial JSON: wait for more data or 'end'
    };
    sock.setEncoding('utf8');
    sock.on('data', (d) => { buf += d; flush(); });
    sock.on('end', () => { flush(); if (buf) log('dropped unparsable message'); });
    sock.on('error', () => {});
  });
  server.on('error', (e) => log(`cannot listen on ${LISTEN_PORT} (${e.code}); replies from TTS unavailable`));
  server.listen(LISTEN_PORT, HOST, () => { listening = true; });
}

function sendToTTS(obj) {
  return new Promise((resolve, reject) => {
    const sock = net.connect(SEND_PORT, HOST);
    sock.on('error', (e) => reject(new Error(`cannot reach TTS on ${HOST}:${SEND_PORT} (${e.code}). Is TTS running with a game loaded?`)));
    sock.on('connect', () => sock.end(JSON.stringify(obj), () => resolve()));
  });
}

async function execLua(script, guid = '-1') {
  if (!listening) throw new Error(`port ${LISTEN_PORT} is taken (another editor open?), cannot receive replies from TTS`);
  const returnID = String(++lastReturnID); // TTS echoes it back as a number, so keep it numeric
  const reply = new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(returnID);
      reject(new Error('no reply from TTS within 10s. Is a game loaded? Did the Lua `return` a value? See tts_log for errors.'));
    }, EXEC_TIMEOUT_MS);
    pending.set(returnID, { resolve, reject, timer });
  });
  try {
    await sendToTTS({ messageID: 3, returnID, guid, script });
  } catch (e) {
    clearTimeout(pending.get(returnID)?.timer);
    pending.delete(returnID);
    reply.catch(() => {});
    throw e;
  }
  return reply;
}

const luaStr = (s) => `"${String(s).replace(/[\\"]/g, '\\$&').replace(/\n/g, '\\n')}"`;

function objectsLua({ tag, name_contains }) {
  return `
local out = {}
local function r(n) return math.floor(n * 100 + 0.5) / 100 end
local function v(t) return {x = r(t.x), y = r(t.y), z = r(t.z)} end
local tag, sub = ${tag ? luaStr(tag) : 'nil'}, ${name_contains ? luaStr(name_contains.toLowerCase()) : 'nil'}
for _, o in ipairs(getObjects()) do
  local ok = true
  if tag and not o.hasTag(tag) then ok = false end
  if ok and sub and not string.find(string.lower(o.getName()), sub, 1, true) then ok = false end
  if ok then
    out[#out + 1] = {guid = o.guid, name = o.getName(), description = o.getDescription(), type = o.type,
      tags = o.getTags(), position = v(o.getPosition()), rotation = v(o.getRotation()),
      scale = v(o.getScale()), locked = o.locked}
  end
end
return JSON.encode(out)`;
}

// ---- screenshot -----------------------------------------------------------

function runCapture(args) {
  return new Promise((resolve, reject) => {
    const ps = spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', CAPTURE, ...args]);
    let out = '', err = '';
    ps.stdout.on('data', (d) => (out += d));
    ps.stderr.on('data', (d) => (err += d));
    ps.on('error', reject);
    ps.on('close', (code) => (code === 0 ? resolve(out.trim()) : reject(new Error(err.trim() || `capture exited ${code}`))));
  });
}

// ---- tools ----------------------------------------------------------------

const text = (v) => ({ content: [{ type: 'text', text: typeof v === 'string' ? v : JSON.stringify(v, null, 2) }] });
const obj = (properties = {}, required = []) => ({ type: 'object', properties, required });

const tools = [
  {
    name: 'tts_status',
    description: 'Check the bridge: is TTS reachable on its API port, is our reply listener up, is a TTS window open.',
    inputSchema: obj(),
    async run() {
      const reachable = await new Promise((res) => {
        const s = net.connect(SEND_PORT, HOST);
        s.on('connect', () => { s.destroy(); res(true); });
        s.on('error', () => res(false));
      });
      const window = await runCapture(['-List']).catch((e) => `error: ${e.message}`);
      return text({ ttsApiReachable: reachable, replyListenerUp: listening, window });
    },
  },
  {
    name: 'tts_lua',
    description: 'Run Lua in TTS (Global by default, or an object by guid) and return its result. The Lua MUST `return` a number, string or boolean to get output back; a returned Lua table gets NO reply, so return `JSON.encode(tbl)` instead. `print` output goes to tts_log.',
    inputSchema: obj({ script: { type: 'string' }, guid: { type: 'string', description: 'Object guid; default "-1" = Global' } }, ['script']),
    async run({ script, guid }) {
      return text(await execLua(script, guid));
    },
  },
  {
    name: 'tts_log',
    description: 'Return buffered print / error / custom messages from TTS (last 200).',
    inputSchema: obj({ limit: { type: 'number' }, clear: { type: 'boolean' } }),
    async run({ limit = 50, clear = false }) {
      const out = messages.slice(-limit);
      if (clear) messages.length = 0;
      return text(out);
    },
  },
  {
    name: 'tts_objects',
    description: 'List table objects (guid, name, type, tags, position, rotation, scale, locked), optionally filtered by tag or name substring.',
    inputSchema: obj({ tag: { type: 'string' }, name_contains: { type: 'string' } }),
    async run(args) {
      return text(JSON.parse(await execLua(objectsLua(args))));
    },
  },
  {
    name: 'tts_get_scripts',
    description: 'List every script TTS holds (guid, name, script length). Pass guid to get that script body.',
    inputSchema: obj({ guid: { type: 'string' } }),
    async run({ guid }) {
      if (!listening) throw new Error(`port ${LISTEN_PORT} is taken, cannot receive scripts`);
      const got = [];
      collectors.add(got);
      try {
        await sendToTTS({ messageID: 0 });
        await new Promise((r) => setTimeout(r, 2000));
      } finally {
        collectors.delete(got);
      }
      if (guid) {
        const s = got.find((x) => x.guid === guid);
        if (!s) throw new Error(`no script for guid ${guid}`);
        return text(s);
      }
      return text(got.map((s) => ({ guid: s.guid, name: s.name, scriptLength: (s.script || '').length })));
    },
  },
  {
    name: 'tts_reload',
    description: 'Save & Play: push scripts to TTS. WARNING: reloads the whole game state (all object scripts restart).',
    inputSchema: obj({
      scripts: { type: 'array', items: obj({ guid: { type: 'string' }, script: { type: 'string' }, ui: { type: 'string' } }, ['guid', 'script']) },
    }, ['scripts']),
    async run({ scripts }) {
      await sendToTTS({ messageID: 1, scriptStates: scripts });
      return text('sent');
    },
  },
  {
    name: 'tts_screenshot',
    description: 'Screenshot the TTS game window (client area) as a PNG. foreground=true brings the window to the front first, which steals focus.',
    inputSchema: obj({ max_width: { type: 'number' }, foreground: { type: 'boolean' } }),
    async run({ max_width = 1280, foreground = true }) {
      const args = ['-MaxWidth', String(max_width)];
      if (foreground) args.push('-Foreground');
      const data = await runCapture(args);
      return { content: [{ type: 'image', data, mimeType: 'image/png' }] };
    },
  },
];

// ---- MCP JSON-RPC ---------------------------------------------------------

const send = (m) => process.stdout.write(JSON.stringify({ jsonrpc: '2.0', ...m }) + '\n');

async function handle(req) {
  const { id, method, params } = req;
  const reply = id !== undefined;
  switch (method) {
    case 'initialize':
      return send({ id, result: { protocolVersion: params?.protocolVersion || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'tts-mcp', version: '0.1.0' } } });
    case 'ping':
      return send({ id, result: {} });
    case 'tools/list':
      return send({ id, result: { tools: tools.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) } });
    case 'tools/call': {
      const tool = tools.find((t) => t.name === params?.name);
      if (!tool) return send({ id, error: { code: -32602, message: `unknown tool ${params?.name}` } });
      try {
        return send({ id, result: await tool.run(params.arguments || {}) });
      } catch (e) {
        return send({ id, result: { content: [{ type: 'text', text: e.message }], isError: true } });
      }
    }
    default:
      if (reply) send({ id, error: { code: -32601, message: `method not found: ${method}` } });
  }
}

startListener();
readline.createInterface({ input: process.stdin }).on('line', (line) => {
  if (!line.trim()) return;
  try {
    handle(JSON.parse(line));
  } catch (e) {
    log('bad request', e.message);
  }
});
