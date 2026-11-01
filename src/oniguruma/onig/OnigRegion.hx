// Ported from Oniguruma 6.9.8: src/oniguruma.h (re_registers), src/regexec.c (onig_region_*)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

/** Match result region (`OnigRegion`): byte offsets of group 0 and every capture. */
class OnigRegion {

    public var allocated:Int = 0;
    public var numRegs:Int = 0;
    public var beg:Array<Int>;
    public var end:Array<Int>;

    public function new() {
        beg = [];
        end = [];
    }

    /** onig_region_resize */
    public function resize(n:Int):Int {
        numRegs = n;
        if (n < Onig.ONIG_NREGION)
            n = Onig.ONIG_NREGION;
        if (allocated < n) {
            beg.resize(n);
            end.resize(n);
            allocated = n;
        }
        return 0;
    }

    /** onig_region_resize_clear */
    public function resizeClear(n:Int):Int {
        var r = resize(n);
        if (r != 0) return r;
        clear();
        return 0;
    }

    /** onig_region_clear */
    public function clear():Void {
        for (i in 0...numRegs) {
            beg[i] = end[i] = Onig.ONIG_REGION_NOTPOS;
        }
    }

    /** onig_region_set */
    public function set(at:Int, b:Int, e:Int):Int {
        if (at < 0) return Onig.ONIGERR_INVALID_ARGUMENT;
        if (at >= allocated) {
            var r = resize(at + 1);
            if (r < 0) return r;
        }
        beg[at] = b;
        end[at] = e;
        return 0;
    }

    /** onig_region_copy */
    public function copyFrom(from:OnigRegion):Void {
        if (this == from) return;
        if (allocated < from.numRegs) {
            beg.resize(from.numRegs);
            end.resize(from.numRegs);
            allocated = from.numRegs;
        }
        for (i in 0...from.numRegs) {
            beg[i] = from.beg[i];
            end[i] = from.end[i];
        }
        numRegs = from.numRegs;
    }

}
