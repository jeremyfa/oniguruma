// Ported from vscode-oniguruma 2.0.1: src/index.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** `IOnigScannerConfig`. */
typedef OnigScannerConfig = {
    ?options:Array<FindOption>,
    ?syntax:Syntax
}
