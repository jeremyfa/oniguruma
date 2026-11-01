// Records the differential corpus with the real vscode-oniguruma 2.0.1:
// every regex of a set of TextMate grammars, scanned over sample lines.
// Output: fixtures/corpus-<lang>.json
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
const require = createRequire(path.join(process.env.ONIG_WORK || '.', 'x.js'));
const onig = require('vscode-oniguruma');

// WORK is a folder outside the repository with node_modules/vscode-oniguruma (npm i vscode-oniguruma@2.0.1),
// vsonig (vscode-oniguruma git checkout at v2.0.1) and onigc (Oniguruma git checkout at 08d3611).
const WORK = process.env.ONIG_WORK;
if (!WORK) throw new Error('set ONIG_WORK');
const SCRATCH = path.join(WORK, 'rec');
const OUT = process.argv[2];
const wasm = fs.readFileSync(path.join(SCRATCH, '../node_modules/vscode-oniguruma/release/onig.wasm')).buffer;
await onig.loadWASM(wasm);

// Escapes U+2013 and U+2014 so the fixtures stay ASCII for those two characters.
const noDash = (s) => s.replace(/[\u2013\u2014]/g, (c) => '\\u' + c.charCodeAt(0).toString(16));

const LANGS = '/Users/jeremyfa/Developer/loreline/node_modules/@shikijs/langs/dist';
function loadShikiGrammars(name) {
  const src = fs.readFileSync(path.join(LANGS, name + '.mjs'), 'utf8');
  const m = src.match(/JSON\.parse\(("(?:[^"\\]|\\.)*")\)/);
  return JSON.parse(JSON.parse(m[1]));
}

function collectRegexes(g, out, listsOut) {
  const seen = new Set(out);
  function addRe(r) { if (typeof r === 'string' && !seen.has(r)) { seen.add(r); out.push(r); } }
  function walkRule(rule) {
    if (!rule || typeof rule !== 'object') return;
    addRe(rule.match); addRe(rule.begin); addRe(rule.end); addRe(rule.while);
    for (const k of ['captures', 'beginCaptures', 'endCaptures', 'whileCaptures']) {
      if (rule[k]) for (const c of Object.values(rule[k])) walkRule(c);
    }
    if (rule.patterns) walkList(rule.patterns);
    if (rule.repository) for (const r of Object.values(rule.repository)) walkRule(r);
    if (rule.injections) for (const r of Object.values(rule.injections)) walkRule(r);
  }
  function walkList(list) {
    const res = [];
    for (const r of list) { walkRule(r); const x = r.match || r.begin; if (typeof x === 'string') res.push(x); }
    if (res.length > 1 && listsOut) listsOut.push(res);
  }
  walkRule(g);
}

function readLines(files, max) {
  const lines = [];
  for (const f of files) {
    for (const l of fs.readFileSync(f, 'utf8').split(/\r?\n/)) {
      if (l.trim().length === 0) continue;
      lines.push(l);
      if (lines.length >= max) return lines;
    }
  }
  return lines;
}

const VS = path.join(SCRATCH, '../vsonig');
const UNICODE_LINES = [
  'café = "naïve résumé" // ünïcödé',
  'const 名前 = "日本語のテキスト"; // コメント',
  'let emoji = "😀 👍🏽 🇫🇷 👨‍👩‍👧";',
  'Возврат значения: 42 \u2014 αβγ ΔΕΖ',
  'x' + String.fromCharCode(0xd83c) + 'y lone surrogate',
  '\tTab\tseparated\tvalues ẞ ß ﬀ İ ı',
  '',
];

const SETS = [
  { lang: 'json', grammars: ['json'], files: [path.join(VS, 'package.json'), path.join(VS, 'tsconfig.json')] },
  { lang: 'javascript', grammars: ['javascript'], files: [path.join(VS, 'webpack.config.js'), path.join(VS, 'scripts/remove-print.js'), path.join(VS, 'scripts/cp.js')] },
  { lang: 'typescript', grammars: ['typescript'], files: [path.join(VS, 'src/index.ts')] },
  { lang: 'haxe', grammars: ['haxe'], files: ['/Users/jeremyfa/Developer/ceramic/git/oniguruma/src/oniguruma/OnigScanner.hx'] },
  { lang: 'rust', grammars: ['rust'], files: [path.join(process.env.HOME, '.cargo/registry/src', fs.readdirSync(path.join(process.env.HOME, '.cargo/registry/src'))[0], 'unicode-segmentation-1.13.2/src/lib.rs')] },
  { lang: 'markdown', grammars: ['markdown'], files: [path.join(VS, 'README.md'), path.join(SCRATCH, '../onigc/README.md')] },
  { lang: 'html', grammars: ['html'], files: ['/Users/jeremyfa/Developer/loreline-monaco/index.html'] },
  { lang: 'css', grammars: ['css'], files: ['/Users/jeremyfa/Developer/loreline-monaco/src/style.css'] },
  { lang: 'yaml', grammars: ['yaml'], files: [path.join(VS, 'build/pipeline.yml'), '/Users/jeremyfa/Developer/ceramic/sample/ceramic.yml'] },
  { lang: 'shellscript', grammars: ['shellscript'], files: [path.join(VS, 'build/setup-emsdk.sh'), path.join(VS, 'scripts/build.sh')] },
  { lang: 'loreline', grammarFile: '/Users/jeremyfa/Developer/loreline/language/loreline.tmLanguage.json', files: fs.readdirSync('/Users/jeremyfa/Developer/loreline/test-syntax').filter(f => f.endsWith('.lor')).map(f => '/Users/jeremyfa/Developer/loreline/test-syntax/' + f) },
];

const MAX_LINES = parseInt(process.env.MAX_LINES || '40');
let totalCalls = 0, totalTime = 0;
const stats = [];

function encodeMatch(m) {
  if (!m) return 0;
  const a = [m.index];
  for (const c of m.captureIndices) a.push(c.start, c.end);
  return a;
}

for (const set of SETS) {
  let regexes = [], lists = [];
  if (set.grammarFile) {
    collectRegexes(JSON.parse(fs.readFileSync(set.grammarFile, 'utf8')), regexes, lists);
  } else {
    for (const g of set.grammars) collectRegexes(loadShikiGrammars(g), regexes, lists);
  }
  let lines = readLines(set.files, MAX_LINES).concat(UNICODE_LINES);
  // a long line (more than 1000 UTF-8 bytes) to use the per regex search path of the scanner
  lines.push(lines.slice(0, 30).join('  ').slice(0, 1500));
  const strings = lines.map(l => onig.createOnigString(l));

  const entries = [];
  const table = [];
  const tableIndex = new Map();
  const idx = (r) => { if (!tableIndex.has(r)) { tableIndex.set(r, table.length); table.push(r); } return tableIndex.get(r); };
  const scannerSets = regexes.map(r => [r]).concat(lists.slice(0, 200));
  for (const pats of scannerSets) {
    let scanner;
    try {
      scanner = new onig.OnigScanner(pats);
    } catch (e) {
      entries.push({ p: pats.map(idx), err: String(e.message) });
      continue;
    }
    const res = [];
    for (let li = 0; li < lines.length; li++) {
      const s = strings[li];
      const len = lines[li].length;
      let pos = 0;
      const seenPos = new Set();
      const positions = [0, 1, Math.floor(len / 2), len];
      let k = 0;
      // successive matches from 0, like a tokenizer, plus a few fixed positions
      while (pos <= len && k < 64) {
        seenPos.add(pos);
        const t0 = process.hrtime.bigint();
        const m = scanner.findNextMatchSync(s, pos);
        totalTime += Number(process.hrtime.bigint() - t0);
        totalCalls++;
        res.push([li, pos, encodeMatch(m)]);
        if (!m) break;
        const e = m.captureIndices[0].end;
        pos = e > pos ? e : pos + 1;
        k++;
      }
      for (const p of positions) {
        if (seenPos.has(p) || p > len) continue;
        const t0 = process.hrtime.bigint();
        const m = scanner.findNextMatchSync(s, p);
        totalTime += Number(process.hrtime.bigint() - t0);
        totalCalls++;
        res.push([li, p, encodeMatch(m)]);
      }
    }
    entries.push({ p: pats.map(idx), r: res });
    scanner.dispose();
  }
  fs.writeFileSync(path.join(OUT, 'corpus-' + set.lang + '.json'), noDash(JSON.stringify({ lang: set.lang, lines, regexes: table, entries })));
  stats.push(`${set.lang}: ${regexes.length} regexes, ${lists.length} lists, ${lines.length} lines, ${entries.reduce((a, e) => a + (e.r ? e.r.length : 0), 0)} calls`);
}
fs.writeFileSync(path.join(OUT, 'corpus-timing.json'), JSON.stringify({ calls: totalCalls, nanos: totalTime }));
console.log(stats.join('\n'));
console.log('total calls', totalCalls, 'wasm time ms', (totalTime / 1e6).toFixed(1), 'per call us', (totalTime / totalCalls / 1000).toFixed(2));
