// Ported from vscode-oniguruma 2.0.1: src/index.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** Regex syntaxes (`Syntax` in vscode-oniguruma), same order and values. */
enum abstract Syntax(Int) to Int {
    var Default = 0;
    var Asis = 1;
    var PosixBasic = 2;
    var PosixExtended = 3;
    var Emacs = 4;
    var Grep = 5;
    var GnuRegex = 6;
    var Java = 7;
    var Perl = 8;
    var PerlNg = 9;
    var Ruby = 10;
    var Python = 11;
    var Oniguruma = 12;
}
