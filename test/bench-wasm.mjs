// The same benchmark as src/Bench.hx with the real vscode-oniguruma 2.0.1 (onig.wasm).
// Usage: node bench-wasm.mjs <path to node_modules containing vscode-oniguruma> [fixtures dir] [rounds]
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
const [modules, dir = 'fixtures', roundsArg = '3'] = process.argv.slice(2);
const require = createRequire(path.join(modules, 'x.js'));
const onig = require('vscode-oniguruma');
let wasmMemory = null;
const wasmData = fs.readFileSync(path.join(modules, 'vscode-oniguruma/release/onig.wasm')).buffer;
await onig.loadWASM({ instantiator: async (imports) => {
  const r = await WebAssembly.instantiate(wasmData, imports);
  for (const v of Object.values(r.instance.exports)) if (v instanceof WebAssembly.Memory) wasmMemory = v;
  for (const ns of Object.values(imports || {})) for (const v of Object.values(ns)) if (v instanceof WebAssembly.Memory) wasmMemory = v;
  return r;
} });
const sets = [];
let compile = 0, numScanners = 0;
for (const f of fs.readdirSync(dir).sort()) {
  if (!f.startsWith('corpus-') || f === 'corpus-timing.json') continue;
  const data = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  const strings = data.lines.map(l => onig.createOnigString(l));
  for (const e of data.entries) {
    if (e.err) continue;
    const t0 = performance.now();
    const scanner = new onig.OnigScanner(e.p.map(i => data.regexes[i]));
    compile += performance.now() - t0;
    numScanners++;
    const calls = [];
    for (const r of e.r) calls.push(r[0], r[1]);
    sets.push({ scanner, strings, calls });
  }
}
function memory() {
  if (global.gc) { global.gc(); global.gc(); }
  const m = process.memoryUsage();
  return `${(m.heapUsed / 1048576).toFixed(0)} MB heap, ${(m.arrayBuffers / 1048576).toFixed(0)} MB array buffers, ${(wasmMemory.buffer.byteLength / 1048576).toFixed(0)} MB wasm memory`;
}
console.log('memory after compile: ' + memory());
let numCalls = 0;
for (const s of sets) numCalls += s.calls.length / 2;
console.log(`scanners: ${numScanners}, compile: ${compile.toFixed(0)} ms (${(compile * 1000 / numScanners).toFixed(0)} us per scanner)`);
for (let r = 0; r < parseInt(roundsArg); r++) {
  const t0 = performance.now();
  for (const s of sets) {
    const c = s.calls;
    for (let i = 0; i < c.length; i += 2) s.scanner.findNextMatchSync(s.strings[c[i]], c[i + 1]);
  }
  const t = performance.now() - t0;
  console.log(`round ${r}: ${numCalls} calls in ${t.toFixed(0)} ms, ${(t * 1000 / numCalls).toFixed(3)} us per call`);
}
console.log('memory after searches: ' + memory());
globalThis.keep = sets;
