// Ported from Oniguruma 6.9.8: src/regexec.c
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. The backtracking stack is a set of parallel
// int vectors (the C union members map to the same slots as in the wasm32
// layout), string and code positions are indexes. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regint.*;
import oniguruma.onig.Regenc.*;

/**
 * MatchArg. The match stack of the C version (allocated for each search and
 * freed at its end) is shared by all searches here (see Regexec.stkType...):
 * a match_at call never uses the stack content of a previous call.
 */
class MatchArg {
    public var options:Int = 0;
    public var region:OnigRegion = null;
    public var start:Int = 0;
    public var matchStackLimit:Int = 0;
    public var retryLimitInMatch:Int = 0;
    public var retryLimitInSearch:Int = 0;
    public var retryLimitInSearchCounter:Int = 0;
    public var bestLen:Int = 0;
    public var bestS:Int = 0;
    public var subexpCallInSearchCounter:Int = 0;

    // callout data of the OnigMatchParam (one search)
    public var matchAtCallCounter:Int = 0;
    public var calloutData:Array<Callout.CalloutData> = null;
    public var calloutArgs:Callout.OnigCalloutArgs = null;

    public function new() {}

    /** MATCH_ARG_INIT */
    public inline function init(reg:Regex, option:Int, region:OnigRegion, start:Int):Void {
        this.options = option | reg.options;
        this.region = region;
        this.start = start;
        this.matchStackLimit = Regexec.MatchStackLimit;
        this.retryLimitInMatch = Regexec.RetryLimitInMatch;
        this.retryLimitInSearch = Regexec.RetryLimitInSearch;
        this.retryLimitInSearchCounter = 0;
        this.subexpCallInSearchCounter = 0;
        this.bestLen = ONIG_MISMATCH;
        Regexec.ensureMem(reg.numMem);
        // adjust_match_param
        this.matchAtCallCounter = 0;
        var ext = reg.extp;
        if (ext != null && ext.calloutNum > 0) {
            if (calloutData == null) calloutData = [];
            while (calloutData.length < ext.calloutNum) calloutData.push(new Callout.CalloutData());
            for (d in calloutData) d.clear();
        }
        else if (calloutData != null) {
            calloutData = null;
        }
    }
}

class Regexec {

    public static inline var INIT_MATCH_STACK_SIZE:Int = 160;
    static inline var OP_STRIDE:Int = Regcomp.OP_STRIDE;

    // the match stack (shared by all searches) and the capture stacks
    public static var stkType:IntArray = new IntArray(INIT_MATCH_STACK_SIZE);
    public static var stkZid:IntArray = new IntArray(INIT_MATCH_STACK_SIZE);
    public static var stk0:IntArray = new IntArray(INIT_MATCH_STACK_SIZE);
    public static var stk1:IntArray = new IntArray(INIT_MATCH_STACK_SIZE);
    public static var stk2:IntArray = new IntArray(INIT_MATCH_STACK_SIZE);
    public static var memStartStk:IntArray = new IntArray(16);
    public static var memEndStk:IntArray = new IntArray(16);

    /** stack_double */
    static function growStack(used:Int):Void {
        var n = stkType.length * 2;
        var t = new IntArray(n);
        var z = new IntArray(n);
        var a = new IntArray(n);
        var b = new IntArray(n);
        var c = new IntArray(n);
        IntArray.blit(stkType, 0, t, 0, used);
        IntArray.blit(stkZid, 0, z, 0, used);
        IntArray.blit(stk0, 0, a, 0, used);
        IntArray.blit(stk1, 0, b, 0, used);
        IntArray.blit(stk2, 0, c, 0, used);
        stkType = t;
        stkZid = z;
        stk0 = a;
        stk1 = b;
        stk2 = c;
    }

    public static function ensureMem(numMem:Int):Void {
        if (memStartStk.length < numMem + 1) {
            memStartStk = new IntArray(numMem + 1);
            memEndStk = new IntArray(numMem + 1);
        }
    }

    static var singleMsa:MatchArg = new MatchArg();
    static var setMsas:Array<MatchArg> = [];

    public static function getSetMsas(n:Int):Array<MatchArg> {
        while (setMsas.length < n) setMsas.push(new MatchArg());
        return setMsas;
    }

    public static var MatchStackLimit:Int = DEFAULT_MATCH_STACK_LIMIT_SIZE;
    public static var RetryLimitInMatch:Int = DEFAULT_RETRY_LIMIT_IN_MATCH;
    public static var RetryLimitInSearch:Int = DEFAULT_RETRY_LIMIT_IN_SEARCH;
    public static var SubexpCallLimitInSearch:Int = DEFAULT_SUBEXP_CALL_LIMIT_IN_SEARCH;
    public static var SubexpCallMaxNestLevel:Int = DEFAULT_SUBEXP_CALL_MAX_NEST_LEVEL;

    // stack types
    static inline var STK_ALT_FLAG:Int = 0x0001;
    static inline var STK_SUPER_ALT:Int = STK_ALT_FLAG;
    static inline var STK_ALT:Int = 0x0002 | STK_ALT_FLAG;
    static inline var STK_MEM_START:Int = 0x0010;
    static inline var STK_MEM_END:Int = 0x8030;
    static inline var STK_REPEAT_INC:Int = 0x0040;
    static inline var STK_CALLOUT:Int = 0x0070;
    static inline var STK_VOID:Int = 0x0000;
    static inline var STK_EMPTY_CHECK_START:Int = 0x3000;
    static inline var STK_EMPTY_CHECK_END:Int = 0x5000;
    static inline var STK_MEM_END_MARK:Int = 0x8100;
    static inline var STK_CALL_FRAME:Int = 0x0400 | STK_MASK_POP_HANDLED;
    static inline var STK_RETURN:Int = 0x0500 | STK_MASK_POP_HANDLED;
    static inline var STK_SAVE_VAL:Int = 0x0600;
    static inline var STK_MARK:Int = 0x0704;

    static inline var STK_MASK_POP_USED:Int = STK_ALT_FLAG;
    static inline var STK_MASK_POP_HANDLED:Int = 0x0010;
    static inline var STK_MASK_POP_HANDLED_TIL:Int = STK_MASK_POP_HANDLED | 0x0004;
    static inline var STK_MASK_TO_VOID_TARGET:Int = 0x100e;
    static inline var STK_MASK_MEM_END_OR_MARK:Int = 0x8000;

    static inline var INVALID_STACK_INDEX:Int = -1;

    static var foldBuf1:Bytes = Bytes.alloc(ONIGENC_MBC_CASE_FOLD_MAXLEN);
    static var foldBuf2:Bytes = Bytes.alloc(ONIGENC_MBC_CASE_FOLD_MAXLEN);

    /** string_cmp_ic: compares s1 (in b1) with ps2 (in b2); returns the new ps2 or -1 when different. */
    static function stringCmpIc(caseFoldFlag:Int, b1:Bytes, s1:Int, b2:Bytes, s2:Int, mblen:Int):Int {
        var buf1 = foldBuf1;
        var buf2 = foldBuf2;
        var end1 = s1 + mblen;
        var end2 = s2 + mblen;
        while (s1 < end1) {
            var len1 = mbcCaseFold(caseFoldFlag, b1, s1, end1, buf1, 0);
            s1 += enclen(b1, s1);
            var len2 = mbcCaseFold(caseFoldFlag, b2, s2, end2, buf2, 0);
            s2 += enclen(b2, s2);
            if (len1 != len2) return -1;
            for (i in 0...len1) {
                if (buf1.get(i) != buf2.get(i)) return -1;
            }
            if (s2 >= end2) {
                if (s1 < end1) return -1;
                else break;
            }
        }
        return s2;
    }

    static function memIsInMemp(mem:Int, num:Int, pool:IntArray, memp:Int):Bool {
        for (i in 0...num) {
            if (mem == pool[memp + i]) return true;
        }
        return false;
    }

    static inline function bitsetAt(pool:IntArray, off:Int, pos:Int):Bool {
        return (pool[off + (pos >>> 5)] & (1 << (pos & 0x1f))) != 0;
    }

    /** backref_match_at_nested_level: returns the new s or -1. */
    static function backrefMatchAtNestedLevel(reg:Regex, msa:MatchArg, top:Int, str:Bytes, ignoreCase:Bool, caseFoldFlag:Int,
            nest:Int, memNum:Int, pool:IntArray, memp:Int, s:Int, send:Int):Int {
        var pend = -1;
        var level = 0;
        var k = top - 1;
        var stkType = Regexec.stkType;
        var stkZid = Regexec.stkZid;
        var stk0 = Regexec.stk0;
        while (k >= 0) {
            var t = stkType[k];
            if (t == STK_CALL_FRAME) {
                level--;
            }
            else if (t == STK_RETURN) {
                level++;
            }
            else if (level == nest) {
                if (t == STK_MEM_START) {
                    if (memIsInMemp(stkZid[k], memNum, pool, memp)) {
                        var pstart = stk0[k];
                        if (pend != -1) {
                            if (pend - pstart > send - s) return -1; /* or goto next_mem; */
                            var p = pstart;
                            var ss = s;
                            if (ignoreCase) {
                                ss = stringCmpIc(caseFoldFlag, str, pstart, str, ss, pend - pstart);
                                if (ss < 0) return -1;
                            }
                            else {
                                while (p < pend) {
                                    if (str.get(p++) != str.get(ss++)) return -1;
                                }
                            }
                            return ss;
                        }
                    }
                }
                else if (t == STK_MEM_END) {
                    if (memIsInMemp(stkZid[k], memNum, pool, memp)) {
                        pend = stk0[k];
                    }
                }
            }
            k--;
        }
        return -1;
    }

    static function backrefCheckAtNestedLevel(reg:Regex, msa:MatchArg, top:Int, nest:Int, memNum:Int, pool:IntArray, memp:Int):Bool {
        var level = 0;
        var k = top - 1;
        var stkType = Regexec.stkType;
        while (k >= 0) {
            var t = stkType[k];
            if (t == STK_CALL_FRAME) {
                level--;
            }
            else if (t == STK_RETURN) {
                level++;
            }
            else if (level == nest) {
                if (t == STK_MEM_END) {
                    if (memIsInMemp(Regexec.stkZid[k], memNum, pool, memp)) {
                        return true;
                    }
                }
            }
            k--;
        }
        return false;
    }

