// Ported from Oniguruma 6.9.8: src/regexec.c (OnigRegSetStruct, onig_regset_*)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regint.*;
import oniguruma.onig.Regexec.MatchArg;
import oniguruma.onig.Regexec.IntRefE;

/** OnigRegSet */
class OnigRegSet {

    public static inline var ONIG_REGSET_POSITION_LEAD:Int = 0;
    public static inline var ONIG_REGSET_REGEX_LEAD:Int = 1;
    public static inline var ONIG_REGSET_PRIORITY_TO_REGEX_ORDER:Int = 2;

    public var regs:Array<Regex> = [];
    public var regions:Array<OnigRegion> = [];
    public var n:Int = 0;
    public var anchor:Int = 0;
    public var ancDmin:Int = 0;
    public var ancDmax:Int = 0;
    public var allLowHigh:Int = 0;
    public var anycharInf:Int = 0;

    // SearchRange array of regset_search_body_position_lead (kept between searches)
    public var srState:Array<Int> = [];
    public var srLow:Array<Int> = [];
    public var srHigh:Array<Int> = [];
    public var srSchRange:Array<Int> = [];

    var matchPos = new IntRefE();

    public function new() {}

    /** onig_regset_new */
    public static function onigRegsetNew(regs:Array<Regex>):OnigRegSet {
        var set = new OnigRegSet();
        for (reg in regs) {
            set.add(reg);
        }
        return set;
    }

    function updateRegsetByReg(reg:Regex):Void {
        if (n == 1) {
            anchor = reg.anchor;
            ancDmin = reg.ancDistMin;
            ancDmax = reg.ancDistMax;
            allLowHigh = (reg.optimize == OPTIMIZE_NONE || reg.distMax == INFINITE_LEN) ? 0 : 1;
            anycharInf = (reg.anchor & ANCR_ANYCHAR_INF) != 0 ? 1 : 0;
        }
        else {
            var anc = anchor & reg.anchor;
            if (anc != 0) {
                var dmin = ancDmin;
                var dmax = ancDmax;
                if (dmin > reg.ancDistMin) dmin = reg.ancDistMin;
                if (dmax < reg.ancDistMax) dmax = reg.ancDistMax;
                ancDmin = dmin;
                ancDmax = dmax;
            }
            anchor = anc;
            if (reg.optimize == OPTIMIZE_NONE || reg.distMax == INFINITE_LEN)
                allLowHigh = 0;
            if ((reg.anchor & ANCR_ANYCHAR_INF) != 0)
                anycharInf = 1;
        }
    }

    /** onig_regset_add */
    public function add(reg:Regex):Int {
        if (OPTON_FIND_LONGEST(reg.options))
            return ONIGERR_INVALID_ARGUMENT;
        regs.push(reg);
        regions.push(new OnigRegion());
        srState.push(0);
        srLow.push(0);
        srHigh.push(0);
        srSchRange.push(0);
        n++;
        updateRegsetByReg(reg);
        return 0;
    }

    /** onig_regset_search: returns the regex index (match position in `matchPosition`), or a negative value. */
    public function search(str:Bytes, end:Int, start:Int, range:Int, lead:Int, option:Int):Int {
        return Regexec.onigRegsetSearch(this, str, end, start, range, lead, option, matchPos);
    }

    public var matchPosition(get, never):Int;

    inline function get_matchPosition():Int {
        return matchPos.v;
    }

    /** onig_regset_get_region */
    public function getRegion(at:Int):OnigRegion {
        if (at < 0 || at >= n)
            return null;
        return regions[at];
    }

}
