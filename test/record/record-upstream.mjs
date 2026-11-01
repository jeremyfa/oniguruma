// Adds the results of the real vscode-oniguruma 2.0.1 to the converted upstream
// Oniguruma test cases (forward search cases with valid UTF-8 pattern and subject).
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
const wasm = fs.readFileSync(path.join(SCRATCH, '../node_modules/vscode-oniguruma/release/onig.wasm')).buffer;
await onig.loadWASM(wasm);

const [inDir, outDir] = process.argv.slice(2);
// FindOption enum order of vscode-oniguruma, with the ONIG_OPTION bit of each
const FIND_OPTIONS = ['Default', 'None', 'Ignorecase', 'Extend', 'Multiline', 'Singleline', 'FindLongest', 'FindNotEmpty',
  'NegateSingleline', 'DontCaptureGroup', 'CaptureGroup', 'Notbol', 'Noteol', 'CheckValidityOfString', 'IgnorecaseIsAscii',
  'WordIsAscii', 'DigitIsAscii', 'SpaceIsAscii', 'PosixIsAscii', 'TextSegmentExtendedGraphemeCluster', 'TextSegmentWord',
  'NotBeginString', 'NotEndString', 'NotBeginPosition', 'CallbackEachMatch', 'DebugCall'];
const BITS = { Ignorecase: 1, Extend: 2, Multiline: 4, Singleline: 8, FindLongest: 16, FindNotEmpty: 32, NegateSingleline: 64,
  DontCaptureGroup: 128, CaptureGroup: 256, Notbol: 512, Noteol: 1024, CheckValidityOfString: 4096,
  IgnorecaseIsAscii: 32768, WordIsAscii: 65536, DigitIsAscii: 131072, SpaceIsAscii: 262144, PosixIsAscii: 524288,
  TextSegmentExtendedGraphemeCluster: 1048576, TextSegmentWord: 2097152, NotBeginString: 4194304, NotEndString: 8388608,
  NotBeginPosition: 16777216 };
const SYNTAX = { DEFAULT: 0, PERL: 8, JAVA: 7, PYTHON: 11 };

function decodeUtf8(hex) {
  const b = Buffer.from(hex, 'hex');
  const s = b.toString('utf8');
  if (!Buffer.from(s, 'utf8').equals(b)) return null;
  return s;
}

for (const f of fs.readdirSync(inDir)) {
  const cases = JSON.parse(fs.readFileSync(path.join(inDir, f), 'utf8'));
  let n = 0;
  for (const c of cases) {
    if (c.back) continue;
    const p = decodeUtf8(c.p), s = decodeUtf8(c.s);
    if (p === null || s === null) continue;
    const opts = [10]; // CaptureGroup (the default of OnigScanner)
    for (const [name, bit] of Object.entries(BITS)) {
      if ((c.opt & bit) !== 0) opts.push(FIND_OPTIONS.indexOf(name));
    }
    let res;
    try {
      const scanner = new onig.OnigScanner([p], { options: opts, syntax: SYNTAX[c.syn] });
      const m = scanner.findNextMatchSync(s, 0);
      if (!m) res = 0;
      else {
        res = [m.index];
        for (const ci of m.captureIndices) res.push(ci.start, ci.end);
      }
      scanner.dispose();
    } catch (e) {
      res = 'error: ' + e.message;
    }
    c.vs = res;
    c.vsopt = opts;
    n++;
  }
  fs.writeFileSync(path.join(outDir, f), JSON.stringify(cases));
  console.log(f, cases.length, 'cases,', n, 'recorded with vscode-oniguruma');
}