    /* match data(str - end) from position (sstart). */
    static function matchAt(reg:Regex, str:Bytes, end:Int, inRightRange:Int, sstart:Int, msa:MatchArg):Int {
        var code = reg.code;
        var strPool = reg.strPool;
        var intPool = reg.intPool;
        var ranges = reg.ranges;
        var p = 0;
        var caseFoldFlag = reg.caseFoldFlag;
        var options = msa.options;
        var subexpCallNestCounter = 0;
        var n:Int;
        var mem:Int;
        var tlen:Int;

        msa.matchAtCallCounter++;

        var retryLimitInMatch = msa.retryLimitInMatch;
        if (msa.retryLimitInSearch != 0) {
            var rem = msa.retryLimitInSearch - msa.retryLimitInSearchCounter;
            if (rem < retryLimitInMatch)
                retryLimitInMatch = rem;
        }

        var popLevel = reg.stackPopLevel;
        var numMem = reg.numMem;
        var pushMemStart = reg.pushMemStart;
        var pushMemEnd = reg.pushMemEnd;

        var stkType = Regexec.stkType;
        var stkZid = Regexec.stkZid;
        var stk0 = Regexec.stk0;
        var stk1 = Regexec.stk1;
        var stk2 = Regexec.stk2;
        var stkEnd = stkType.length;
        var memStartStk = Regexec.memStartStk;
        var memEndStk = Regexec.memEndStk;
        var stk = 0;

        inline function ENSURE():Void {
            if (stk >= stkEnd) {
                growStack(stk);
                stkType = Regexec.stkType;
                stkZid = Regexec.stkZid;
                stk0 = Regexec.stk0;
                stk1 = Regexec.stk1;
                stk2 = Regexec.stk2;
                stkEnd = stkType.length;
            }
        }

        inline function PUSH(type:Int, pcode:Int, pstr:Int):Void {
            ENSURE();
            stkType[stk] = type;
            stk0[stk] = pcode;
            stk1[stk] = pstr;
            stk++;
        }

        inline function PUSH_ZID(type:Int, pcode:Int, pstr:Int, zid:Int):Void {
            ENSURE();
            stkType[stk] = type;
            stkZid[stk] = zid;
            stk0[stk] = pcode;
            stk1[stk] = pstr;
            stk++;
        }

        inline function STACK_MEM_START(idx:Int):Int {
            return MEM_STATUS_AT(pushMemStart, idx) ? stk0[memStartStk[idx]] : memStartStk[idx];
        }

        inline function STACK_MEM_END(idx:Int):Int {
            return MEM_STATUS_AT(pushMemEnd, idx) ? stk0[memEndStk[idx]] : memEndStk[idx];
        }

        for (i in 1...(numMem + 1)) {
            memStartStk[i] = memEndStk[i] = INVALID_STACK_INDEX;
        }

        var bestLen = ONIG_MISMATCH;
        var s = sstart;
        var keep = s;
        // STACK_PUSH_BOTTOM(STK_ALT, FinishCode)
        stkType[stk] = STK_ALT;
        stk0[stk] = reg.finishIndex;
        stk++;
        var rightRange = inRightRange;

        var retryInMatchCounter = 0;
        var calloutAbort = false;

        while (true) {
            var b = p * OP_STRIDE;
            var opcode = code[b];
            var fail = false;
            switch (opcode) {
                case OP_END:
                    n = s - sstart;
                    if (n == 0 && OPTON_FIND_NOT_EMPTY(options)) {
                        bestLen = ONIG_MISMATCH;
                        fail = true; /* for retry */
                    }
                    else {
                        var doRegion = true;
                        if (n > bestLen) {
                            if (OPTON_FIND_LONGEST(options)) {
                                if (n > msa.bestLen) {
                                    msa.bestLen = n;
                                    msa.bestS = sstart;
                                    if (s >= inRightRange) {
                                        bestLen = msa.bestLen; /* end of find */
                                    }
                                }
                                else {
                                    if (s >= inRightRange && msa.bestS == sstart) {
                                        bestLen = msa.bestLen; /* end of find */
                                    }
                                    else {
                                        fail = true; /* for retry */
                                        doRegion = false;
                                    }
                                }
                            }
                            else {
                                bestLen = n;
                            }
                        }
                        if (doRegion) {
                            /* set region */
                            var region = msa.region;
                            if (region != null) {
                                if (keep > s) keep = s;
                                region.beg[0] = keep;
                                region.end[0] = s;
                                for (i in 1...(numMem + 1)) {
                                    if (memEndStk[i] != INVALID_STACK_INDEX) {
                                        region.beg[i] = STACK_MEM_START(i);
                                        region.end[i] = STACK_MEM_END(i);
                                    }
                                    else {
                                        region.beg[i] = region.end[i] = ONIG_REGION_NOTPOS;
                                    }
                                }
                            }
                            /* default behavior: return first-matching result. */
                            break; // goto match_at_end
                        }
                    }

                case OP_STR_1:
                    if (rightRange - s < 1 || strPool.get(code[b + 3]) != str.get(s)) fail = true;
                    else {
                        s++;
                        p++;
                    }

                case OP_STR_2:
                    if (rightRange - s < 2) fail = true;
                    else {
                        var ps = code[b + 3];
                        if (strPool.get(ps) != str.get(s) || strPool.get(ps + 1) != str.get(s + 1)) fail = true;
                        else {
                            s += 2;
                            p++;
                        }
                    }

                case OP_STR_3:
                    if (rightRange - s < 3) fail = true;
                    else {
                        var ps = code[b + 3];
                        if (strPool.get(ps) != str.get(s) || strPool.get(ps + 1) != str.get(s + 1) || strPool.get(ps + 2) != str.get(s + 2)) fail = true;
                        else {
                            s += 3;
                            p++;
                        }
                    }

                case OP_STR_4:
                    if (rightRange - s < 4) fail = true;
                    else {
                        var ps = code[b + 3];
                        if (strPool.get(ps) != str.get(s) || strPool.get(ps + 1) != str.get(s + 1) || strPool.get(ps + 2) != str.get(s + 2)
                                || strPool.get(ps + 3) != str.get(s + 3)) fail = true;
                        else {
                            s += 4;
                            p++;
                        }
                    }

                case OP_STR_5:
                    if (rightRange - s < 5) fail = true;
                    else {
                        var ps = code[b + 3];
                        if (strPool.get(ps) != str.get(s) || strPool.get(ps + 1) != str.get(s + 1) || strPool.get(ps + 2) != str.get(s + 2)
                                || strPool.get(ps + 3) != str.get(s + 3) || strPool.get(ps + 4) != str.get(s + 4)) fail = true;
                        else {
                            s += 5;
                            p++;
                        }
                    }

                case OP_STR_N, OP_STR_MB2N1, OP_STR_MB2N2, OP_STR_MB2N3, OP_STR_MB2N, OP_STR_MB3N, OP_STR_MBN:
                    var oc = opcode;
                    tlen = oc == OP_STR_N ? code[b + 1]
                        : oc == OP_STR_MB2N1 ? 2
                        : oc == OP_STR_MB2N2 ? 4
                        : oc == OP_STR_MB2N3 ? 6
                        : oc == OP_STR_MB2N ? code[b + 1] * 2
                        : oc == OP_STR_MB3N ? code[b + 1] * 3
                        : code[b + 1] * code[b + 2];
                    if (rightRange - s < tlen) fail = true;
                    else {
                        var ps = code[b + 3];
                        var i = 0;
                        while (i < tlen) {
                            if (strPool.get(ps + i) != str.get(s + i)) {
                                fail = true;
                                break;
                            }
                            i++;
                        }
                        if (!fail) {
                            s += tlen;
                            p++;
                        }
                    }

                case OP_CCLASS:
                    if (rightRange - s < 1) fail = true;
                    else {
                        var c = str.get(s);
                        if (!bitsetAt(intPool, code[b + 1], c) || EncLen_UTF8[c] != 1) fail = true;
                        else {
                            s++;
                            p++;
                        }
                    }

                case OP_CCLASS_MB, OP_CCLASS_MIX:
                    if (rightRange - s < 1) fail = true;
                    else {
                        var c = str.get(s);
                        var mbLen = EncLen_UTF8[c];
                        if (mbLen == 1) {
                            if (opcode == OP_CCLASS_MB) fail = true;
                            else {
                                if (!bitsetAt(intPool, code[b + 1], c)) fail = true;
                                else {
                                    s++;
                                    p++;
                                }
                            }
                        }
                        else {
                            // cclass_mb:
                            if (rightRange - s < mbLen) fail = true;
                            else {
                                var ss = s;
                                s += mbLen;
                                var cp = mbcToCode(str, ss, s);
                                if (!Unicode.onigIsInCodeRange(ranges[code[b + 2]], cp)) fail = true;
                                else p++;
                            }
                        }
                    }

                case OP_CCLASS_NOT:
                    if (rightRange - s < 1) fail = true;
                    else {
                        var c = str.get(s);
                        if (bitsetAt(intPool, code[b + 1], c)) fail = true;
                        else {
                            s += EncLen_UTF8[c];
                            p++;
                        }
                    }

                case OP_CCLASS_MB_NOT, OP_CCLASS_MIX_NOT:
                    if (rightRange - s < 1) fail = true;
                    else {
                        var c = str.get(s);
                        var mbLen = EncLen_UTF8[c];
                        if (mbLen == 1) {
                            if (opcode == OP_CCLASS_MB_NOT) {
                                s++;
                                p++; // cc_mb_not_success
                            }
                            else {
                                if (bitsetAt(intPool, code[b + 1], c)) fail = true;
                                else {
                                    s++;
                                    p++;
                                }
                            }
                        }
                        else {
                            // cclass_mb_not:
                            if (!(mbLen <= rightRange - s)) {
                                // DATA_ENSURE(1) is already true here
                                s = end;
                                p++; // cc_mb_not_success
                            }
                            else {
                                var ss = s;
                                s += mbLen;
                                var cp = mbcToCode(str, ss, s);
                                if (Unicode.onigIsInCodeRange(ranges[code[b + 2]], cp)) fail = true;
                                else p++;
                            }
                        }
                    }

                case OP_ANYCHAR:
                    if (rightRange - s < 1) fail = true;
                    else {
                        n = EncLen_UTF8[str.get(s)];
                        if (rightRange - s < n) fail = true;
                        else if (str.get(s) == NEWLINE_CODE) fail = true;
                        else {
                            s += n;
                            p++;
                        }
                    }

                case OP_ANYCHAR_ML:
                    if (rightRange - s < 1) fail = true;
                    else {
                        n = EncLen_UTF8[str.get(s)];
                        if (rightRange - s < n) fail = true;
                        else {
                            s += n;
                            p++;
                        }
                    }

                case OP_ANYCHAR_STAR:
                    p++;
                    while (s < rightRange) {
                        PUSH(STK_ALT, p, s);
                        n = EncLen_UTF8[str.get(s)];
                        if (rightRange - s < n) { fail = true; break; }
                        if (str.get(s) == NEWLINE_CODE) { fail = true; break; }
                        s += n;
                    }

                case OP_ANYCHAR_ML_STAR:
                    p++;
                    while (s < rightRange) {
                        PUSH(STK_ALT, p, s);
                        n = EncLen_UTF8[str.get(s)];
                        if (n > 1) {
                            if (rightRange - s < n) { fail = true; break; }
                            s += n;
                        }
                        else {
                            s++;
                        }
                    }

                case OP_ANYCHAR_STAR_PEEK_NEXT:
                    var c = code[b + 2];
                    p++;
                    while (s < rightRange) {
                        var b = str.get(s);
                        if (c == b) {
                            PUSH(STK_ALT, p, s);
                        }
                        n = EncLen_UTF8[b];
                        if (rightRange - s < n) { fail = true; break; }
                        if (b == NEWLINE_CODE) { fail = true; break; }
                        s += n;
                    }

                case OP_ANYCHAR_ML_STAR_PEEK_NEXT:
                    var c = code[b + 2];
                    p++;
                    while (s < rightRange) {
                        var b = str.get(s);
                        if (c == b) {
                            PUSH(STK_ALT, p, s);
                        }
                        n = EncLen_UTF8[b];
                        if (n > 1) {
                            if (rightRange - s < n) { fail = true; break; }
                            s += n;
                        }
                        else {
                            s++;
                        }
                    }

                case OP_WORD:
                    if (rightRange - s < 1) fail = true;
                    else if (!isMbcWord(str, s, end)) fail = true;
                    else {
                        s += enclen(str, s);
                        p++;
                    }

                case OP_WORD_ASCII:
                    if (rightRange - s < 1) fail = true;
                    else if (!isMbcWordAscii(str, s, end)) fail = true;
                    else {
                        s += enclen(str, s);
                        p++;
                    }

                case OP_NO_WORD:
                    if (rightRange - s < 1) fail = true;
                    else if (isMbcWord(str, s, end)) fail = true;
                    else {
                        s += enclen(str, s);
                        p++;
                    }

                case OP_NO_WORD_ASCII:
                    if (rightRange - s < 1) fail = true;
                    else if (isMbcWordAscii(str, s, end)) fail = true;
                    else {
                        s += enclen(str, s);
                        p++;
                    }

                case OP_WORD_BOUNDARY:
                    var mode = code[b + 1];
                    if (s == 0) {
                        if (rightRange - s < 1) fail = true;
                        else if (!isMbcWordAsciiMode(str, s, end, mode)) fail = true;
                    }
                    else {
                        var sprev = onigencGetPrevCharHead(str, 0, s);
                        if (s == end) {
                            if (!isMbcWordAsciiMode(str, sprev, end, mode)) fail = true;
                        }
                        else {
                            if (isMbcWordAsciiMode(str, s, end, mode) == isMbcWordAsciiMode(str, sprev, end, mode)) fail = true;
                        }
                    }
                    if (!fail) p++;

                case OP_NO_WORD_BOUNDARY:
                    var mode = code[b + 1];
                    if (s == 0) {
                        if (s < rightRange && isMbcWordAsciiMode(str, s, end, mode)) fail = true;
                    }
                    else {
                        var sprev = onigencGetPrevCharHead(str, 0, s);
                        if (s == end) {
                            if (isMbcWordAsciiMode(str, sprev, end, mode)) fail = true;
                        }
                        else {
                            if (isMbcWordAsciiMode(str, s, end, mode) != isMbcWordAsciiMode(str, sprev, end, mode)) fail = true;
                        }
                    }
                    if (!fail) p++;

                case OP_WORD_BEGIN:
                    var mode = code[b + 1];
                    fail = true;
                    if (s < rightRange && isMbcWordAsciiMode(str, s, end, mode)) {
                        if (s == 0) {
                            fail = false;
                        }
                        else {
                            var sprev = onigencGetPrevCharHead(str, 0, s);
                            if (!isMbcWordAsciiMode(str, sprev, end, mode)) {
                                fail = false;
                            }
                        }
                    }
                    if (!fail) p++;

                case OP_WORD_END:
                    var mode = code[b + 1];
                    fail = true;
                    if (s != 0) {
                        var sprev = onigencGetPrevCharHead(str, 0, s);
                        if (isMbcWordAsciiMode(str, sprev, end, mode)) {
                            if (s == end || !isMbcWordAsciiMode(str, s, end, mode)) {
                                fail = false;
                            }
                        }
                    }
                    if (!fail) p++;

                case OP_TEXT_SEGMENT_BOUNDARY:
                    var isBreak:Bool;
                    var sprev = onigencGetPrevCharHead(str, 0, s);
                    if (code[b + 1] == EXTENDED_GRAPHEME_CLUSTER_BOUNDARY)
                        isBreak = Unicode.onigencEgcbIsBreakPosition(str, s, sprev, 0, end);
                    else
                        isBreak = Unicode.onigencWbIsBreakPosition(str, s, sprev, 0, end);
                    if (code[b + 2] != 0)
                        isBreak = !isBreak;
                    if (isBreak) p++;
                    else fail = true;

                case OP_BEGIN_BUF:
                    if (s != 0) fail = true;
                    else if (OPTON_NOTBOL(options)) fail = true;
                    else if (OPTON_NOT_BEGIN_STRING(options)) fail = true;
                    else p++;

                case OP_END_BUF:
                    if (s != end) fail = true;
                    else if (OPTON_NOTEOL(options)) fail = true;
                    else if (OPTON_NOT_END_STRING(options)) fail = true;
                    else p++;

                case OP_BEGIN_LINE:
                    if (s == 0) {
                        if (OPTON_NOTBOL(options)) fail = true;
                        else p++;
                    }
                    else if (s != end) {
                        var sprev = onigencGetPrevCharHead(str, 0, s);
                        if (isMbcNewline(str, sprev, end)) p++;
                        else fail = true;
                    }
                    else fail = true;

                case OP_END_LINE:
                    if (s == end) {
                        if (OPTON_NOTEOL(options)) fail = true;
                        else p++;
                    }
                    else if (isMbcNewline(str, s, end)) {
                        p++;
                    }
                    else fail = true;

                case OP_SEMI_END_BUF:
                    if (s == end) {
                        if (OPTON_NOTEOL(options)) fail = true;
                        else if (OPTON_NOT_END_STRING(options)) fail = true;
                        else p++;
                    }
                    else if (isMbcNewline(str, s, end) && s + enclen(str, s) == end) {
                        if (OPTON_NOTEOL(options)) fail = true;
                        else if (OPTON_NOT_END_STRING(options)) fail = true;
                        else p++;
                    }
                    else fail = true;

                case OP_CHECK_POSITION:
                    switch (code[b + 1]) {
                        case CHECK_POSITION_SEARCH_START:
                            if (s != msa.start) fail = true;
                            else if (OPTON_NOT_BEGIN_POSITION(options)) fail = true;
                        case CHECK_POSITION_CURRENT_RIGHT_RANGE:
                            if (s != rightRange) fail = true;
                        default:
                    }
                    if (!fail) p++;

                case OP_MEM_START_PUSH:
                    mem = code[b + 2];
                    ENSURE();
                    stkType[stk] = STK_MEM_START;
                    stkZid[stk] = mem;
                    stk0[stk] = s;
                    stk1[stk] = memStartStk[mem];
                    stk2[stk] = memEndStk[mem];
                    memStartStk[mem] = stk;
                    memEndStk[mem] = INVALID_STACK_INDEX;
                    stk++;
                    p++;

                case OP_MEM_START:
                    mem = code[b + 2];
                    memStartStk[mem] = s;
                    p++;

                case OP_MEM_END_PUSH:
                    mem = code[b + 2];
                    ENSURE();
                    stkType[stk] = STK_MEM_END;
                    stkZid[stk] = mem;
                    stk0[stk] = s;
                    stk1[stk] = memStartStk[mem];
                    stk2[stk] = memEndStk[mem];
                    memEndStk[mem] = stk;
                    stk++;
                    p++;

                case OP_MEM_END:
                    mem = code[b + 2];
                    memEndStk[mem] = s;
                    p++;

                case OP_MEM_END_PUSH_REC:
                    mem = code[b + 2];
                    var si = stackGetMemStart(stkType, stkZid, stk, mem); /* should be before push mem-end. */
                    ENSURE();
                    stkType[stk] = STK_MEM_END;
                    stkZid[stk] = mem;
                    stk0[stk] = s;
                    stk1[stk] = memStartStk[mem];
                    stk2[stk] = memEndStk[mem];
                    memEndStk[mem] = stk;
                    stk++;
                    memStartStk[mem] = si;
                    p++;

                case OP_MEM_END_REC:
                    mem = code[b + 2];
                    memEndStk[mem] = s;
                    var stkp = stackGetMemStart(stkType, stkZid, stk, mem);
                    if (MEM_STATUS_AT(pushMemStart, mem))
                        memStartStk[mem] = stkp;
                    else
                        memStartStk[mem] = stk0[stkp];
                    ENSURE();
                    stkType[stk] = STK_MEM_END_MARK;
                    stkZid[stk] = mem;
                    stk++;
                    p++;

                case OP_BACKREF1, OP_BACKREF2, OP_BACKREF_N:
                    mem = opcode == OP_BACKREF1 ? 1 : opcode == OP_BACKREF2 ? 2 : code[b + 1];
                    // backref:
                    if (memEndStk[mem] == INVALID_STACK_INDEX) fail = true;
                    else if (memStartStk[mem] == INVALID_STACK_INDEX) fail = true;
                    else {
                        var pstart = STACK_MEM_START(mem);
                        var pend = STACK_MEM_END(mem);
                        n = pend - pstart;
                        if (n != 0) {
                            if (rightRange - s < n) fail = true;
                            else {
                                while (n-- > 0) {
                                    if (str.get(s++) != str.get(pstart++)) {
                                        fail = true;
                                        break;
                                    }
                                }
                            }
                        }
                        if (!fail) p++;
                    }

                case OP_BACKREF_N_IC:
                    mem = code[b + 1];
                    if (memEndStk[mem] == INVALID_STACK_INDEX) fail = true;
                    else if (memStartStk[mem] == INVALID_STACK_INDEX) fail = true;
                    else {
                        var pstart = STACK_MEM_START(mem);
                        var pend = STACK_MEM_END(mem);
                        n = pend - pstart;
                        if (n != 0) {
                            if (rightRange - s < n) fail = true;
                            else {
                                var ns = stringCmpIc(caseFoldFlag, str, pstart, str, s, n);
                                if (ns < 0) fail = true;
                                else s = ns;
                            }
                        }
                        if (!fail) p++;
                    }

                case OP_BACKREF_MULTI, OP_BACKREF_MULTI_IC:
                    var ic = opcode == OP_BACKREF_MULTI_IC;
                    tlen = code[b + 2];
                    var i = 0;
                    while (i < tlen) {
                        mem = tlen == 1 ? code[b + 1] : intPool[code[b + 4] + i];
                        if (memEndStk[mem] == INVALID_STACK_INDEX) { i++; continue; }
                        if (memStartStk[mem] == INVALID_STACK_INDEX) { i++; continue; }
                        var pstart = STACK_MEM_START(mem);
                        var pend = STACK_MEM_END(mem);
                        n = pend - pstart;
                        if (n != 0) {
                            if (!(n <= rightRange - s)) { i++; continue; }
                            var swork = s;
                            var isFail = false;
                            if (ic) {
                                var ns = stringCmpIc(caseFoldFlag, str, pstart, str, swork, n);
                                if (ns < 0) isFail = true;
                                else swork = ns;
                            }
                            else {
                                while (n-- > 0) {
                                    if (str.get(swork++) != str.get(pstart++)) {
                                        isFail = true;
                                        break;
                                    }
                                }
                            }
                            if (isFail) { i++; continue; }
                            s = swork;
                        }
                        break; /* success */
                    }
                    if (i == tlen) fail = true;
                    else p++;

                case OP_BACKREF_WITH_LEVEL, OP_BACKREF_WITH_LEVEL_IC:
                    var ic = opcode == OP_BACKREF_WITH_LEVEL_IC;
                    var level = code[b + 3];
                    tlen = code[b + 2];
                    var ns = backrefMatchAtNestedLevel(reg, msa, stk, str, ic, caseFoldFlag, level, tlen, intPool, code[b + 4], s, end);
                    if (ns < 0) fail = true;
                    else {
                        s = ns;
                        p++;
                    }

                case OP_BACKREF_CHECK:
                    tlen = code[b + 2];
                    var mems = code[b + 4];
                    var i = 0;
                    while (i < tlen) {
                        mem = intPool[mems + i];
                        if (memEndStk[mem] == INVALID_STACK_INDEX) { i++; continue; }
                        if (memStartStk[mem] == INVALID_STACK_INDEX) { i++; continue; }
                        break; /* success */
                    }
                    if (i == tlen) fail = true;
                    else p++;

                case OP_BACKREF_CHECK_WITH_LEVEL:
                    var level = code[b + 3];
                    tlen = code[b + 2];
                    if (!backrefCheckAtNestedLevel(reg, msa, stk, level, tlen, intPool, code[b + 4])) fail = true;
                    else p++;

                case OP_EMPTY_CHECK_START:
                    mem = code[b + 1]; /* mem: null check id */
                    ENSURE();
                    stkType[stk] = STK_EMPTY_CHECK_START;
                    stkZid[stk] = mem;
                    stk0[stk] = s;
                    stk++;
                    p++;

                case OP_EMPTY_CHECK_END:
                    mem = code[b + 1]; /* mem: null check id */
                    var k = stk;
                    while (true) {
                        k--;
                        if (stkType[k] == STK_EMPTY_CHECK_START) {
                            if (stkZid[k] == mem) break;
                        }
                    }
                    var isEmpty = stk0[k] == s;
                    p++;
                    if (isEmpty) {
                        /* empty loop founded, skip next instruction */
                        p++;
                    }

                case OP_EMPTY_CHECK_END_MEMST:
                    mem = code[b + 1]; /* mem: null check id */
                    var isEmpty = stackEmptyCheckMem(msa, stk, mem, code[b + 3], s, pushMemStart);
                    p++;
                    if (isEmpty != 0) {
                        if (isEmpty == -1) fail = true;
                        else p++;
                    }

                case OP_EMPTY_CHECK_END_MEMST_PUSH:
                    mem = code[b + 1]; /* mem: null check id */
                    var isEmpty = stackEmptyCheckMemRec(msa, stk, mem, code[b + 3], s);
                    p++;
                    if (isEmpty != 0) {
                        if (isEmpty == -1) fail = true;
                        else p++;
                    }
                    else {
                        ENSURE();
                        stkType[stk] = STK_EMPTY_CHECK_END;
                        stkZid[stk] = mem;
                        stk++;
                    }

                case OP_JUMP:
                    p += code[b + 1];

                case OP_PUSH:
                    PUSH(STK_ALT, p + code[b + 1], s);
                    p++;

                case OP_PUSH_SUPER:
                    PUSH(STK_SUPER_ALT, p + code[b + 1], s);
                    p++;

                case OP_POP:
                    stk--;
                    p++;

                case OP_POP_TO_MARK:
                    var sid = code[b + 2];
                    while (true) {
                        stk--;
                        var t = stkType[stk];
                        if ((t & STK_MASK_POP_HANDLED_TIL) != 0) {
                            if (t == STK_MARK) {
                                if (stkZid[stk] == sid) break;
                            }
                            else {
                                if (t == STK_MEM_START || t == STK_MEM_END) {
                                    memStartStk[stkZid[stk]] = stk1[stk];
                                    memEndStk[stkZid[stk]] = stk2[stk];
                                }
                                else if (t == STK_RETURN) {
                                    subexpCallNestCounter++;
                                }
                                else if (t == STK_CALL_FRAME) {
                                    subexpCallNestCounter--;
                                }
                            }
                        }
                    }
                    p++;

                case OP_PUSH_OR_JUMP_EXACT1:
                    var addr = code[b + 1];
                    if (s < rightRange && code[b + 2] == str.get(s)) {
                        PUSH(STK_ALT, p + addr, s);
                        p++;
                    }
                    else {
                        p += addr;
                    }

                case OP_PUSH_IF_PEEK_NEXT:
                    if (s < rightRange && code[b + 2] == str.get(s)) {
                        PUSH(STK_ALT, p + code[b + 1], s);
                    }
                    p++;

                case OP_REPEAT:
                    mem = code[b + 2]; /* mem: OP_REPEAT ID */
                    ENSURE();
                    stkType[stk] = STK_REPEAT_INC;
                    stkZid[stk] = mem;
                    stk0[stk] = 0;
                    stk++;
                    if (reg.repeatRange[mem].lower == 0) {
                        PUSH(STK_ALT, p + code[b + 1], s);
                    }
                    p++;

                case OP_REPEAT_NG:
                    mem = code[b + 2]; /* mem: OP_REPEAT ID */
                    ENSURE();
                    stkType[stk] = STK_REPEAT_INC;
                    stkZid[stk] = mem;
                    stk0[stk] = 0;
                    stk++;
                    if (reg.repeatRange[mem].lower == 0) {
                        PUSH(STK_ALT, p + 1, s);
                        p += code[b + 1];
                    }
                    else
                        p++;

                case OP_REPEAT_INC:
                    mem = code[b + 2]; /* mem: OP_REPEAT ID */
                    n = stackGetRepeatCount(stkType, stkZid, stk0, stk, mem);
                    n++;
                    var rr = reg.repeatRange[mem];
                    if (n >= rr.upper) {
                        /* end of repeat. Nothing to do. */
                        p++;
                    }
                    else if (n >= rr.lower) {
                        p++;
                        PUSH(STK_ALT, p, s);
                        p = rr.pcode;
                    }
                    else {
                        p = rr.pcode;
                    }
                    ENSURE();
                    stkType[stk] = STK_REPEAT_INC;
                    stkZid[stk] = mem;
                    stk0[stk] = n;
                    stk++;

                case OP_REPEAT_INC_NG:
                    mem = code[b + 2]; /* mem: OP_REPEAT ID */
                    n = stackGetRepeatCount(stkType, stkZid, stk0, stk, mem);
                    n++;
                    ENSURE();
                    stkType[stk] = STK_REPEAT_INC;
                    stkZid[stk] = mem;
                    stk0[stk] = n;
                    stk++;
                    var rr = reg.repeatRange[mem];
                    if (n == rr.upper) {
                        p++;
                    }
                    else {
                        if (n >= rr.lower) {
                            PUSH(STK_ALT, rr.pcode, s);
                            p++;
                        }
                        else {
                            p = rr.pcode;
                        }
                    }

                case OP_CALL:
                    if (subexpCallNestCounter == SubexpCallMaxNestLevel)
                        fail = true;
                    else {
                        subexpCallNestCounter++;
                        if (SubexpCallLimitInSearch != 0) {
                            msa.subexpCallInSearchCounter++;
                            if (msa.subexpCallInSearchCounter > SubexpCallLimitInSearch) {
                                bestLen = ONIGERR_SUBEXP_CALL_LIMIT_IN_SEARCH_OVER;
                                break; // MATCH_AT_ERROR_RETURN
                            }
                        }
                        var addr = code[b + 1];
                        p++;
                        ENSURE();
                        stkType[stk] = STK_CALL_FRAME;
                        stk0[stk] = p;
                        stk++;
                        p = addr;
                    }

                case OP_RETURN:
                    // STACK_RETURN(p)
                    var level = 0;
                    var k = stk;
                    while (true) {
                        k--;
                        var t = stkType[k];
                        if (t == STK_CALL_FRAME) {
                            if (level == 0) {
                                p = stk0[k];
                                break;
                            }
                            else level--;
                        }
                        else if (t == STK_RETURN)
                            level++;
                    }
                    ENSURE();
                    stkType[stk] = STK_RETURN;
                    stk++;
                    subexpCallNestCounter--;

                case OP_MOVE:
                    if (code[b + 1] < 0) {
                        s = onigencStepBack(str, 0, s, -code[b + 1]);
                        if (s == NULL_UCHARP) fail = true;
                    }
                    else {
                        tlen = code[b + 1];
                        while (tlen > 0) {
                            var len = enclen(str, s);
                            s += len;
                            if (s > end) { fail = true; break; }
                            if (s == end) {
                                if (tlen != 1) fail = true;
                                break;
                            }
                            tlen--;
                        }
                    }
                    if (!fail) p++;

                case OP_STEP_BACK_START:
                    tlen = code[b + 2];
                    if (tlen != 0) {
                        s = onigencStepBack(str, 0, s, tlen);
                        if (s == NULL_UCHARP) fail = true;
                    }
                    if (!fail) {
                        if (code[b + 3] != 0) {
                            PUSH_ZID(STK_ALT, p + 1, s, code[b + 3]);
                            p += code[b + 1];
                        }
                        else
                            p++;
                    }

                case OP_STEP_BACK_NEXT:
                    tlen = stkZid[stk]; /* remaining count */
                    if (tlen != INFINITE_LEN) tlen--;
                    s = onigencStepBack(str, 0, s, 1);
                    if (s == NULL_UCHARP) fail = true;
                    else {
                        if (tlen != 0) {
                            PUSH_ZID(STK_ALT, p, s, tlen);
                        }
                        p++;
                    }

                case OP_CUT_TO_MARK:
                    mem = code[b + 2]; /* mem: mark id */
                    // STACK_TO_VOID_TO_MARK(stkp, mem)
                    var k = stk;
                    while (true) {
                        k--;
                        var t = stkType[k];
                        if ((t & STK_MASK_TO_VOID_TARGET) != 0) {
                            if (t == STK_MARK) {
                                if (stkZid[k] == mem) {
                                    stkType[k] = STK_VOID;
                                    break;
                                } /* don't void different id mark */
                            }
                            else
                                stkType[k] = STK_VOID;
                        }
                    }
                    if (code[b + 3] != 0) {
                        s = stk1[k];
                    }
                    p++;

                case OP_MARK:
                    mem = code[b + 2]; /* mem: mark id */
                    ENSURE();
                    stkType[stk] = STK_MARK;
                    stkZid[stk] = mem;
                    if (code[b + 3] != 0)
                        stk1[stk] = s;
                    stk++;
                    p++;

                case OP_SAVE_VAL:
                    var type = code[b + 1];
                    mem = code[b + 2]; /* mem: save id */
                    ENSURE();
                    stkType[stk] = STK_SAVE_VAL;
                    stkZid[stk] = mem;
                    stk0[stk] = type;
                    stk1[stk] = (type == SAVE_RIGHT_RANGE) ? rightRange : s;
                    stk++;
                    p++;

                case OP_UPDATE_VAR:
                    switch (code[b + 1]) {
                        case UPDATE_VAR_KEEP_FROM_STACK_LAST:
                            // STACK_GET_SAVE_VAL_TYPE_LAST(SAVE_KEEP, keep)
                            var k = stk;
                            while (k > 0) {
                                k--;
                                if (stkType[k] == STK_SAVE_VAL && stk0[k] == SAVE_KEEP) {
                                    keep = stk1[k];
                                    break;
                                }
                            }
                        case UPDATE_VAR_S_FROM_STACK:
                            mem = code[b + 2]; /* mem: save id */
                            var v = stackGetSaveValTypeLastId(stkType, stkZid, stk0, stk1, stk, SAVE_S, mem, false);
                            if (v != -2) s = v;
                        case UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK, UPDATE_VAR_RIGHT_RANGE_FROM_STACK:
                            var saveType = code[b + 1] == UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK ? SAVE_S : SAVE_RIGHT_RANGE;
                            mem = code[b + 2]; /* mem: save id */
                            var v = stackGetSaveValTypeLastId(stkType, stkZid, stk0, stk1, stk, saveType, mem, code[b + 3] != 0);
                            if (v != -2) rightRange = v;
                        case UPDATE_VAR_RIGHT_RANGE_TO_S:
                            rightRange = s;
                        case UPDATE_VAR_RIGHT_RANGE_INIT:
                            rightRange = inRightRange;
                        default:
                    }
                    p++;

                case OP_CALLOUT_CONTENTS, OP_CALLOUT_NAME:
                    var of = opcode == OP_CALLOUT_NAME ? ONIG_CALLOUT_OF_NAME : ONIG_CALLOUT_OF_CONTENTS;
                    mem = code[b + 2];
                    // callout_common_entry:
                    var e = Callout.onigRegCalloutListAt(reg, mem);
                    var in_ = e.in_;
                    var nameId:Int;
                    var func:Int;
                    if (of == ONIG_CALLOUT_OF_NAME) {
                        nameId = code[b + 3];
                        func = e.startFunc;
                    }
                    else {
                        nameId = ONIG_NON_NAME_ID;
                        func = Callout.FUNC_NONE; // msa->mp->progress_callout_of_contents (no default progress callout)
                    }
                    var retraction = false;
                    var calloutError = false;
                    if (func != Callout.FUNC_NONE && (in_ & ONIG_CALLOUT_IN_PROGRESS) != 0) {
                        var callResult = calloutCall(func, ONIG_CALLOUT_IN_PROGRESS, nameId, mem, reg, str, end, sstart, rightRange, s,
                            retryInMatchCounter, msa);
                        switch (callResult) {
                            case ONIG_CALLOUT_FAIL:
                                fail = true;
                            case ONIG_CALLOUT_SUCCESS:
                                retraction = true;
                            default: /* error code */
                                if (callResult > 0) {
                                    callResult = ONIGERR_INVALID_ARGUMENT;
                                }
                                bestLen = callResult;
                                calloutError = true;
                        }
                    }
                    else {
                        retraction = true;
                    }
                    if (calloutError) break; // goto match_at_end
                    if (retraction) {
                        // retraction_callout2:
                        if ((in_ & ONIG_CALLOUT_IN_RETRACTION) != 0) {
                            if (of == ONIG_CALLOUT_OF_NAME) {
                                if (func != Callout.FUNC_NONE) {
                                    ENSURE();
                                    stkType[stk] = STK_CALLOUT;
                                    stkZid[stk] = nameId;
                                    stk0[stk] = mem;
                                    stk1[stk] = func;
                                    stk++;
                                }
                            }
                            // callouts of contents: no default retraction callout
                        }
                    }
                    if (!fail) p++;

                case OP_FINISH:
                    break; // goto match_at_end

                case OP_FAIL:
                    fail = true;

                default:
                    bestLen = ONIGERR_UNDEFINED_BYTECODE;
                    break;
            }

            if (fail) {
                // STACK_POP
                switch (popLevel) {
                    case STACK_POP_LEVEL_FREE:
                        while (true) {
                            stk--;
                            if ((stkType[stk] & STK_MASK_POP_USED) != 0) break;
                        }
                    case STACK_POP_LEVEL_MEM_START:
                        while (true) {
                            stk--;
                            var t = stkType[stk];
                            if ((t & STK_MASK_POP_USED) != 0) break;
                            else if (t == STK_MEM_START) {
                                memStartStk[stkZid[stk]] = stk1[stk];
                                memEndStk[stkZid[stk]] = stk2[stk];
                            }
                        }
                    default:
                        while (true) {
                            stk--;
                            var t = stkType[stk];
                            if ((t & STK_MASK_POP_USED) != 0) break;
                            else if ((t & STK_MASK_POP_HANDLED) != 0) {
                                if (t == STK_MEM_START || t == STK_MEM_END) {
                                    memStartStk[stkZid[stk]] = stk1[stk];
                                    memEndStk[stkZid[stk]] = stk2[stk];
                                }
                                else if (t == STK_RETURN) {
                                    subexpCallNestCounter++;
                                }
                                else if (t == STK_CALL_FRAME) {
                                    subexpCallNestCounter--;
                                }
                                else if (t == STK_CALLOUT) {
                                    // RETRACTION_CALLOUT
                                    var result = calloutCall(stk1[stk], ONIG_CALLOUT_IN_RETRACTION, stkZid[stk], stk0[stk], reg, str, end,
                                        sstart, rightRange, s, retryInMatchCounter, msa);
                                    if (result != ONIG_CALLOUT_FAIL && result != ONIG_CALLOUT_SUCCESS) {
                                        if (result > 0) {
                                            result = ONIGERR_INVALID_ARGUMENT;
                                        }
                                        bestLen = result;
                                        calloutAbort = true;
                                        break;
                                    }
                                }
                            }
                        }
                }
                if (calloutAbort) break; // goto match_at_end
                p = stk0[stk];
                s = stk1[stk];
                if (++retryInMatchCounter > retryLimitInMatch) {
                    bestLen = retryInMatchCounter > msa.retryLimitInMatch ? ONIGERR_RETRY_LIMIT_IN_MATCH_OVER : ONIGERR_RETRY_LIMIT_IN_SEARCH_OVER;
                    break;
                }
            }
        }

        // match_at_end:
        if (msa.retryLimitInSearch != 0) {
            msa.retryLimitInSearchCounter += retryInMatchCounter;
        }
        return bestLen;
    }

