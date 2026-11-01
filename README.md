# oniguruma (Haxe port)

A pure Haxe port of [Oniguruma](https://github.com/kkos/oniguruma) **6.9.8** (commit `08d3611`), the regular expression library written in C by K.Kosako, with the API of [vscode-oniguruma](https://github.com/microsoft/vscode-oniguruma) **2.0.1** (Microsoft), the WebAssembly binding VS Code uses to run TextMate grammars. 6.9.8 at `08d3611` is the exact revision vscode-oniguruma 2.0.1 builds (its `deps/oniguruma` submodule).

It is the regex engine of the `textmate` library (the vscode-textmate port). It has no dependency (no Ceramic, no other haxelib) and runs on every Haxe target. Patterns and subjects are converted to UTF-8 like vscode-oniguruma does, and all offsets given to and returned by the scanner are UTF-16 code unit offsets, so the results are the same on targets with UTF-16 strings (JavaScript) and UTF-8 strings (C++).

All credit for the design and the algorithms goes to Oniguruma and vscode-oniguruma. This port translates the C and TypeScript sources file by file: each Haxe module starts with a header naming the file it comes from. The code is distributed under the same terms, BSD-2-Clause for Oniguruma and MIT for vscode-oniguruma (see [LICENSE](LICENSE)).

## What is ported

From vscode-oniguruma (`src/index.ts`, `src/onig.cc`):

- `OnigScanner` (`new OnigScanner(patterns)`, `findNextMatchSync(string, startPosition, options)`, `dispose`), with the same strategy as `onig.cc`: a `OnigRegSet` search with `ONIG_REGSET_POSITION_LEAD` for strings shorter than 1000 UTF-8 bytes, otherwise one search per regex with the per regex result cache, the `\G` handling and the `MAX_REGIONS` limit;
- `OnigString` (the `UtfString` conversion: UTF-8 bytes, the UTF-16 to UTF-8 offset maps, lone surrogates encoded on 3 bytes);
- `FindOption`, `IOnigMatch` / `OnigMatch`, `IOnigCaptureIndex` / `OnigCaptureIndex`, `setDefaultDebugCall` (accepted, no effect);
- the regexes are compiled with `ONIG_OPTION_CAPTURE_GROUP`, `ONIG_ENCODING_UTF8` and `ONIG_SYNTAX_DEFAULT` (Oniguruma 6.9.8 makes it `OnigSyntaxOniguruma`), and run with the default retry limit (10000000 in match), like the binding.

From Oniguruma (`src/`), everything those builds use:

- the parser (`regparse.c`): all the syntax of `OnigSyntaxOniguruma`, plus the other syntax definitions of `regsyntax.c` (Ruby, Perl, Perl_NT, Java, Python, Emacs, Grep, GNU regex, POSIX basic and extended, ASIS), character classes and set operations, `\p{...}` properties, named groups, back references with levels, subexpression calls, absent operators `(?~...)`, `\X`, `\R`, `\N`, `\O`, `\K`, `\y` / `\Y`, text segment options, whole options `(?I)` `(?L)` `(?C)`, and builtin callouts (`(*FAIL)`, `(*MISMATCH)`, `(*MAX{n})`, `(*COUNT)`, `(*TOTAL_COUNT)`, `(*CMP)`, `(*ERROR)`, `(?{...})` contents);
- the compiler and optimizer (`regcomp.c`): tree tuning, case fold expansion, the exact / map / Sunday optimizations, anchors and the bytecode;
- the backtracking matcher (`regexec.c`): `onig_search`, `onig_match`, `onig_regset_search` with both lead modes, the forward and backward searches, the retry limits, the empty loop checks, captures in empty repeats (`USE_RIGID_CHECK_CAPTURES_IN_EMPTY_REPEAT`);
- the UTF-8 encoding (`utf8.c`, `regenc.c`) and the Unicode data of Unicode 14.0 (`unicode.c` and the generated tables: properties, scripts, case folding and unfolding, grapheme cluster and word break data);
- error messages (`regerror.c`), `OnigRegion` and `OnigErrorInfo`.

Not ported: the encodings other than UTF-8, the POSIX and GNU API wrappers (`regposix.c`, `reggnu.c`), user defined callouts (only the builtin ones exist, there is no API to register others, which vscode-oniguruma does not expose either) and capture history `(?@...)` (no syntax used here enables it).

## Differences with the vscode-oniguruma API

- No `loadWASM`: the engine is plain Haxe and needs no initialization. `OnigLib` has the shape of vscode-textmate's `IOnigLib` (`new OnigLib().createOnigScanner(patterns)`, `createOnigString(str)`), plus static `createScanner`, `createString` and `setDefaultDebugCall`.
- `findNextMatchSync` takes a `String` or an `OnigString` (through the `OnigScannerInput` abstract) and the options as an `Array<FindOption>` (vscode-oniguruma also accepts a numeric mask there, which it then ignores: pass `null`). It returns `null` when nothing matches.
- An unset capture group is returned as vscode-oniguruma returns it: `start` and `end` are `4294967295` on JavaScript when the string is ASCII only, and `utf16Length` otherwise. On C++, where `Int` is 32 bits, the ASCII case gives `-1`.
- `dispose()` exists on `OnigScanner` and `OnigString` but does nothing (the garbage collector frees everything).
- Errors thrown by `new OnigScanner` are `OnigError` exceptions with Oniguruma's message, like the `Error` of the binding.
- The Oniguruma C API is available in `oniguruma.onig` with camelCase names (`Regex.onigNew`, `Regexec.onigSearch`, `Regexec.onigMatch`, `OnigRegSet.onigRegsetNew`, `OnigRegion`...). C pointers are offsets in `haxe.io.Bytes`, out parameters are small ref objects.

## Implementation notes

The translation stays close to the C code, with these changes that never alter results:

- The compiled program is packed into one integer array (5 slots per operation) with a byte pool for strings and an integer pool for bitsets and back reference lists, instead of an array of C structs. Identical code ranges are shared between regexes.
- The backtracking stack is a set of parallel integer arrays shared by all regexes (the matcher is not reentrant, which callouts cannot violate since only builtin ones exist), and the match parameters are pooled. This keeps the memory of a big grammar close to the WebAssembly build.
- `OnigString` pads its UTF-8 bytes with zeros because the C code reads the byte at the end position in some searches.
- `OnigLen` (`INFINITE_LEN` is `0x7fffffff`) and code points are compared as unsigned 32 bit values like in C.
- The Unicode tables are generated from the C sources into packed strings, and the gperf lookup tables are replaced by maps.

## Usage

```haxe
import oniguruma.OnigScanner;
import oniguruma.OnigString;

class Main {

    static function main() {
        var scanner = new OnigScanner(['(?<=\\.)\\h+', '\\p{Lu}\\w*']);
        var str = new OnigString('a.ff Été');
        var m = scanner.findNextMatchSync(str, 0);
        trace(m.index, m.captureIndices[0].start, m.captureIndices[0].end); // 0 2 4
        m = scanner.findNextMatchSync(str, 4);
        trace(m.index, m.captureIndices[0].start, m.captureIndices[0].end); // 1 5 8
    }

}
```

## Tests

The `test` folder contains a runner that does not need Ceramic. The expected values are recorded from the real vscode-oniguruma 2.0.1 running in node (and from the C test programs of Oniguruma), never from the port:

- `vscode-oniguruma`: the tests of vscode-oniguruma (`src/test`), translated;
- `upstream-*`: the cases of Oniguruma's `test/test_utf8.c`, `test_back.c`, `test_options.c` and `test_syntax.c`, converted to data. Each case is checked twice: with the Oniguruma API against the C expectation (same semantics as the C harness), and through `OnigScanner` against what vscode-oniguruma returns;
- `corpus-*`: a differential corpus of 11 grammars (JSON, JavaScript, TypeScript, Haxe, Rust, Markdown, HTML, CSS, YAML, shell, Loreline): every regex of the grammar, grouped in the scanners vscode-textmate builds, run on sample lines at many positions, with the exact match and capture offsets of vscode-oniguruma (about 458000 calls).

```sh
cd test
./run.sh                       # JavaScript build, run with node
./run.sh corpus-rust           # only the suites whose name contains "corpus-rust"
haxe build-cpp.hxml && ./bin/cpp/Main fixtures
```

`run.sh` uses `haxe` from the `PATH`. The hxcpp build needs hxcpp: a local repository can be set up in the test folder with `haxelib newrepo && haxelib dev hxcpp <path to hxcpp>`.

The runner also prints the time spent in `findNextMatchSync` on the corpus. `build-bench.hxml` and `build-bench-cpp.hxml` build a benchmark over the same corpus (compile time, time per call, memory), and `bench-wasm.mjs` runs the same benchmark with the real onig.wasm (`node bench-wasm.mjs <node_modules folder with vscode-oniguruma>`).

The scripts used to record the fixtures are in `test/record` (they need vscode-oniguruma and the upstream sources in a work folder outside the repository, see their headers). The sources and licenses of the test data are listed in [test/fixtures/NOTICE.md](test/fixtures/NOTICE.md).

## License

BSD-2-Clause for the Oniguruma part (Copyright (c) 2002-2022 K.Kosako) and MIT for the vscode-oniguruma part (Copyright (c) Microsoft Corporation). See [LICENSE](LICENSE).
