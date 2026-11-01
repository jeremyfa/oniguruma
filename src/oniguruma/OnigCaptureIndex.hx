// Ported from vscode-oniguruma 2.0.1: main.d.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** A capture range in UTF-16 code units (`IOnigCaptureIndex`). */
class OnigCaptureIndex {

    public var start:Int;
    public var end:Int;
    public var length:Int;

    public inline function new(start:Int, end:Int, length:Int) {
        this.start = start;
        this.end = end;
        this.length = length;
    }

    public function toString():String {
        return '{ start: $start, end: $end, length: $length }';
    }

}