    /** CALLOUT_BODY */
    static function calloutCall(func:Int, in_:Int, nameId:Int, num:Int, reg:Regex, str:Bytes, end:Int, sstart:Int, rightRange:Int,
            s:Int, retryInMatchCounter:Int, msa:MatchArg):Int {
        var args = msa.calloutArgs;
        if (args == null) {
            args = new Callout.OnigCalloutArgs();
            msa.calloutArgs = args;
        }
        args.in_ = in_;
        args.nameId = nameId;
        args.num = num;
        args.regex = reg;
        args.string = str;
        args.stringEnd = end;
        args.start = sstart;
        args.rightRange = rightRange;
        args.current = s;
        args.retryInMatchCounter = retryInMatchCounter;
        args.msa = msa;
        return Callout.call(func, args);
    }

    /** STACK_GET_MEM_START: returns the stack index k */
    static function stackGetMemStart(stkType:IntArray, stkZid:IntArray, stk:Int, mnum:Int):Int {
        var level = 0;
        var k = stk;
        while (k > 0) {
            k--;
            var t = stkType[k];
            if ((t & STK_MASK_MEM_END_OR_MARK) != 0 && stkZid[k] == mnum) {
                level++;
            }
            else if (t == STK_MEM_START && stkZid[k] == mnum) {
                if (level == 0) break;
                level--;
            }
        }
        return k;
    }

