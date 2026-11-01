// Ported from Oniguruma 6.9.8: src/oniguruma.h (OnigSyntaxType, OnigMetaCharTableType)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

class OnigSyntaxType {

    public var op:Int;
    public var op2:Int;
    public var behavior:Int;
    public var options:Int; // default option
    // meta_char_table
    public var metaEsc:Int;
    public var metaAnychar:Int;
    public var metaAnytime:Int;
    public var metaZeroOrOneTime:Int;
    public var metaOneOrMoreTime:Int;
    public var metaAnycharAnytime:Int;

    public function new(op:Int, op2:Int, behavior:Int, options:Int) {
        this.op = op;
        this.op2 = op2;
        this.behavior = behavior;
        this.options = options;
        metaEsc = '\\'.code;
        metaAnychar = Onig.ONIG_INEFFECTIVE_META_CHAR;
        metaAnytime = Onig.ONIG_INEFFECTIVE_META_CHAR;
        metaZeroOrOneTime = Onig.ONIG_INEFFECTIVE_META_CHAR;
        metaOneOrMoreTime = Onig.ONIG_INEFFECTIVE_META_CHAR;
        metaAnycharAnytime = Onig.ONIG_INEFFECTIVE_META_CHAR;
    }

    public function copy():OnigSyntaxType {
        var s = new OnigSyntaxType(op, op2, behavior, options);
        s.metaEsc = metaEsc;
        s.metaAnychar = metaAnychar;
        s.metaAnytime = metaAnytime;
        s.metaZeroOrOneTime = metaZeroOrOneTime;
        s.metaOneOrMoreTime = metaOneOrMoreTime;
        s.metaAnycharAnytime = metaAnycharAnytime;
        return s;
    }

}
