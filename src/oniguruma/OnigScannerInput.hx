// Ported from vscode-oniguruma 2.0.1: src/index.ts (the string | OnigString argument)
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** `string | OnigString` argument of `OnigScanner.findNextMatchSync`. */
abstract OnigScannerInput(OnigString) to OnigString {

    inline function new(s:OnigString) {
        this = s;
    }

    @:from static inline function fromOnigString(s:OnigString):OnigScannerInput {
        return new OnigScannerInput(s);
    }

    @:from static inline function fromString(s:String):OnigScannerInput {
        return new OnigScannerInput(new OnigString(s));
    }

}