    /** STACK_GET_REPEAT_COUNT_SEARCH */
    static function stackGetRepeatCount(stkType:IntArray, stkZid:IntArray, stk0:IntArray, stk:Int, sid:Int):Int {
        var k = stk;
        while (true) {
            k--;
            var t = stkType[k];
            if (t == STK_REPEAT_INC) {
                if (stkZid[k] == sid) {
                    return stk0[k];
                }
            }
            else if (t == STK_RETURN) {
                var level = -1;
                while (true) {
                    k--;
                    var t2 = stkType[k];
                    if (t2 == STK_CALL_FRAME) {
                        level++;
                        if (level == 0) break;
                    }
                    else if (t2 == STK_RETURN) level--;
                }
            }
        }
    }

    /** STACK_GET_SAVE_VAL_TYPE_LAST_ID (-2 when not found) */
    static function stackGetSaveValTypeLastId(stkType:IntArray, stkZid:IntArray, stk0:IntArray, stk1:IntArray, stk:Int,
            stype:Int, sid:Int, clear:Bool):Int {
        var level = 0;
        var k = stk;
        while (k > 0) {
            k--;
            var t = stkType[k];
            if (t == STK_SAVE_VAL && stk0[k] == stype && stkZid[k] == sid) {
                if (level == 0) {
                    var v = stk1[k];
                    if (clear) stkType[k] = STK_VOID;
                    return v;
                }
            }
            else if (t == STK_CALL_FRAME)
                level--;
            else if (t == STK_RETURN)
                level++;
        }
        return -2;
    }

