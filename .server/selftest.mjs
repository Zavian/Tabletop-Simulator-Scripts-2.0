// Runs server.mjs against a fake TTS: tts_lua round trip + failure path.
import net from 'node:net';
import assert from 'node:assert';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));

const fake = net.createServer((sock) => {
  let buf = '';
  sock.on('data', (d) => (buf += d));
  sock.on('end', () => {
    const msg = JSON.parse(buf);
    if (msg.messageID !== 3) return;
    const back = net.connect(39988, '127.0.0.1');
    back.end(JSON.stringify({ messageID: 5, returnID: Number(msg.returnID), returnValue: '{"ok":true}' }));
  });
});

const srv = spawn('node', [path.join(dir, 'server.mjs')], { stdio: ['pipe', 'pipe', 'inherit'], env: { ...process.env, TTS_SEND_PORT: '39989', TTS_LISTEN_PORT: '39988' } });
const waiters = new Map();
let out = '';
srv.stdout.on('data', (d) => {
  out += d;
  let i;
  while ((i = out.indexOf('\n')) >= 0) {
    const m = JSON.parse(out.slice(0, i));
    out = out.slice(i + 1);
    waiters.get(m.id)?.(m);
  }
});
let nextId = 1;
const rpc = (method, params) =>
  new Promise((resolve) => {
    const id = nextId++;
    waiters.set(id, resolve);
    srv.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });

try {
  await rpc('initialize', { protocolVersion: '2024-11-05' });
  const list = await rpc('tools/list');
  assert.equal(list.result.tools.length, 7);

  const down = await rpc('tools/call', { name: 'tts_lua', arguments: { script: 'return 1' } });
  assert.equal(down.result.isError, true, 'TTS down must be a tool error');

  await new Promise((r) => fake.listen(39989, '127.0.0.1', r));
  const up = await rpc('tools/call', { name: 'tts_lua', arguments: { script: 'return {ok=true}' } });
  assert.ok(!up.result.isError && up.result.content[0].text.includes('"ok":true'), JSON.stringify(up));
  console.log('selftest ok');
} finally {
  srv.kill();
  fake.close();
}
