// Ported from Oniguruma 6.9.8: src/regint.h (re_pattern_buffer, RegexExt, RepeatRange), src/regcomp.c (onig_new, onig_reg_init)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regint.*;

class RepeatRange {
    public var lower:Int = 0;
    public var upper:Int = 0;
    /** u.pcode (index of the repeated body in ops) */
    public var pcode:Int = 0;
    public function new() {}
}

/** NameEntry of regparse.c */
class NameEntry {
    public var name:String;
    public var nameLen:Int = 0;
    public var backNum:Int = 0;
    public var backRefs:Array<Int>;
    public function new(name:String, nameLen:Int) {
        this.name = name;
        this.nameLen = nameLen;
        backRefs = [];
    }
}

/** CalloutListEntry of regint.h */
class CalloutListEntry {
    public var flag:Int = 0;
    public var of:Int = 0;
    public var in_:Int = 0;
    public var nameId:Int = 0;
    public var tagStart:Int = -1;
    public var tagEnd:Int = -1;
    public var contentBytes:haxe.io.Bytes = null;
    public var type:Int = 0;
    /** start function (an id of Callout's builtin functions, 0 for none) */
    public var startFunc:Int = 0;
    public var endFunc:Int = 0;
    // u.content
    public var contentStart:Int = -1;
    public var contentEnd:Int = -1;
    // u.arg
    public var argNum:Int = 0;
    public var argPassedNum:Int = 0;
    public var argTypes:Array<Int>;
    public var argVals:Array<Callout.OnigValue>;
    public function new() {
        argTypes = [0, 0, 0, 0];
        argVals = [new Callout.OnigValue(), new Callout.OnigValue(), new Callout.OnigValue(), new Callout.OnigValue()];
    }
}

/** RegexExt */
class RegexExt {
    public var pattern:Bytes = null;
    public var patternStart:Int = 0;
    public var patternEnd:Int = 0;
    public var tagTable:Map<String, Int> = null;
    public var calloutNum:Int = 0;
    public var calloutListAlloc:Int = 0;
    public var calloutList:Array<CalloutListEntry> = null;
    public function new() {}
}

/** regex_t (struct re_pattern_buffer) */
class Regex {

    /** operations during the compilation (released once packed into `code`) */
    public var ops:Array<Operation> = null;
    public var opsUsed:Int = 0;
    /** index of the FINISH operation appended after the program (FinishCode of match_at) */
    public var finishIndex:Int = 0;

    /**
     * The compiled program: OP_STRIDE ints per operation (opcode then its operands,
     * see Regcomp.packOps), with the strings in `strPool`, the bitsets and backref
     * lists in `intPool` and the code ranges in `ranges`.
     */
    public var code:IntArray = null;
    public var strPool:Bytes = null;
    public var intPool:IntArray = null;
    public var ranges:Array<IntArray> = null;

    public var numMem:Int = 0;
    public var numRepeat:Int = 0;
    public var numEmptyCheck:Int = 0;
    public var numCall:Int = 0;
    public var captureHistory:Int = 0;
    public var pushMemStart:Int = 0;
    public var pushMemEnd:Int = 0;
    public var stackPopLevel:Int = 0;
    public var repeatRangeAlloc:Int = 0;
    public var repeatRange:Array<RepeatRange> = null;

    public var options:Int = 0;
    public var syntax:OnigSyntaxType = null;
    public var caseFoldFlag:Int = 0;
    public var nameTable:Map<String, NameEntry> = null;

    // optimization info (string search, char-map and anchors)
    public var optimize:Int = 0;
    public var thresholdLen:Int = 0;
    public var anchor:Int = 0;
    public var ancDistMin:Int = 0;
    public var ancDistMax:Int = 0;
    public var subAnchor:Int = 0;
    public var exact:Bytes = null;
    public var exactStart:Int = 0;
    public var exactEnd:Int = 0;
    /** BMH skip table or char map (allocated only for the optimizations that use it) */
    public var map:Bytes = null;
    public var mapOffset:Int = 0;
    public var distMin:Int = 0;
    public var distMax:Int = 0;
    public var extp:RegexExt = null;


    public function new() {}

    /** onig_new: returns ONIG_NORMAL or an error code (reg is then unusable). */
    public static function onigNew(reg:Regex, pattern:Bytes, start:Int, end:Int, option:Int, syntax:OnigSyntaxType, einfo:OnigErrorInfo):Int {
        var r = onigRegInit(reg, option, ONIGENC_CASE_FOLD_DEFAULT, syntax);
        if (r != 0) return r;
        return Regcomp.onigCompile(reg, pattern, start, end, einfo);
    }

    /** onig_reg_init */
    public static function onigRegInit(reg:Regex, option:Int, caseFoldFlag:Int, syntax:OnigSyntaxType):Int {
        if ((option & (ONIG_OPTION_DONT_CAPTURE_GROUP | ONIG_OPTION_CAPTURE_GROUP)) == (ONIG_OPTION_DONT_CAPTURE_GROUP | ONIG_OPTION_CAPTURE_GROUP)) {
            return ONIGERR_INVALID_COMBINATION_OF_OPTIONS;
        }

        if ((option & ONIG_OPTION_NEGATE_SINGLELINE) != 0) {
            option |= syntax.options;
            option &= ~ONIG_OPTION_SINGLELINE;
        }
        else
            option |= syntax.options;

        if ((option & ONIG_OPTION_IGNORECASE_IS_ASCII) != 0) {
            caseFoldFlag &= ~(INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR | ONIGENC_CASE_FOLD_TURKISH_AZERI);
            caseFoldFlag |= ONIGENC_CASE_FOLD_ASCII_ONLY;
        }

        reg.options = option;
        reg.syntax = syntax;
        reg.optimize = 0;
        reg.exact = null;
        reg.extp = null;
        reg.ops = null;
        reg.opsUsed = 0;
        reg.nameTable = null;
        reg.caseFoldFlag = caseFoldFlag;
        return 0;
    }

}