    /** STACK_EMPTY_CHECK_MEM: 0 not empty, 1 empty */
    static function stackEmptyCheckMem(msa:MatchArg, stk:Int, sid:Int, emptyStatusMem:Int, s:Int, pushMemStart:Int):Int {
        var stkType = Regexec.stkType;
        var stkZid = Regexec.stkZid;
        var stk0 = Regexec.stk0;
        var stk1 = Regexec.stk1;
        var stk2 = Regexec.stk2;
        // GET_EMPTY_CHECK_START(sid, klow)
        var klow = stk;
        while (true) {
            klow--;
            if (stkType[klow] == STK_EMPTY_CHECK_START) {
                if (stkZid[klow] == sid) break;
            }
        }
        if (stk0[klow] != s) {
            return 0;
        }
        var ms = emptyStatusMem;
        var k = stk;
        while (k > klow) {
            k--;
            if (stkType[k] == STK_MEM_END && MEM_STATUS_LIMIT_AT(ms, stkZid[k])) {
                var kk = klow;
                while (kk < k) {
                    if (stkType[kk] == STK_MEM_START && stkZid[kk] == stkZid[k]) {
                        if (stk2[kk] == INVALID_STACK_INDEX
                                || ((stk0[stk2[kk]] != stk0[k] || stk0[stk1[kk]] != stk0[stk1[k]])
                                    && (stk0[stk1[k]] != stk0[k] || stk0[stk1[kk]] != stk0[stk2[kk]]))) {
                            return 0;
                        }
                        else {
                            ms &= ~(1 << stkZid[k]);
                            break;
                        }
                    }
                    kk++;
                }
                if (ms == 0) break;
            }
        }
        return 1;
    }

