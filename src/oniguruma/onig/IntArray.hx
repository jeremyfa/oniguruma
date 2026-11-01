// Part of the Haxe port of Oniguruma 6.9.8 (no upstream file: replaces the C int arrays).
// Oniguruma Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: written for the Haxe port. See README.md.

package oniguruma.onig;

/**
 * A fixed size array of 32 bit integers: a `js.lib.Int32Array` on JavaScript
 * (4 bytes per element, like the C arrays of the original), a `haxe.ds.Vector`
 * elsewhere.
 */
#if js
abstract IntArray(js.lib.Int32Array) {

    public var length(get, never):Int;

    public inline function new(n:Int) {
        this = new js.lib.Int32Array(n);
    }

    inline function get_length():Int {
        return this.length;
    }

    @:arrayAccess public inline function get(i:Int):Int {
        return this[i];
    }

    @:arrayAccess public inline function set(i:Int, v:Int):Int {
        return this[i] = v;
    }

    public static inline function blit(src:IntArray, srcPos:Int, dest:IntArray, destPos:Int, len:Int):Void {
        (cast dest : js.lib.Int32Array).set((cast src : js.lib.Int32Array).subarray(srcPos, srcPos + len), destPos);
    }

    public static function fromArray(a:Array<Int>, ?len:Int):IntArray {
        var n = len == null ? a.length : len;
        var r = new IntArray(n);
        for (i in 0...n) r[i] = a[i];
        return r;
    }

}
#else
abstract IntArray(haxe.ds.Vector<Int>) {

    public var length(get, never):Int;

    public inline function new(n:Int) {
        this = new haxe.ds.Vector<Int>(n);
        #if !static
        for (i in 0...n) this[i] = 0;
        #end
    }

    inline function get_length():Int {
        return this.length;
    }

    @:arrayAccess public inline function get(i:Int):Int {
        return this[i];
    }

    @:arrayAccess public inline function set(i:Int, v:Int):Int {
        return this[i] = v;
    }

    public static inline function blit(src:IntArray, srcPos:Int, dest:IntArray, destPos:Int, len:Int):Void {
        haxe.ds.Vector.blit(cast src, srcPos, cast dest, destPos, len);
    }

    public static function fromArray(a:Array<Int>, ?len:Int):IntArray {
        var n = len == null ? a.length : len;
        var r = new IntArray(n);
        for (i in 0...n) r[i] = a[i];
        return r;
    }

}
#end
