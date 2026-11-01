// Ported from vscode-oniguruma 2.0.1: main.d.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** Result of `OnigScanner.findNextMatchSync` (`IOnigMatch`). */
class OnigMatch {

    /** Index of the pattern that matched. */
    public var index:Int;

    /**
     * Group 0 then every capture group, in UTF-16 code units. Like upstream, an unset
     * group has a length of 0 and starts at 4294967295 (-1 on targets with 32 bit
     * integers) on a string without non ASCII characters, and at the string length otherwise.
     */
    public var captureIndices:Array<OnigCaptureIndex>;

    public inline function new(index:Int, captureIndices:Array<OnigCaptureIndex>) {
        this.index = index;
        this.captureIndices = captureIndices;
    }

    public function toString():String {
        return '{ index: $index, captureIndices: $captureIndices }';
    }

}