    /** STACK_EMPTY_CHECK_MEM_REC */
    static function stackEmptyCheckMemRec(msa:MatchArg, stk:Int, sid:Int, emptyStatusMem:Int, s:Int):Int {
        var stkType = Regexec.stkType;
        var stkZid = Regexec.stkZid;
        var stk0 = Regexec.stk0;
        var stk1 = Regexec.stk1;
        var stk2 = Regexec.stk2;
        var level = 0;
        var klow = stk;
        while (true) {
            klow--;
            var t = stkType[klow];
            if (t == STK_EMPTY_CHECK_START) {
                if (stkZid[klow] == sid) {
                    if (level == 0) {
                        if (stk0[klow] != s) {
                            return 0;
                        }
                        else {
                            if (emptyStatusMem == 0) return 1;
                            var ms = emptyStatusMem;
                            var k = stk;
                            while (k > klow) {
                                k--;
                                var tk = stkType[k];
                                if (tk == STK_MEM_END) {
                                    if (level == 0 && MEM_STATUS_LIMIT_AT(ms, stkZid[k])) {
                                        var kk = klow;
                                        kk++;
                                        while (kk < k) {
                                            var tkk = stkType[kk];
                                            if (tkk == STK_MEM_START && stkZid[kk] == stkZid[k]) {
                                                if (stk2[kk] == INVALID_STACK_INDEX
                                                        || ((stk0[stk2[kk]] != stk0[k] || stk0[stk1[kk]] != stk0[stk1[k]])
                                                            && (stk0[stk1[k]] != stk0[k] || stk0[stk1[kk]] != stk0[stk2[kk]]))) {
                                                    return 0;
                                                }
                                                else {
                                                    ms &= ~(1 << stkZid[k]);
                                                    break;
                                                }
                                            }
                                            else if (tkk == STK_EMPTY_CHECK_START) {
                                                if (stkZid[kk] == sid) level++;
                                            }
                                            else if (tkk == STK_EMPTY_CHECK_END) {
                                                if (stkZid[kk] == sid) level--;
                                            }
                                            kk++;
                                        }
                                        level = 0;
                                        if (ms == 0) break;
                                    }
                                }
                                else if (tk == STK_EMPTY_CHECK_START) {
                                    if (stkZid[k] == sid) level++;
                                }
                                else if (tk == STK_EMPTY_CHECK_END) {
                                    if (stkZid[k] == sid) level--;
                                }
                            }
                            return 1;
                        }
                    }
                    else {
                        level--;
                    }
                }
            }
            else if (t == STK_EMPTY_CHECK_END) {
                if (stkZid[klow] == sid) level++;
            }
        }
    }

    // ---- search ----

    static function slowSearch(target:Bytes, tStart:Int, targetEnd:Int, text:Bytes, textStart:Int, textEnd:Int, textRange:Int):Int {
        var end = textEnd;
        end -= targetEnd - tStart - 1;
        if (end > textRange)
            end = textRange;

        var s = textStart;
        while (s < end) {
            if (text.get(s) == target.get(tStart)) {
                var p = s + 1;
                var t = tStart + 1;
                while (t < targetEnd) {
                    if (target.get(t) != text.get(p++))
                        break;
                    t++;
                }
                if (t == targetEnd)
                    return s;
            }
            s += enclen(text, s);
        }
        return NULL_UCHARP;
    }

    static function slowSearchBackward(target:Bytes, tStart:Int, targetEnd:Int, text:Bytes, textStart:Int, adjustText:Int, textEnd:Int,
            textStartPos:Int):Int {
        var s = textEnd;
        s -= (targetEnd - tStart);
        if (s > textStartPos)
            s = textStartPos;
        else
            s = leftAdjustCharHead(text, adjustText, s);

        while (s != NULL_UCHARP && s >= textStart) {
            if (text.get(s) == target.get(tStart)) {
                var p = s + 1;
                var t = tStart + 1;
                while (t < targetEnd) {
                    if (target.get(t) != text.get(p++))
                        break;
                    t++;
                }
                if (t == targetEnd)
                    return s;
            }
            s = onigencGetPrevCharHead(text, adjustText, s);
        }
        return NULL_UCHARP;
    }

    static function sundayQuickSearchStepForward(reg:Regex, target:Bytes, tStart:Int, targetEnd:Int, text:Bytes, textStart:Int,
            textEnd:Int, textRange:Int):Int {
        var tail = targetEnd - 1;
        var tlen1 = tail - tStart;
        var end = textRange;
        if (tlen1 > textEnd - end)
            end = textEnd - tlen1;

        var mapOffset = reg.mapOffset;
        var s = textStart;

        while (s < end) {
            var p = s + tlen1;
            var se = p;
            var t = tail;
            while (text.get(p) == target.get(t)) {
                if (t == tStart) return s;
                p--;
                t--;
            }
            if (se + mapOffset >= textEnd) break;
            var skip = reg.map.get(text.get(se + mapOffset));
            var next = s + skip;
            if (next < end)
                s = onigencGetRightAdjustCharHead(text, s, next);
            else
                break;
        }
        return NULL_UCHARP;
    }

    static function sundayQuickSearch(reg:Regex, target:Bytes, tStart:Int, targetEnd:Int, text:Bytes, textStart:Int, textEnd:Int,
            textRange:Int):Int {
        var mapOffset = reg.mapOffset;
        var tail = targetEnd - 1;
        var targetLen = targetEnd - tStart;
        var end:Int;

        if (targetLen > textEnd - textRange) {
            end = textEnd;
            if (targetLen > textEnd - textStart)
                return NULL_UCHARP;
        }
        else {
            end = textRange + targetLen;
        }

        var s = textStart + targetLen - 1;

        if (s < end) {
            while (true) {
                var p = s;
                var t = tail;
                while (text.get(p) == target.get(t)) {
                    if (t == tStart) return p;
                    p--;
                    t--;
                }
                if (textEnd - s <= mapOffset) break;
                if (reg.map.get(text.get(s + mapOffset)) >= end - s) break;
                s += reg.map.get(text.get(s + mapOffset));
            }
        }
        return NULL_UCHARP;
    }

    static function mapSearch(map:Bytes, text:Bytes, textStart:Int, textRange:Int):Int {
        var s = textStart;
        while (s < textRange) {
            if (map.get(text.get(s)) != 0) return s;
            s += enclen(text, s);
        }
        return NULL_UCHARP;
    }

    static function mapSearchBackward(map:Bytes, text:Bytes, textStart:Int, adjustText:Int, textStartPos:Int):Int {
        var s = textStartPos;
        while (s != NULL_UCHARP && s >= textStart) {
            if (map.get(text.get(s)) != 0) return s;
            s = onigencGetPrevCharHead(text, adjustText, s);
        }
        return NULL_UCHARP;
    }

    /** forward_search: returns true and sets low/high. */
    static function forwardSearch(reg:Regex, str:Bytes, end:Int, start:Int, range:Int, low:IntRefE, high:IntRefE):Bool {
        var pprev = NULL_UCHARP;
        var p = start;
        if (reg.distMin != 0) {
            if (end - p <= reg.distMin)
                return false; /* fail */
            var q = p + reg.distMin;
            while (p < q) p += enclen(str, p);
        }

        while (true) { // retry:
            switch (reg.optimize) {
                case OPTIMIZE_STR:
                    p = slowSearch(reg.exact, reg.exactStart, reg.exactEnd, str, p, end, range);
                case OPTIMIZE_STR_FAST:
                    p = sundayQuickSearch(reg, reg.exact, reg.exactStart, reg.exactEnd, str, p, end, range);
                case OPTIMIZE_STR_FAST_STEP_FORWARD:
                    p = sundayQuickSearchStepForward(reg, reg.exact, reg.exactStart, reg.exactEnd, str, p, end, range);
                case OPTIMIZE_MAP:
                    p = mapSearch(reg.map, str, p, range);
            }

            if (p != NULL_UCHARP && p < range) {
                var retryGate = false;
                if (p - start < reg.distMin) {
                    retryGate = true;
                }
                else if (reg.subAnchor != 0) {
                    switch (reg.subAnchor) {
                        case ANCR_BEGIN_LINE:
                            if (p != 0) {
                                var prev = onigencGetPrevCharHead(str, (pprev != NULL_UCHARP ? pprev : 0), p);
                                if (!isMbcNewline(str, prev, end))
                                    retryGate = true;
                            }
                        case ANCR_END_LINE:
                            if (p == end) {
                            }
                            else if (!isMbcNewline(str, p, end))
                                retryGate = true;
                        default:
                    }
                }
                if (retryGate) {
                    // retry_gate:
                    pprev = p;
                    p += enclen(str, p);
                    continue;
                }

                if (reg.distMax == 0) {
                    low.v = p;
                    high.v = p;
                }
                else {
                    if (reg.distMax != INFINITE_LEN) {
                        if (p - 0 < reg.distMax) {
                            low.v = 0;
                        }
                        else {
                            low.v = p - reg.distMax;
                            if (low.v > start) {
                                low.v = onigencGetRightAdjustCharHead(str, start, low.v);
                            }
                        }
                    }
                    /* no needs to adjust *high, *high is used as range check only */
                    if (p - 0 < reg.distMin)
                        high.v = 0;
                    else
                        high.v = p - reg.distMin;
                }
                return true; /* success */
            }
            return false; /* fail */
        }
    }

    static function backwardSearch(reg:Regex, str:Bytes, end:Int, s:Int, range:Int, adjrange:Int, low:IntRefE, high:IntRefE):Bool {
        var p = s;
        while (true) { // retry:
            switch (reg.optimize) {
                case OPTIMIZE_STR, OPTIMIZE_STR_FAST, OPTIMIZE_STR_FAST_STEP_FORWARD:
                    p = slowSearchBackward(reg.exact, reg.exactStart, reg.exactEnd, str, range, adjrange, end, p);
                case OPTIMIZE_MAP:
                    p = mapSearchBackward(reg.map, str, range, adjrange, p);
            }

            if (p != NULL_UCHARP) {
                if (reg.subAnchor != 0) {
                    switch (reg.subAnchor) {
                        case ANCR_BEGIN_LINE:
                            if (p != 0) {
                                var prev = onigencGetPrevCharHead(str, 0, p);
                                if (prev != NULL_UCHARP && !isMbcNewline(str, prev, end)) {
                                    p = prev;
                                    continue;
                                }
                            }
                        case ANCR_END_LINE:
                            if (p == end) {
                            }
                            else if (!isMbcNewline(str, p, end)) {
                                p = onigencGetPrevCharHead(str, adjrange, p);
                                if (p == NULL_UCHARP) return false;
                                continue;
                            }
                        default:
                    }
                }

                if (reg.distMax != INFINITE_LEN) {
                    if (p - 0 < reg.distMax)
                        low.v = 0;
                    else
                        low.v = p - reg.distMax;

                    if (reg.distMin != 0) {
                        if (p - 0 < reg.distMin)
                            high.v = 0;
                        else
                            high.v = p - reg.distMin;
                    }
                    else {
                        high.v = p;
                    }
                    high.v = onigencGetRightAdjustCharHead(str, adjrange, high.v);
                }
                return true; /* success */
            }
            return false; /* fail */
        }
    }

