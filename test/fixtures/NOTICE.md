# Test data sources

The fixtures are recorded with the scripts of `test/record`. They contain text and regular expressions taken from the following projects, under their own licenses.

## Upstream tests

- `upstream-utf8.json`, `upstream-back.json`, `upstream-options.json`, `upstream-syntax.json`: the cases of `test/test_utf8.c`, `test/test_back.c`, `test/test_options.c` and `test/test_syntax.c` of [Oniguruma](https://github.com/kkos/oniguruma) 6.9.8 (commit `08d3611`), Copyright (c) 2002-2022 K.Kosako, BSD-2-Clause (see the repository `LICENSE`). The `vs` values are the results of vscode-oniguruma 2.0.1.
- `test/src/VscodeOnigurumaTest.hx`: the tests of [vscode-oniguruma](https://github.com/microsoft/vscode-oniguruma) 2.0.1 (`src/test`), Copyright (c) Microsoft Corporation, MIT.

## Differential corpus (`corpus-*.json`)

Each file holds the regexes of one grammar, the sample lines and the results of vscode-oniguruma 2.0.1 (onig.wasm) on them.

Regexes, extracted from the grammars bundled in [@shikijs/langs](https://github.com/shikijs/shiki) 3.23.0 (MIT), which come from [tm-grammars](https://github.com/shikijs/textmate-grammars-themes), each under the license of its source repository:

| File | Grammar source | License |
|---|---|---|
| corpus-json | microsoft/vscode (extensions/json) | MIT |
| corpus-javascript, corpus-typescript | microsoft/TypeScript-TmLanguage | MIT |
| corpus-haxe | vshaxe/haxe-TmLanguage | MIT |
| corpus-rust | dustypomerleau/rust-syntax | MIT |
| corpus-markdown | microsoft/vscode-markdown-tm-grammar | MIT |
| corpus-html | textmate/html.tmbundle (through microsoft/vscode) | MIT |
| corpus-css | microsoft/vscode-css | MIT |
| corpus-yaml | RedCMD/YAML-Syntax-Highlighter | MIT |
| corpus-shellscript | jeff-hykin/better-shell-syntax | MIT |
| corpus-loreline | loreline `language/loreline.tmLanguage.json`, Copyright (c) 2025 Jérémy Faivre | MIT |

Sample lines (at most 40 per file), plus a few synthetic lines written for the corpus (Unicode, lone surrogate, tabs):

- vscode-oniguruma 2.0.1 (`package.json`, `tsconfig.json`, `webpack.config.js`, `scripts/*.js`, `scripts/build.sh`, `src/index.ts`, `README.md`, `build/pipeline.yml`, `build/setup-emsdk.sh`), Copyright (c) Microsoft Corporation, MIT;
- Oniguruma 6.9.8 `README.md`, Copyright (c) 2002-2022 K.Kosako, BSD-2-Clause;
- [unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation) 1.13.2 `src/lib.rs`, MIT OR Apache-2.0;
- loreline `test-syntax/*.lor`, Copyright (c) 2025 Jérémy Faivre, MIT;
- loreline-monaco `index.html` and `src/style.css`, and Ceramic `sample/ceramic.yml`, by Jérémy Faivre, MIT;
- `src/oniguruma/OnigScanner.hx` of this port (as it was when the corpus was recorded).