    static var emptyBytes:Bytes = Bytes.alloc(8);
    static var tmpLow = new IntRefE();
    static var tmpHigh = new IntRefE();

    /** onig_search (forward when range > start, backward otherwise) */
    public static function onigSearch(reg:Regex, str:Bytes, end:Int, start:Int, range:Int, region:OnigRegion, option:Int):Int {
        var dataRange = range > start ? range : end;
        return searchInRange(reg, str, end, start, range, dataRange, region, option);
    }

    static inline function getMsa(reg:Regex):MatchArg {
        return singleMsa;
    }

    static function searchInRange(reg:Regex, str:Bytes, end:Int, start:Int, range:Int, dataRange:Int, region:OnigRegion, option:Int):Int {
        var r:Int;
        var s:Int;
        var origStart = start;
        var msa:MatchArg = null;

        if (region != null) {
            region.resizeClear(reg.numMem + 1);
        }

        if (start > end || start < 0) return ONIG_MISMATCH;

        if (OPTON_CHECK_VALIDITY_OF_STRING(option)) {
            if (!isValidMbcString(str, 0, end)) {
                return ONIGERR_INVALID_WIDE_CHAR_VALUE;
            }
        }

        // result codes of the main search: 0 mismatch (goto mismatch), 1 match (s), 2 finish (r)
        var outcome = 0;
        var mismatchNoMsa = false;

        /* anchor optimize: resume search range */
        if (reg.anchor != 0 && 0 < end) {
            var minSemiEnd = 0;
            var maxSemiEnd = 0;
            var gotoBeginPosition = false;
            var gotoEndBuf = false;

            if ((reg.anchor & ANCR_BEGIN_POSITION) != 0) {
                gotoBeginPosition = true;
            }
            else if ((reg.anchor & ANCR_BEGIN_BUF) != 0) {
                /* search str-position only */
                if (range > start) {
                    if (start != 0) return ONIG_MISMATCH;
                    range = 0 + 1;
                }
                else {
                    if (range <= 0) {
                        start = 0;
                        range = 0;
                    }
                    else
                        return ONIG_MISMATCH;
                }
            }
            else if ((reg.anchor & ANCR_END_BUF) != 0) {
                minSemiEnd = maxSemiEnd = end;
                gotoEndBuf = true;
            }
            else if ((reg.anchor & ANCR_SEMI_END_BUF) != 0) {
                var preEnd = onigencStepBack(str, 0, end, 1);
                maxSemiEnd = end;
                if (isMbcNewline(str, preEnd, end)) {
                    minSemiEnd = preEnd;
                    if (minSemiEnd > 0 && start <= minSemiEnd) {
                        gotoEndBuf = true;
                    }
                }
                else {
                    minSemiEnd = end;
                    gotoEndBuf = true;
                }
            }
            else if ((reg.anchor & ANCR_ANYCHAR_INF_ML) != 0 && range > start) {
                gotoBeginPosition = true;
            }

            if (gotoBeginPosition) {
                /* search start-position only */
                if (range > start)
                    range = start + 1;
                else
                    range = start;
            }
            if (gotoEndBuf) {
                // end_buf:
                if (maxSemiEnd - 0 < reg.ancDistMin)
                    return ONIG_MISMATCH;

                if (range > start) {
                    if (reg.ancDistMax != INFINITE_LEN && minSemiEnd - start > reg.ancDistMax) {
                        start = minSemiEnd - reg.ancDistMax;
                        if (start < end)
                            start = onigencGetRightAdjustCharHead(str, 0, start);
                    }
                    if (maxSemiEnd - (range - 1) < reg.ancDistMin) {
                        if (maxSemiEnd - 0 + 1 < reg.ancDistMin)
                            return ONIG_MISMATCH;
                        else
                            range = maxSemiEnd - reg.ancDistMin + 1;
                    }
                    if (start > range) return ONIG_MISMATCH;
                    /* If start == range, match with empty at end.
                       Backward search is used. */
                }
                else {
                    if (reg.ancDistMax != INFINITE_LEN && minSemiEnd - range > reg.ancDistMax) {
                        range = minSemiEnd - reg.ancDistMax;
                    }
                    if (maxSemiEnd - start < reg.ancDistMin) {
                        if (maxSemiEnd - 0 < reg.ancDistMin)
                            return ONIG_MISMATCH;
                        else {
                            start = maxSemiEnd - reg.ancDistMin;
                            start = leftAdjustCharHead(str, 0, start);
                        }
                    }
                    if (range > start) return ONIG_MISMATCH;
                }
            }
        }
        else if (0 == end) { /* empty string */
            if (reg.thresholdLen == 0) {
                str = emptyBytes;
                start = end = 0;
                s = start;
                msa = getMsa(reg);
                msa.init(reg, option, region, start);
                r = matchAt(reg, str, end, end, s, msa);
                if (r != ONIG_MISMATCH) {
                    if (r >= 0) return s;
                    return finishSearch(reg, region, r);
                }
                return finishSearch(reg, region, mismatchResult(reg, msa));
            }
            return ONIG_MISMATCH;
        }

        msa = getMsa(reg);
        msa.init(reg, option, region, origStart);

        s = start;
        r = ONIG_MISMATCH;
        if (range > start) { /* forward search */
            var done = false;
            if (reg.optimize != OPTIMIZE_NONE) {
                var schRange:Int;
                var low = tmpLow;
                var high = tmpHigh;

                if (reg.distMax != 0) {
                    if (reg.distMax == INFINITE_LEN)
                        schRange = end;
                    else {
                        if (end - range < reg.distMax)
                            schRange = end;
                        else {
                            schRange = range + reg.distMax;
                        }
                    }
                }
                else
                    schRange = range;

                if ((end - start) < reg.thresholdLen)
                    return finishSearch(reg, region, mismatchResult(reg, msa));

                if (reg.distMax != INFINITE_LEN) {
                    do {
                        if (!forwardSearch(reg, str, end, s, schRange, low, high))
                            return finishSearch(reg, region, mismatchResult(reg, msa));
                        if (s < low.v) {
                            s = low.v;
                        }
                        while (s <= high.v) {
                            r = matchAt(reg, str, end, dataRange, s, msa);
                            if (r != ONIG_MISMATCH) {
                                if (r >= 0) return s;
                                return finishSearch(reg, region, r);
                            }
                            s += enclen(str, s);
                        }
                    } while (s < range);
                    return finishSearch(reg, region, mismatchResult(reg, msa));
                }
                else { /* check only. */
                    if (!forwardSearch(reg, str, end, s, schRange, low, high))
                        return finishSearch(reg, region, mismatchResult(reg, msa));

                    if ((reg.anchor & ANCR_ANYCHAR_INF) != 0 && (reg.anchor & (ANCR_LOOK_BEHIND | ANCR_PREC_READ_NOT)) == 0) {
                        do {
                            r = matchAt(reg, str, end, dataRange, s, msa);
                            if (r != ONIG_MISMATCH) {
                                if (r >= 0) return s;
                                return finishSearch(reg, region, r);
                            }
                            var prev = s;
                            s += enclen(str, s);
                            while (!isMbcNewline(str, prev, end) && s < range) {
                                prev = s;
                                s += enclen(str, s);
                            }
                        } while (s < range);
                        return finishSearch(reg, region, mismatchResult(reg, msa));
                    }
                }
            }

            do {
                r = matchAt(reg, str, end, dataRange, s, msa);
                if (r != ONIG_MISMATCH) {
                    if (r >= 0) return s;
                    return finishSearch(reg, region, r);
                }
                s += enclen(str, s);
            } while (s < range);

            if (s == range) { /* because empty match with /$/. */
                r = matchAt(reg, str, end, dataRange, s, msa);
                if (r != ONIG_MISMATCH) {
                    if (r >= 0) return s;
                    return finishSearch(reg, region, r);
                }
            }
        }
        else { /* backward search */
            if (range < 0) return finishSearch(reg, region, mismatchResult(reg, msa));

            if (origStart < end)
                origStart += enclen(str, origStart); /* is upper range */

            if (reg.optimize != OPTIMIZE_NONE) {
                var low = tmpLow;
                var high = tmpHigh;
                var adjrange:Int;
                var schStart:Int;
                var minRange:Int;

                if ((end - range) < reg.thresholdLen) return finishSearch(reg, region, mismatchResult(reg, msa));

                if (range < end)
                    adjrange = leftAdjustCharHead(str, 0, range);
                else
                    adjrange = end;

                if (end - range > reg.distMin)
                    minRange = range + reg.distMin;
                else
                    minRange = end;

                if (reg.distMax != INFINITE_LEN) {
                    do {
                        if (end - s > reg.distMax)
                            schStart = s + reg.distMax;
                        else {
                            schStart = onigencGetPrevCharHead(str, 0, end);
                        }

                        if (!backwardSearch(reg, str, end, schStart, minRange, adjrange, low, high))
                            return finishSearch(reg, region, mismatchResult(reg, msa));

                        if (s > high.v)
                            s = high.v;

                        while (s != NULL_UCHARP && s >= low.v) {
                            r = matchAt(reg, str, end, origStart, s, msa);
                            if (r != ONIG_MISMATCH) {
                                if (r >= 0) return s;
                                return finishSearch(reg, region, r);
                            }
                            s = onigencGetPrevCharHead(str, 0, s);
                        }
                    } while (s != NULL_UCHARP && s >= range);
                    return finishSearch(reg, region, mismatchResult(reg, msa));
                }
                else { /* check only. */
                    schStart = onigencGetPrevCharHead(str, 0, end);
                    if (!backwardSearch(reg, str, end, schStart, minRange, adjrange, low, high))
                        return finishSearch(reg, region, mismatchResult(reg, msa));
                }
            }

            do {
                r = matchAt(reg, str, end, origStart, s, msa);
                if (r != ONIG_MISMATCH) {
                    if (r >= 0) return s;
                    return finishSearch(reg, region, r);
                }
                s = onigencGetPrevCharHead(str, 0, s);
            } while (s != NULL_UCHARP && s >= range);
        }

        return finishSearch(reg, region, mismatchResult(reg, msa));
    }

    /** mismatch: label (FIND_LONGEST keeps the best match) */
    static function mismatchResult(reg:Regex, msa:MatchArg):Int {
        if (OPTON_FIND_LONGEST(reg.options)) {
            if (msa.bestLen >= 0) {
                return -1000000 - msa.bestS; // encoded match position, see finishSearch
            }
        }
        return ONIG_MISMATCH;
    }

    /** finish: label */
    static function finishSearch(reg:Regex, region:OnigRegion, r:Int):Int {
        if (r <= -1000000) {
            return -1000000 - r; // match: (int)(s - str) of the FIND_LONGEST case
        }
        /* If result is mismatch and no FIND_NOT_EMPTY option,
           then the region is not set in match_at(). */
        if (OPTON_FIND_NOT_EMPTY(reg.options) && region != null) {
            region.clear();
        }
        return r;
    }

    // ---- regset ----

    static inline var SRS_DEAD:Int = 0;
    static inline var SRS_LOW_HIGH:Int = 1;
    static inline var SRS_ALL_RANGE:Int = 2;
    static inline var ACTIVATE_ALL_LOW_HIGH_SEARCH_THRESHOLD_LEN:Int = 500;

    static function regsetSearchBodyPositionLead(set:OnigRegSet, str:Bytes, end:Int, start:Int, range:Int, origRange:Int, option:Int,
            msas:Array<MatchArg>, rmatchPos:IntRefE):Int {
        var r:Int;
        var n = set.n;
        var s = start;
        var low = tmpLow;
        var high = tmpHigh;
        var srState = set.srState;
        var srLow = set.srLow;
        var srHigh = set.srHigh;
        var srSchRange = set.srSchRange;

        for (i in 0...n) {
            var reg = set.regs[i];
            srState[i] = SRS_DEAD;
            var totalActive = false;
            if (reg.optimize != OPTIMIZE_NONE) {
                if (reg.distMax != INFINITE_LEN) {
                    var schRange:Int;
                    if (end - range > reg.distMax)
                        schRange = range + reg.distMax;
                    else
                        schRange = end;

                    if (forwardSearch(reg, str, end, s, schRange, low, high)) {
                        srState[i] = SRS_LOW_HIGH;
                        srLow[i] = low.v;
                        srHigh[i] = high.v;
                        srSchRange[i] = schRange;
                    }
                }
                else {
                    var schRange = end;
                    if (forwardSearch(reg, str, end, s, schRange, low, high)) {
                        totalActive = true;
                    }
                }
            }
            else {
                totalActive = true;
            }
            if (totalActive) {
                srState[i] = SRS_ALL_RANGE;
                srLow[i] = s;
                srHigh[i] = range;
            }
        }

        if (set.allLowHigh != 0 && range - start > ACTIVATE_ALL_LOW_HIGH_SEARCH_THRESHOLD_LEN) {
            do {
                var tryCount = 0;
                for (i in 0...n) {
                    if (srState[i] == SRS_DEAD) continue;
                    if (s < srLow[i]) continue;
                    if (s >= srHigh[i]) {
                        if (forwardSearch(set.regs[i], str, end, s, srSchRange[i], low, high)) {
                            srLow[i] = low.v;
                            srHigh[i] = high.v;
                            if (s < low.v) continue;
                        }
                        else {
                            srState[i] = SRS_DEAD;
                            continue;
                        }
                    }
                    var reg = set.regs[i];
                    r = matchAt(reg, str, end, origRange, s, msas[i]);
                    if (r != ONIG_MISMATCH) {
                        if (r >= 0) {
                            rmatchPos.v = s;
                            return i;
                        }
                        else return r; /* error */
                    }
                    tryCount++;
                }

                if (s >= range) break;

                if (tryCount == 0) {
                    var lw = range;
                    for (i in 0...n) {
                        if (srState[i] == SRS_LOW_HIGH && lw > srLow[i]) {
                            lw = srLow[i];
                        }
                    }
                    if (lw == range) break;
                    s = lw;
                }
                else {
                    s += enclen(str, s);
                }
            } while (true);
        }
        else {
            var prevIsNewline = true;
            do {
                for (i in 0...n) {
                    if (srState[i] == SRS_DEAD) continue;
                    if (srState[i] == SRS_LOW_HIGH) {
                        if (s < srLow[i]) continue;
                        if (s >= srHigh[i]) {
                            if (forwardSearch(set.regs[i], str, end, s, srSchRange[i], low, high)) {
                                srLow[i] = low.v;
                                srHigh[i] = high.v;
                                if (s < low.v) continue;
                            }
                            else {
                                srState[i] = SRS_DEAD;
                                continue;
                            }
                        }
                    }

                    var reg = set.regs[i];
                    if ((reg.anchor & ANCR_ANYCHAR_INF) == 0 || prevIsNewline) {
                        r = matchAt(reg, str, end, origRange, s, msas[i]);
                        if (r != ONIG_MISMATCH) {
                            if (r >= 0) {
                                rmatchPos.v = s;
                                return i;
                            }
                            else return r; /* error */
                        }
                    }
                }

                if (s >= range) break;

                if (set.anycharInf != 0)
                    prevIsNewline = isMbcNewline(str, s, end);

                s += enclen(str, s);
            } while (true);
        }
        return ONIG_MISMATCH;
    }

    static function regsetSearchBodyRegexLead(set:OnigRegSet, str:Bytes, end:Int, start:Int, origRange:Int, lead:Int, option:Int,
            rmatchPos:IntRefE):Int {
        var n = set.n;
        var matchIndex = ONIG_MISMATCH;
        var ep = origRange;
        for (i in 0...n) {
            var reg = set.regs[i];
            var region = set.regions[i];
            var r = searchInRange(reg, str, end, start, ep, origRange, region, option);
            if (r > 0) {
                if (r < ep) {
                    matchIndex = i;
                    rmatchPos.v = r;
                    if (lead == OnigRegSet.ONIG_REGSET_PRIORITY_TO_REGEX_ORDER)
                        break;
                    ep = r;
                }
            }
            else if (r == 0) {
                matchIndex = i;
                rmatchPos.v = r;
                break;
            }
        }
        return matchIndex;
    }

    /** onig_regset_search: returns the index of the matching regex (or ONIG_MISMATCH / an error). */
    public static function onigRegsetSearch(set:OnigRegSet, str:Bytes, end:Int, start:Int, range:Int, lead:Int, option:Int,
            rmatchPos:IntRefE):Int {
        var r:Int;
        var origStart = start;
        var origRange = range;
        var msas:Array<MatchArg> = null;

        if (set.n == 0)
            return ONIG_MISMATCH;

        if (OPTON_POSIX_REGION(option) || OPTON_CALLBACK_EACH_MATCH(option))
            return ONIGERR_INVALID_ARGUMENT;

        for (i in 0...set.n) {
            var reg = set.regs[i];
            var region = set.regions[i];
            if (region != null) {
                region.resizeClear(reg.numMem + 1);
            }
        }

        if (start > end || start < 0) return ONIG_MISMATCH;
        if (0 < end) {
            /* forward search only */
            if (range < start)
                return ONIGERR_INVALID_ARGUMENT;
        }

        if (OPTON_CHECK_VALIDITY_OF_STRING(option)) {
            if (!isValidMbcString(str, 0, end)) {
                return ONIGERR_INVALID_WIDE_CHAR_VALUE;
            }
        }

        if (set.anchor != OPTIMIZE_NONE && 0 < end) {
            var minSemiEnd = 0;
            var maxSemiEnd = 0;
            var gotoBeginPosition = false;
            var gotoEndBuf = false;

            if ((set.anchor & ANCR_BEGIN_POSITION) != 0) {
                gotoBeginPosition = true;
            }
            else if ((set.anchor & ANCR_BEGIN_BUF) != 0) {
                /* search str-position only */
                if (start != 0) return ONIG_MISMATCH;
                range = 0 + 1;
            }
            else if ((set.anchor & ANCR_END_BUF) != 0) {
                minSemiEnd = maxSemiEnd = end;
                gotoEndBuf = true;
            }
            else if ((set.anchor & ANCR_SEMI_END_BUF) != 0) {
                var preEnd = onigencStepBack(str, 0, end, 1);
                maxSemiEnd = end;
                if (isMbcNewline(str, preEnd, end)) {
                    minSemiEnd = preEnd;
                    if (minSemiEnd > 0 && start <= minSemiEnd) {
                        gotoEndBuf = true;
                    }
                }
                else {
                    minSemiEnd = end;
                    gotoEndBuf = true;
                }
            }
            else if ((set.anchor & ANCR_ANYCHAR_INF_ML) != 0) {
                gotoBeginPosition = true;
            }

            if (gotoBeginPosition) {
                range = start + 1;
            }
            if (gotoEndBuf) {
                if (maxSemiEnd - 0 < set.ancDmin)
                    return ONIG_MISMATCH;
                if (minSemiEnd - start > set.ancDmax) {
                    start = minSemiEnd - set.ancDmax;
                    if (start < end)
                        start = onigencGetRightAdjustCharHead(str, 0, start);
                }
                if (maxSemiEnd - (range - 1) < set.ancDmin) {
                    range = maxSemiEnd - set.ancDmin + 1;
                }
                if (start > range) return ONIG_MISMATCH;
            }
        }
        else if (0 == end) { /* empty string */
            str = emptyBytes;
            start = end = 0;
            var s = start;
            msas = getSetMsas(set.n);
            for (i in 0...set.n) {
                msas[i].init(set.regs[i], option, set.regions[i], start);
            }
            for (i in 0...set.n) {
                var reg = set.regs[i];
                if (reg.thresholdLen == 0) {
                    r = matchAt(reg, str, end, end, s, msas[i]);
                    if (r != ONIG_MISMATCH) {
                        if (r >= 0) {
                            r = i;
                            rmatchPos.v = s;
                            return regsetFinish(set, r);
                        }
                        else return regsetFinish(set, r); /* error */
                    }
                }
            }
            return regsetFinish(set, ONIG_MISMATCH);
        }

        if (lead == OnigRegSet.ONIG_REGSET_POSITION_LEAD) {
            msas = getSetMsas(set.n);
            for (i in 0...set.n) {
                msas[i].init(set.regs[i], option, set.regions[i], origStart);
            }
            r = regsetSearchBodyPositionLead(set, str, end, start, range, origRange, option, msas, rmatchPos);
        }
        else {
            r = regsetSearchBodyRegexLead(set, str, end, start, origRange, lead, option, rmatchPos);
        }
        return regsetFinish(set, r);
    }

    static function regsetFinish(set:OnigRegSet, r:Int):Int {
        for (i in 0...set.n) {
            if (OPTON_FIND_NOT_EMPTY(set.regs[i].options) && set.regions[i] != null) {
                set.regions[i].clear();
            }
        }
        return r;
    }

}

/** An Int passed by reference. */
class IntRefE {
    public var v:Int = 0;
    public inline function new() {}
}
