// Ported from Oniguruma 6.9.8: src/regcomp.c
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. Operations are kept in an array of objects
// (one per C Operation), addresses are indexes. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regint.*;
import oniguruma.onig.Regenc.*;
import oniguruma.onig.Node.*;
import oniguruma.onig.Node.BBuf;
import oniguruma.onig.Regparse;
import oniguruma.onig.Regex.RepeatRange;
import oniguruma.onig.Regex.RegexExt;
import oniguruma.onig.Regenc.OnigCaseFoldCodeItem;

/** MinMaxLen */
class MinMaxLen {
    public var min:Int = 0;
    public var max:Int = 0;
    public function new() {}
    public inline function copyFrom(f:MinMaxLen):Void {
        min = f.min;
        max = f.max;
    }
}

/** MinMaxCharLen */
class MinMaxCharLen {
    public var min:Int = 0;
    public var max:Int = 0;
    public var minIsSure:Bool = false;
    public function new() {}
    public inline function copyFrom(f:MinMaxCharLen):Void {
        min = f.min;
        max = f.max;
        minIsSure = f.minIsSure;
    }
}

class Regcomp {

    static inline var CHAR_LEN_NORMAL:Int = 0;
    static inline var CHAR_LEN_TOP_ALT_FIXED:Int = 1;

    static inline var SIZE_INC:Int = 1;
    static inline var OPSIZE_ANYCHAR_STAR:Int = 1;
    static inline var OPSIZE_ANYCHAR_STAR_PEEK_NEXT:Int = 1;
    static inline var OPSIZE_JUMP:Int = 1;
    static inline var OPSIZE_PUSH:Int = 1;
    static inline var OPSIZE_PUSH_SUPER:Int = 1;
    static inline var OPSIZE_POP:Int = 1;
    static inline var OPSIZE_POP_TO_MARK:Int = 1;
    static inline var OPSIZE_PUSH_OR_JUMP_EXACT1:Int = 1;
    static inline var OPSIZE_PUSH_IF_PEEK_NEXT:Int = 1;
    static inline var OPSIZE_REPEAT:Int = 1;
    static inline var OPSIZE_REPEAT_INC:Int = 1;
    static inline var OPSIZE_REPEAT_INC_NG:Int = 1;
    static inline var OPSIZE_WORD_BOUNDARY:Int = 1;
    static inline var OPSIZE_BACKREF:Int = 1;
    static inline var OPSIZE_FAIL:Int = 1;
    static inline var OPSIZE_MEM_START:Int = 1;
    static inline var OPSIZE_MEM_START_PUSH:Int = 1;
    static inline var OPSIZE_MEM_END_PUSH:Int = 1;
    static inline var OPSIZE_MEM_END_PUSH_REC:Int = 1;
    static inline var OPSIZE_MEM_END:Int = 1;
    static inline var OPSIZE_MEM_END_REC:Int = 1;
    static inline var OPSIZE_EMPTY_CHECK_START:Int = 1;
    static inline var OPSIZE_EMPTY_CHECK_END:Int = 1;
    static inline var OPSIZE_CHECK_POSITION:Int = 1;
    static inline var OPSIZE_CALL:Int = 1;
    static inline var OPSIZE_RETURN:Int = 1;
    static inline var OPSIZE_MOVE:Int = 1;
    static inline var OPSIZE_STEP_BACK_START:Int = 1;
    static inline var OPSIZE_STEP_BACK_NEXT:Int = 1;
    static inline var OPSIZE_CUT_TO_MARK:Int = 1;
    static inline var OPSIZE_MARK:Int = 1;
    static inline var OPSIZE_SAVE_VAL:Int = 1;
    static inline var OPSIZE_UPDATE_VAR:Int = 1;
    static inline var OPSIZE_CALLOUT_CONTENTS:Int = 1;
    static inline var OPSIZE_CALLOUT_NAME:Int = 1;
    static inline var SIZE_OPCODE:Int = 1;

    static inline var QUANTIFIER_EXPAND_LIMIT_SIZE:Int = 10;

    public static var OnigDefaultCaseFoldFlag:Int = ONIGENC_CASE_FOLD_MIN;

    static inline function NODE_IS_REAL_IGNORECASE(node:Node):Bool {
        return node.hasStatus(NODE_ST_IGNORECASE) && !node.isStrCrude();
    }

    // ---- ops ----

    static function opsInit(reg:Regex, initAllocSize:Int):Int {
        if (initAllocSize <= 0)
            return ONIGERR_PARSER_BUG;
        reg.ops = [];
        reg.opsUsed = 0;
        return ONIG_NORMAL;
    }

    static inline function COP(reg:Regex):Operation {
        return reg.ops[reg.opsUsed - 1];
    }

    static inline function COP_CURR_OFFSET(reg:Regex):Int {
        return reg.opsUsed - 1;
    }

    static function addOp(reg:Regex, opcode:Int):Int {
        var op = new Operation();
        op.opcode = opcode;
        reg.ops.push(op);
        reg.opsUsed++;
        return 0;
    }

    static function lenMultiplyCmp(x:Int, y:Int, v:Int):Int {
        if (x == 0 || y == 0) return -1;
        if (x < Std.int(INFINITE_LEN / y)) {
            var xy = x * y;
            if (xy > v) return 1;
            else {
                if (xy == v) return 0;
                else return -1;
            }
        }
        else
            return v == INFINITE_LEN ? 0 : 1;
    }

    static inline function onigPositiveIntMultiply(x:Int, y:Int):Int {
        return Regparse.onigPositiveIntMultiply(x, y);
    }

    static function nodeSwap(a:Node, b:Node):Void {
        a.swapWith(b);
    }

    static function nodeListLen(list:Node):Int {
        var len = 1;
        while (list.cdr != null) {
            list = list.cdr;
            len++;
        }
        return len;
    }

    static function nodeListAdd(list:Node, x:Node):Node {
        var n = Regparse.onigNodeNewList(x, null);
        if (list != null) {
            while (list.cdr != null)
                list = list.cdr;
            list.cdr = n;
        }
        return n;
    }

    static function nodeStrNodeCat(node:Node, add:Node):Int {
        if (node.status != add.status)
            return ONIGERR_TYPE_BUG;
        if (node.flag != add.flag)
            return ONIGERR_TYPE_BUG;
        var r = Regparse.onigNodeStrCat(node, add.sbuf, add.s, add.end);
        if (r != 0) return r;
        return 0;
    }

    static function nodeConvToStrNode(node:Node, refNode:Node):Void {
        node.clear();
        node.nodeType = NODE_STRING;
        node.status = refNode.status;
        node.flag = refNode.flag;
        node.sbuf = null;
        node.s = 0;
        node.end = 0;
    }

    static inline function distanceAdd(d1:Int, d2:Int):Int {
        if (d1 == INFINITE_LEN || d2 == INFINITE_LEN)
            return INFINITE_LEN;
        else {
            if (d1 <= INFINITE_LEN - d2) return d1 + d2;
            else return INFINITE_LEN;
        }
    }

    static inline function distanceMultiply(d:Int, m:Int):Int {
        if (m == 0) return 0;
        if (d < Std.int(INFINITE_LEN / m))
            return d * m;
        else
            return INFINITE_LEN;
    }

    static function bitsetIsEmpty(bs:Vector<Int>):Bool {
        for (i in 0...BITSET_REAL_SIZE) {
            if (bs[i] != 0) return false;
        }
        return true;
    }

    static function unsetAddrListAdd(list:Array<UnsetAddr>, offset:Int, node:Node):Int {
        list.push(new UnsetAddr(offset, node));
        return 0;
    }

    // ---- MinMaxCharLen ----

    static inline function mmclFixed(c:MinMaxCharLen):Bool {
        return c.min == c.max && c.min != INFINITE_LEN;
    }

    static inline function mmclSet(l:MinMaxCharLen, len:Int):Void {
        l.min = len;
        l.max = len;
        l.minIsSure = true;
    }

    static inline function mmclSetMinMax(l:MinMaxCharLen, min:Int, max:Int, minIsSure:Bool):Void {
        l.min = min;
        l.max = max;
        l.minIsSure = minIsSure;
    }

    static function mmclAdd(to:MinMaxCharLen, add:MinMaxCharLen):Void {
        to.min = distanceAdd(to.min, add.min);
        to.max = distanceAdd(to.max, add.max);
        to.minIsSure = add.minIsSure && to.minIsSure;
    }

    static function mmclMultiply(to:MinMaxCharLen, m:Int):Void {
        to.min = distanceMultiply(to.min, m);
        to.max = distanceMultiply(to.max, m);
    }

    static function mmclRepeatRangeMultiply(to:MinMaxCharLen, mlow:Int, mhigh:Int):Void {
        to.min = distanceMultiply(to.min, mlow);
        if (mhigh == INFINITE_REPEAT)
            to.max = INFINITE_LEN;
        else
            to.max = distanceMultiply(to.max, mhigh);
    }

    static function mmclAltMerge(to:MinMaxCharLen, alt:MinMaxCharLen):Void {
        if (to.min > alt.min) {
            to.min = alt.min;
            to.minIsSure = alt.minIsSure;
        }
        else if (to.min == alt.min) {
            if (alt.minIsSure)
                to.minIsSure = true;
        }
        if (to.max < alt.max) to.max = alt.max;
    }

    // ---- MinMaxLen ----

    static inline function mmlIsEqual(a:MinMaxLen, b:MinMaxLen):Bool {
        return a.min == b.min && a.max == b.max;
    }

    static inline function mmlSetMinMax(l:MinMaxLen, min:Int, max:Int):Void {
        l.min = min;
        l.max = max;
    }

    static inline function mmlClear(l:MinMaxLen):Void {
        l.min = l.max = 0;
    }

    static inline function mmlCopy(to:MinMaxLen, from:MinMaxLen):Void {
        to.min = from.min;
        to.max = from.max;
    }

    static function mmlAdd(to:MinMaxLen, add:MinMaxLen):Void {
        to.min = distanceAdd(to.min, add.min);
        to.max = distanceAdd(to.max, add.max);
    }

    static function mmlAltMerge(to:MinMaxLen, alt:MinMaxLen):Void {
        if (to.min > alt.min) to.min = alt.min;
        if (to.max < alt.max) to.max = alt.max;
    }

    /* fixed size pattern node only */
    static function nodeCharLen1(node:Node, reg:Regex, ci:MinMaxCharLen, env:ParseEnv, level:Int):Int {
        var tci = new MinMaxCharLen();
        var r = CHAR_LEN_NORMAL;

        level++;

        switch (node.nodeType) {
            case NODE_LIST:
                var first = true;
                do {
                    r = nodeCharLen1(node.car, reg, tci, env, level);
                    if (r < 0) break;
                    if (first) {
                        ci.copyFrom(tci);
                        first = false;
                    }
                    else
                        mmclAdd(ci, tci);
                } while ((node = node.cdr) != null);

            case NODE_ALT:
                r = nodeCharLen1(node.car, reg, ci, env, level);
                if (r >= 0) {
                    var fixed = true;
                    while ((node = node.cdr) != null) {
                        r = nodeCharLen1(node.car, reg, tci, env, level);
                        if (r < 0) break;
                        if (!mmclFixed(tci))
                            fixed = false;
                        mmclAltMerge(ci, tci);
                    }
                    if (r >= 0) {
                        r = CHAR_LEN_NORMAL;
                        if (!mmclFixed(ci)) {
                            if (fixed && level == 1) {
                                r = CHAR_LEN_TOP_ALT_FIXED;
                            }
                        }
                    }
                }

            case NODE_STRING:
                if (NODE_IS_REAL_IGNORECASE(node) && CASE_FOLD_IS_NOT_ASCII_ONLY(env.caseFoldFlag)) {
                    /* Such a case is possible.
                       ex. /(?i)(?<=\1)(a)/
                       Backref node refer to capture group, but it doesn't tune yet.
                     */
                    r = ONIGERR_INVALID_LOOK_BEHIND_PATTERN;
                }
                else {
                    var clen = 0;
                    var s = node.s;
                    while (s < node.end) {
                        s += enclen(node.sbuf, s);
                        clen = distanceAdd(clen, 1);
                    }
                    mmclSet(ci, clen);
                }

            case NODE_QUANT:
                var qn = node;
                if (qn.lower == qn.upper) {
                    if (qn.upper == 0) {
                        mmclSet(ci, 0);
                    }
                    else {
                        r = nodeCharLen1(node.body, reg, ci, env, level);
                        if (r >= 0)
                            mmclMultiply(ci, qn.lower);
                    }
                }
                else {
                    r = nodeCharLen1(node.body, reg, ci, env, level);
                    if (r >= 0)
                        mmclRepeatRangeMultiply(ci, qn.lower, qn.upper);
                }

            case NODE_CALL:
                if (node.hasStatus(NODE_ST_RECURSION))
                    mmclSetMinMax(ci, 0, INFINITE_LEN, false);
                else
                    r = nodeCharLen1(node.body, reg, ci, env, level);

            case NODE_CTYPE, NODE_CCLASS:
                mmclSet(ci, 1);

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_MEMORY:
                        if (node.hasStatus(NODE_ST_FIXED_CLEN)) {
                            mmclSetMinMax(ci, en.minCharLen, en.maxCharLen, node.hasStatus(NODE_ST_FIXED_CLEN_MIN_SURE));
                        }
                        else {
                            if (node.hasStatus(NODE_ST_MARK1)) {
                                mmclSetMinMax(ci, 0, INFINITE_LEN, false);
                            }
                            else {
                                node.addStatus(NODE_ST_MARK1);
                                r = nodeCharLen1(node.body, reg, ci, env, level);
                                node.removeStatus(NODE_ST_MARK1);
                                if (r < 0) return r;

                                en.minCharLen = ci.min;
                                en.maxCharLen = ci.max;
                                node.addStatus(NODE_ST_FIXED_CLEN);
                                if (ci.minIsSure)
                                    node.addStatus(NODE_ST_FIXED_CLEN_MIN_SURE);
                            }
                        }
                        /* can't optimize look-behind if capture exists. */
                        ci.minIsSure = false;
                    case BAG_OPTION, BAG_STOP_BACKTRACK:
                        r = nodeCharLen1(node.body, reg, ci, env, level);
                    case BAG_IF_ELSE:
                        var eci = new MinMaxCharLen();
                        r = nodeCharLen1(node.body, reg, ci, env, level);
                        if (r < 0) return r;
                        if (en.Then != null) {
                            r = nodeCharLen1(en.Then, reg, tci, env, level);
                            if (r < 0) return r;
                            mmclAdd(ci, tci);
                        }
                        if (en.Else != null) {
                            r = nodeCharLen1(en.Else, reg, eci, env, level);
                            if (r < 0) return r;
                        }
                        else {
                            mmclSet(eci, 0);
                        }
                        mmclAltMerge(ci, eci);
                    default: /* never come here */
                        r = ONIGERR_PARSER_BUG;
                }

            case NODE_GIMMICK:
                mmclSet(ci, 0);

            case NODE_ANCHOR:
                mmclSet(ci, 0);
                /* can't optimize look-behind if anchor exists. */
                ci.minIsSure = false;

            case NODE_BACKREF:
                if (node.hasStatus(NODE_ST_CHECKER)) {
                    mmclSet(ci, 0);
                    ci.minIsSure = false;
                }
                else if (node.hasStatus(NODE_ST_RECURSION)) {
                    if (node.hasStatus(NODE_ST_NEST_LEVEL)) {
                        mmclSetMinMax(ci, 0, INFINITE_LEN, false);
                    }
                    else
                        mmclSetMinMax(ci, 0, 0, false);
                }
                else {
                    var memEnv = env.memEnv;
                    var br = node;
                    var backs = br.backs;
                    r = nodeCharLen1(memEnv[backs[0]].memNode, reg, ci, env, level);
                    if (r >= 0) {
                        if (!mmclFixed(ci)) ci.minIsSure = false;
                        for (i in 1...br.backNum) {
                            r = nodeCharLen1(memEnv[backs[i]].memNode, reg, tci, env, level);
                            if (r < 0) break;
                            if (!mmclFixed(tci)) tci.minIsSure = false;
                            mmclAltMerge(ci, tci);
                        }
                    }
                }

            default: /* never come here */
                r = ONIGERR_PARSER_BUG;
        }
        return r;
    }

    static inline function nodeCharLen(node:Node, reg:Regex, ci:MinMaxCharLen, env:ParseEnv):Int {
        return nodeCharLen1(node, reg, ci, env, 0);
    }

    static inline function IS_NEED_STR_LEN_OP(op:Int):Bool {
        return op == OP_STR_N || op == OP_STR_MB2N || op == OP_STR_MB3N || op == OP_STR_MBN;
    }

    static function selectStrOpcode(mbLen:Int, strLen:Int):Int {
        var op:Int;
        switch (mbLen) {
            case 1:
                switch (strLen) {
                    case 1: op = OP_STR_1;
                    case 2: op = OP_STR_2;
                    case 3: op = OP_STR_3;
                    case 4: op = OP_STR_4;
                    case 5: op = OP_STR_5;
                    default: op = OP_STR_N;
                }
            case 2:
                switch (strLen) {
                    case 1: op = OP_STR_MB2N1;
                    case 2: op = OP_STR_MB2N2;
                    case 3: op = OP_STR_MB2N3;
                    default: op = OP_STR_MB2N;
                }
            case 3:
                op = OP_STR_MB3N;
            default:
                op = OP_STR_MBN;
        }
        return op;
    }

    static function isStrictRealNode(node:Node):Bool {
        switch (node.nodeType) {
            case NODE_STRING:
                return node.end != node.s;
            case NODE_CCLASS, NODE_CTYPE:
                return true;
            default:
                return false;
        }
    }

    static function compileQuantBodyWithEmptyCheck(qn:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        var body = qn.body;
        var emptiness = qn.emptiness;
        var savedNumEmptyCheck = reg.numEmptyCheck;

        if (emptiness != BODY_IS_NOT_EMPTY) {
            r = addOp(reg, OP_EMPTY_CHECK_START);
            if (r != 0) return r;
            COP(reg).mem = reg.numEmptyCheck; /* NULL CHECK ID */
            reg.numEmptyCheck++;
        }

        r = compileTree(body, reg, env);
        if (r != 0) return r;

        if (emptiness != BODY_IS_NOT_EMPTY) {
            if (emptiness == BODY_MAY_BE_EMPTY)
                r = addOp(reg, OP_EMPTY_CHECK_END);
            else if (emptiness == BODY_MAY_BE_EMPTY_MEM) {
                if (qn.hasStatus(NODE_ST_EMPTY_STATUS_CHECK) && qn.emptyStatusMem != 0) {
                    r = addOp(reg, OP_EMPTY_CHECK_END_MEMST);
                    if (r != 0) return r;
                    COP(reg).emptyStatusMem = qn.emptyStatusMem;
                }
                else
                    r = addOp(reg, OP_EMPTY_CHECK_END);
            }
            else if (emptiness == BODY_MAY_BE_EMPTY_REC) {
                r = addOp(reg, OP_EMPTY_CHECK_END_MEMST_PUSH);
                if (r != 0) return r;
                COP(reg).emptyStatusMem = qn.emptyStatusMem;
            }
            if (r != 0) return r;
            COP(reg).mem = savedNumEmptyCheck; /* NULL CHECK ID */
        }
        return r;
    }

    static function compileCall(node:Node, reg:Regex, env:ParseEnv):Int {
        var r = addOp(reg, OP_CALL);
        if (r != 0) return r;
        COP(reg).addr = 0; /* dummy addr. */
        var offset = COP_CURR_OFFSET(reg);
        return unsetAddrListAdd(env.unsetAddrList, offset, node.body);
    }

    static function compileTreeNTimes(node:Node, n:Int, reg:Regex, env:ParseEnv):Int {
        for (i in 0...n) {
            var r = compileTree(node, reg, env);
            if (r != 0) return r;
        }
        return 0;
    }

    static inline function addCompileStringLength(mbLen:Int, strLen:Int):Int {
        return 1;
    }

    static function addCompileString(sb:Bytes, s:Int, mbLen:Int, strLen:Int, reg:Regex):Int {
        var op = selectStrOpcode(mbLen, strLen);
        var r = addOp(reg, op);
        if (r != 0) return r;

        var byteLen = mbLen * strLen;
        var p = Bytes.alloc(byteLen);
        p.blit(0, sb, s, byteLen);
        if (op == OP_STR_MBN) {
            COP(reg).len = mbLen;
            COP(reg).n = strLen;
            COP(reg).s = p;
        }
        else if (IS_NEED_STR_LEN_OP(op)) {
            COP(reg).n = strLen;
            COP(reg).s = p;
        }
        else {
            COP(reg).s = p;
        }
        return 0;
    }

    static function compileLengthStringNode(node:Node, reg:Regex):Int {
        if (node.end <= node.s)
            return 0;
        var sb = node.sbuf;
        var p = node.s;
        var prevLen = enclen(sb, p);
        p += prevLen;
        var slen = 1;
        var rlen = 0;
        while (p < node.end) {
            var len = enclen(sb, p);
            if (len == prevLen) {
                slen++;
            }
            else {
                rlen += addCompileStringLength(prevLen, slen);
                slen = 1;
                prevLen = len;
            }
            p += len;
        }
        rlen += addCompileStringLength(prevLen, slen);
        return rlen;
    }

    static function compileLengthStringCrudeNode(sn:Node, reg:Regex):Int {
        if (sn.end <= sn.s)
            return 0;
        return addCompileStringLength(1, sn.end - sn.s);
    }

    static function compileStringNode(node:Node, reg:Regex):Int {
        if (node.end <= node.s)
            return 0;
        var sb = node.sbuf;
        var end = node.end;
        var p = node.s;
        var prev = p;
        var prevLen = enclen(sb, p);
        p += prevLen;
        var slen = 1;
        while (p < end) {
            var len = enclen(sb, p);
            if (len == prevLen) {
                slen++;
            }
            else {
                var r = addCompileString(sb, prev, prevLen, slen, reg);
                if (r != 0) return r;
                prev = p;
                slen = 1;
                prevLen = len;
            }
            p += len;
        }
        return addCompileString(sb, prev, prevLen, slen, reg);
    }

    static function compileStringCrudeNode(sn:Node, reg:Regex):Int {
        if (sn.end <= sn.s)
            return 0;
        return addCompileString(sn.sbuf, sn.s, 1, sn.end - sn.s, reg);
    }

    static function setMultiByteCclass(mbuf:BBuf, reg:Regex):Array<Int> {
        return mbuf.p.slice(0, mbuf.used);
    }

    static inline function compileLengthCclassNode(cc:Node, reg:Regex):Int {
        return 1;
    }

    static function compileCclassNode(cc:Node, reg:Regex):Int {
        var r:Int;
        if (cc.mbuf == null) {
            r = addOp(reg, cc.isNcclassNot() ? OP_CCLASS_NOT : OP_CCLASS);
            if (r != 0) return r;
            COP(reg).bsp = cc.bs.copy();
        }
        else {
            if (bitsetIsEmpty(cc.bs)) {
                r = addOp(reg, cc.isNcclassNot() ? OP_CCLASS_MB_NOT : OP_CCLASS_MB);
                if (r != 0) return r;
                COP(reg).mb = setMultiByteCclass(cc.mbuf, reg);
            }
            else {
                r = addOp(reg, cc.isNcclassNot() ? OP_CCLASS_MIX_NOT : OP_CCLASS_MIX);
                if (r != 0) return r;
                COP(reg).bsp = cc.bs.copy();
                COP(reg).mb = setMultiByteCclass(cc.mbuf, reg);
            }
        }
        return 0;
    }

    static function setAddrInRepeatRange(reg:Regex):Void {
        // u.offset is already the ops index of the body
    }

    static function entryRepeatRange(reg:Regex, id:Int, lower:Int, upper:Int, opsIndex:Int):Int {
        if (reg.repeatRange == null) reg.repeatRange = [];
        while (reg.repeatRange.length <= id) reg.repeatRange.push(new RepeatRange());
        reg.repeatRangeAlloc = reg.repeatRange.length;
        var p = reg.repeatRange[id];
        p.lower = lower;
        p.upper = (upper == INFINITE_REPEAT ? 0x7fffffff : upper);
        p.pcode = opsIndex;
        return 0;
    }

    static function compileRangeRepeatNode(qn:Node, targetLen:Int, emptiness:Int, reg:Regex, env:ParseEnv):Int {
        var numRepeat = reg.numRepeat++;
        var r = addOp(reg, qn.greedy != 0 ? OP_REPEAT : OP_REPEAT_NG);
        if (r != 0) return r;
        COP(reg).id = numRepeat;
        COP(reg).addr = SIZE_INC + targetLen + OPSIZE_REPEAT_INC;

        r = entryRepeatRange(reg, numRepeat, qn.lower, qn.upper, COP_CURR_OFFSET(reg) + OPSIZE_REPEAT);
        if (r != 0) return r;

        r = compileQuantBodyWithEmptyCheck(qn, reg, env);
        if (r != 0) return r;

        r = addOp(reg, qn.greedy != 0 ? OP_REPEAT_INC : OP_REPEAT_INC_NG);
        if (r != 0) return r;
        COP(reg).id = numRepeat;
        return r;
    }

    static function isAnycharInfiniteGreedy(qn:Node):Bool {
        return qn.greedy != 0 && qn.upper == INFINITE_REPEAT && qn.body.isAnychar();
    }

    static function compileLengthQuantifierNode(qn:Node, reg:Regex):Int {
        var len:Int;
        var infinite = qn.upper == INFINITE_REPEAT;
        var emptiness = qn.emptiness;
        var tlen = compileLengthTree(qn.body, reg);

        if (tlen < 0) return tlen;
        if (tlen == 0) return 0;

        /* anychar repeat */
        if (isAnycharInfiniteGreedy(qn)) {
            if (qn.lower <= 1 || lenMultiplyCmp(tlen, qn.lower, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0) {
                if (qn.nextHeadExact != null)
                    return OPSIZE_ANYCHAR_STAR_PEEK_NEXT + tlen * qn.lower;
                else
                    return OPSIZE_ANYCHAR_STAR + tlen * qn.lower;
            }
        }

        var modTlen = tlen;
        if (emptiness != BODY_IS_NOT_EMPTY)
            modTlen += OPSIZE_EMPTY_CHECK_START + OPSIZE_EMPTY_CHECK_END;

        if (infinite && (qn.lower <= 1 || lenMultiplyCmp(tlen, qn.lower, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0)) {
            if (qn.lower == 1 && tlen > QUANTIFIER_EXPAND_LIMIT_SIZE) {
                len = OPSIZE_JUMP;
            }
            else {
                len = tlen * qn.lower;
            }

            if (qn.greedy != 0) {
                if (qn.headExact != null)
                    len += OPSIZE_PUSH_OR_JUMP_EXACT1 + modTlen + OPSIZE_JUMP;
                else if (qn.nextHeadExact != null)
                    len += OPSIZE_PUSH_IF_PEEK_NEXT + modTlen + OPSIZE_JUMP;
                else
                    len += OPSIZE_PUSH + modTlen + OPSIZE_JUMP;
            }
            else
                len += OPSIZE_JUMP + modTlen + OPSIZE_PUSH;
        }
        else if (qn.upper == 0) {
            if (qn.includeReferred != 0) { /* /(?<n>..){0}/ */
                len = OPSIZE_JUMP + tlen;
            }
            else
                len = 0;
        }
        else if (!infinite && qn.greedy != 0
                && (qn.upper == 1 || lenMultiplyCmp(tlen + OPSIZE_PUSH, qn.upper, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0)) {
            len = tlen * qn.lower;
            len += (OPSIZE_PUSH + tlen) * (qn.upper - qn.lower);
        }
        else if (qn.greedy == 0 && qn.upper == 1 && qn.lower == 0) { /* '??' */
            len = OPSIZE_PUSH + OPSIZE_JUMP + tlen;
        }
        else {
            len = OPSIZE_REPEAT_INC + modTlen + OPSIZE_REPEAT;
        }
        return len;
    }

    static function compileQuantifierNode(qn:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        var infinite = qn.upper == INFINITE_REPEAT;
        var emptiness = qn.emptiness;
        var tlen = compileLengthTree(qn.body, reg);

        if (tlen < 0) return tlen;
        if (tlen == 0) return 0;

        if (isAnycharInfiniteGreedy(qn) && (qn.lower <= 1 || lenMultiplyCmp(tlen, qn.lower, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0)) {
            r = compileTreeNTimes(qn.body, qn.lower, reg, env);
            if (r != 0) return r;
            if (qn.nextHeadExact != null) {
                r = addOp(reg, qn.body.hasStatus(NODE_ST_MULTILINE) ? OP_ANYCHAR_ML_STAR_PEEK_NEXT : OP_ANYCHAR_STAR_PEEK_NEXT);
                if (r != 0) return r;
                COP(reg).c = qn.nextHeadExact.sbuf.get(qn.nextHeadExact.s);
                return 0;
            }
            else {
                r = addOp(reg, qn.body.hasStatus(NODE_ST_MULTILINE) ? OP_ANYCHAR_ML_STAR : OP_ANYCHAR_STAR);
                return r;
            }
        }

        var modTlen = tlen;
        if (emptiness != BODY_IS_NOT_EMPTY)
            modTlen += OPSIZE_EMPTY_CHECK_START + OPSIZE_EMPTY_CHECK_END;

        if (infinite && (qn.lower <= 1 || lenMultiplyCmp(tlen, qn.lower, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0)) {
            var addr:Int;
            if (qn.lower == 1 && tlen > QUANTIFIER_EXPAND_LIMIT_SIZE) {
                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                if (qn.greedy != 0) {
                    if (qn.headExact != null)
                        COP(reg).addr = OPSIZE_PUSH_OR_JUMP_EXACT1 + SIZE_INC;
                    else if (qn.nextHeadExact != null)
                        COP(reg).addr = OPSIZE_PUSH_IF_PEEK_NEXT + SIZE_INC;
                    else
                        COP(reg).addr = OPSIZE_PUSH + SIZE_INC;
                }
                else {
                    COP(reg).addr = OPSIZE_JUMP + SIZE_INC;
                }
            }
            else {
                r = compileTreeNTimes(qn.body, qn.lower, reg, env);
                if (r != 0) return r;
            }

            if (qn.greedy != 0) {
                if (qn.headExact != null) {
                    r = addOp(reg, OP_PUSH_OR_JUMP_EXACT1);
                    if (r != 0) return r;
                    COP(reg).addr = SIZE_INC + modTlen + OPSIZE_JUMP;
                    COP(reg).c = qn.headExact.sbuf.get(qn.headExact.s);
                    r = compileQuantBodyWithEmptyCheck(qn, reg, env);
                    if (r != 0) return r;
                    addr = -(modTlen + OPSIZE_PUSH_OR_JUMP_EXACT1);
                }
                else if (qn.nextHeadExact != null) {
                    r = addOp(reg, OP_PUSH_IF_PEEK_NEXT);
                    if (r != 0) return r;
                    COP(reg).addr = SIZE_INC + modTlen + OPSIZE_JUMP;
                    COP(reg).c = qn.nextHeadExact.sbuf.get(qn.nextHeadExact.s);
                    r = compileQuantBodyWithEmptyCheck(qn, reg, env);
                    if (r != 0) return r;
                    addr = -(modTlen + OPSIZE_PUSH_IF_PEEK_NEXT);
                }
                else {
                    r = addOp(reg, OP_PUSH);
                    if (r != 0) return r;
                    COP(reg).addr = SIZE_INC + modTlen + OPSIZE_JUMP;
                    r = compileQuantBodyWithEmptyCheck(qn, reg, env);
                    if (r != 0) return r;
                    addr = -(modTlen + OPSIZE_PUSH);
                }
                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = addr;
            }
            else {
                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = modTlen + SIZE_INC;
                r = compileQuantBodyWithEmptyCheck(qn, reg, env);
                if (r != 0) return r;
                r = addOp(reg, OP_PUSH);
                if (r != 0) return r;
                COP(reg).addr = -modTlen;
            }
        }
        else if (qn.upper == 0) {
            if (qn.includeReferred != 0) { /* /(?<n>..){0}/ */
                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = tlen + SIZE_INC;
                r = compileTree(qn.body, reg, env);
            }
            else {
                /* Nothing output */
                r = 0;
            }
        }
        else if (!infinite && qn.greedy != 0
                && (qn.upper == 1 || lenMultiplyCmp(tlen + OPSIZE_PUSH, qn.upper, QUANTIFIER_EXPAND_LIMIT_SIZE) <= 0)) {
            var n = qn.upper - qn.lower;
            r = compileTreeNTimes(qn.body, qn.lower, reg, env);
            if (r != 0) return r;
            for (i in 0...n) {
                var v = onigPositiveIntMultiply(n - i, tlen + OPSIZE_PUSH);
                if (v < 0) return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
                r = addOp(reg, OP_PUSH);
                if (r != 0) return r;
                COP(reg).addr = v;
                r = compileTree(qn.body, reg, env);
                if (r != 0) return r;
            }
        }
        else if (qn.greedy == 0 && qn.upper == 1 && qn.lower == 0) { /* '??' */
            r = addOp(reg, OP_PUSH);
            if (r != 0) return r;
            COP(reg).addr = SIZE_INC + OPSIZE_JUMP;
            r = addOp(reg, OP_JUMP);
            if (r != 0) return r;
            COP(reg).addr = tlen + SIZE_INC;
            r = compileTree(qn.body, reg, env);
        }
        else {
            r = compileRangeRepeatNode(qn, modTlen, emptiness, reg, env);
        }
        return r;
    }

    static function compileLengthOptionNode(node:Node, reg:Regex):Int {
        return compileLengthTree(node.body, reg);
    }

    static function compileOptionNode(node:Node, reg:Regex, env:ParseEnv):Int {
        return compileTree(node.body, reg, env);
    }

    static function compileLengthBagNode(node:Node, reg:Regex):Int {
        var len = 0;
        var tlen:Int;

        if (node.type == BAG_OPTION)
            return compileLengthOptionNode(node, reg);

        if (node.body != null) {
            tlen = compileLengthTree(node.body, reg);
            if (tlen < 0) return tlen;
        }
        else
            tlen = 0;

        switch (node.type) {
            case BAG_MEMORY:
                if (node.regnum == 0 && node.hasStatus(NODE_ST_CALLED)) {
                    len = tlen + OPSIZE_CALL + OPSIZE_JUMP + OPSIZE_RETURN;
                    return len;
                }
                if (node.hasStatus(NODE_ST_CALLED)) {
                    len = OPSIZE_MEM_START_PUSH + tlen + OPSIZE_CALL + OPSIZE_JUMP + OPSIZE_RETURN;
                    if (MEM_STATUS_AT0(reg.pushMemEnd, node.regnum))
                        len += (node.hasStatus(NODE_ST_RECURSION) ? OPSIZE_MEM_END_PUSH_REC : OPSIZE_MEM_END_PUSH);
                    else
                        len += (node.hasStatus(NODE_ST_RECURSION) ? OPSIZE_MEM_END_REC : OPSIZE_MEM_END);
                }
                else if (node.hasStatus(NODE_ST_RECURSION)) {
                    len = OPSIZE_MEM_START_PUSH;
                    len += tlen + (MEM_STATUS_AT0(reg.pushMemEnd, node.regnum) ? OPSIZE_MEM_END_PUSH_REC : OPSIZE_MEM_END_REC);
                }
                else {
                    if (MEM_STATUS_AT0(reg.pushMemStart, node.regnum))
                        len = OPSIZE_MEM_START_PUSH;
                    else
                        len = OPSIZE_MEM_START;
                    len += tlen + (MEM_STATUS_AT0(reg.pushMemEnd, node.regnum) ? OPSIZE_MEM_END_PUSH : OPSIZE_MEM_END);
                }

            case BAG_STOP_BACKTRACK:
                if (node.hasStatus(NODE_ST_STRICT_REAL_REPEAT)) {
                    var qn = node.body;
                    tlen = compileLengthTree(qn.body, reg);
                    if (tlen < 0) return tlen;
                    var v = onigPositiveIntMultiply(qn.lower, tlen);
                    if (v < 0) return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
                    len = v + OPSIZE_PUSH + tlen + OPSIZE_POP + OPSIZE_JUMP;
                }
                else {
                    len = OPSIZE_MARK + tlen + OPSIZE_CUT_TO_MARK;
                }

            case BAG_IF_ELSE:
                var cond = node.body;
                var Then = node.Then;
                var Else = node.Else;
                len = compileLengthTree(cond, reg);
                if (len < 0) return len;
                len += OPSIZE_PUSH + OPSIZE_MARK + OPSIZE_CUT_TO_MARK;
                if (Then != null) {
                    tlen = compileLengthTree(Then, reg);
                    if (tlen < 0) return tlen;
                    len += tlen;
                }
                len += OPSIZE_JUMP + OPSIZE_CUT_TO_MARK;
                if (Else != null) {
                    tlen = compileLengthTree(Else, reg);
                    if (tlen < 0) return tlen;
                    len += tlen;
                }

            case BAG_OPTION:
                len = 0;
        }
        return len;
    }

    static function compileBagMemoryNode(node:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        if (node.hasStatus(NODE_ST_CALLED)) {
            var len:Int;
            r = addOp(reg, OP_CALL);
            if (r != 0) return r;

            node.calledAddr = COP_CURR_OFFSET(reg) + 1 + OPSIZE_JUMP;
            node.addStatus(NODE_ST_FIXED_ADDR);
            COP(reg).addr = node.calledAddr;

            if (node.regnum == 0) {
                len = compileLengthTree(node.body, reg);
                len += OPSIZE_RETURN;

                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = len + SIZE_INC;

                r = compileTree(node.body, reg, env);
                if (r != 0) return r;

                r = addOp(reg, OP_RETURN);
                return r;
            }
            else {
                len = compileLengthTree(node.body, reg);
                len += (OPSIZE_MEM_START_PUSH + OPSIZE_RETURN);
                if (MEM_STATUS_AT0(reg.pushMemEnd, node.regnum))
                    len += (node.hasStatus(NODE_ST_RECURSION) ? OPSIZE_MEM_END_PUSH_REC : OPSIZE_MEM_END_PUSH);
                else
                    len += (node.hasStatus(NODE_ST_RECURSION) ? OPSIZE_MEM_END_REC : OPSIZE_MEM_END);

                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = len + SIZE_INC;
            }
        }

        if (MEM_STATUS_AT0(reg.pushMemStart, node.regnum))
            r = addOp(reg, OP_MEM_START_PUSH);
        else
            r = addOp(reg, OP_MEM_START);
        if (r != 0) return r;
        COP(reg).num = node.regnum;

        r = compileTree(node.body, reg, env);
        if (r != 0) return r;

        if (MEM_STATUS_AT0(reg.pushMemEnd, node.regnum))
            r = addOp(reg, (node.hasStatus(NODE_ST_RECURSION) ? OP_MEM_END_PUSH_REC : OP_MEM_END_PUSH));
        else
            r = addOp(reg, (node.hasStatus(NODE_ST_RECURSION) ? OP_MEM_END_REC : OP_MEM_END));
        if (r != 0) return r;
        COP(reg).num = node.regnum;

        if (node.hasStatus(NODE_ST_CALLED)) {
            r = addOp(reg, OP_RETURN);
        }
        return r;
    }

    static function compileBagNode(node:Node, reg:Regex, env:ParseEnv):Int {
        var r = 0;
        var len:Int;
        switch (node.type) {
            case BAG_MEMORY:
                r = compileBagMemoryNode(node, reg, env);

            case BAG_OPTION:
                r = compileOptionNode(node, reg, env);

            case BAG_STOP_BACKTRACK:
                if (node.hasStatus(NODE_ST_STRICT_REAL_REPEAT)) {
                    var qn = node.body;
                    r = compileTreeNTimes(qn.body, qn.lower, reg, env);
                    if (r != 0) return r;

                    len = compileLengthTree(qn.body, reg);
                    if (len < 0) return len;

                    r = addOp(reg, OP_PUSH);
                    if (r != 0) return r;
                    COP(reg).addr = SIZE_INC + len + OPSIZE_POP + OPSIZE_JUMP;

                    r = compileTree(qn.body, reg, env);
                    if (r != 0) return r;
                    r = addOp(reg, OP_POP);
                    if (r != 0) return r;

                    r = addOp(reg, OP_JUMP);
                    if (r != 0) return r;
                    COP(reg).addr = -(OPSIZE_PUSH + len + OPSIZE_POP);
                }
                else {
                    var mid = env.idNum++;
                    r = addOp(reg, OP_MARK);
                    if (r != 0) return r;
                    COP(reg).id = mid;
                    COP(reg).flagv = 0;

                    r = compileTree(node.body, reg, env);
                    if (r != 0) return r;
                    r = addOp(reg, OP_CUT_TO_MARK);
                    if (r != 0) return r;
                    COP(reg).id = mid;
                    COP(reg).flagv = 0;
                }

            case BAG_IF_ELSE:
                var condLen:Int, thenLen:Int, elseLen:Int, jumpLen:Int;
                var cond = node.body;
                var Then = node.Then;
                var Else = node.Else;

                var mid = env.idNum++;

                r = addOp(reg, OP_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 0;

                condLen = compileLengthTree(cond, reg);
                if (condLen < 0) return condLen;
                if (Then != null) {
                    thenLen = compileLengthTree(Then, reg);
                    if (thenLen < 0) return thenLen;
                }
                else
                    thenLen = 0;

                jumpLen = condLen + thenLen + OPSIZE_CUT_TO_MARK + OPSIZE_JUMP;

                r = addOp(reg, OP_PUSH);
                if (r != 0) return r;
                COP(reg).addr = SIZE_INC + jumpLen;

                r = compileTree(cond, reg, env);
                if (r != 0) return r;
                r = addOp(reg, OP_CUT_TO_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 0;

                if (Then != null) {
                    r = compileTree(Then, reg, env);
                    if (r != 0) return r;
                }

                if (Else != null) {
                    elseLen = compileLengthTree(Else, reg);
                    if (elseLen < 0) return elseLen;
                }
                else
                    elseLen = 0;

                r = addOp(reg, OP_JUMP);
                if (r != 0) return r;
                COP(reg).addr = OPSIZE_CUT_TO_MARK + elseLen + SIZE_INC;

                r = addOp(reg, OP_CUT_TO_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 0;

                if (Else != null) {
                    r = compileTree(Else, reg, env);
                }
        }
        return r;
    }

    static function compileLengthAnchorNode(node:Node, reg:Regex):Int {
        var len:Int;
        var tlen = 0;

        if (node.body != null) {
            tlen = compileLengthTree(node.body, reg);
            if (tlen < 0) return tlen;
        }

        switch (node.type) {
            case ANCR_PREC_READ:
                len = OPSIZE_MARK + tlen + OPSIZE_CUT_TO_MARK;
            case ANCR_PREC_READ_NOT:
                len = OPSIZE_PUSH + OPSIZE_MARK + tlen + OPSIZE_POP_TO_MARK + OPSIZE_POP + OPSIZE_FAIL;
            case ANCR_LOOK_BEHIND:
                if (node.charMinLen == node.charMaxLen)
                    len = OPSIZE_MARK + OPSIZE_STEP_BACK_START + tlen + OPSIZE_CUT_TO_MARK;
                else {
                    len = OPSIZE_SAVE_VAL + OPSIZE_UPDATE_VAR + OPSIZE_MARK + OPSIZE_PUSH + OPSIZE_UPDATE_VAR + OPSIZE_FAIL
                        + OPSIZE_JUMP + OPSIZE_STEP_BACK_START + OPSIZE_STEP_BACK_NEXT + tlen + OPSIZE_CHECK_POSITION
                        + OPSIZE_CUT_TO_MARK + OPSIZE_UPDATE_VAR;
                    if (node.leadNode != null) {
                        var llen = compileLengthTree(node.leadNode, reg);
                        if (llen < 0) return llen;
                        len += OPSIZE_MOVE + llen;
                    }
                }
            case ANCR_LOOK_BEHIND_NOT:
                if (node.charMinLen == node.charMaxLen)
                    len = OPSIZE_MARK + OPSIZE_PUSH + OPSIZE_STEP_BACK_START + tlen + OPSIZE_POP_TO_MARK + OPSIZE_FAIL + OPSIZE_POP;
                else {
                    len = OPSIZE_SAVE_VAL + OPSIZE_UPDATE_VAR + OPSIZE_MARK + OPSIZE_PUSH + OPSIZE_STEP_BACK_START
                        + OPSIZE_STEP_BACK_NEXT + tlen + OPSIZE_CHECK_POSITION + OPSIZE_POP_TO_MARK + OPSIZE_UPDATE_VAR
                        + OPSIZE_POP + OPSIZE_FAIL + OPSIZE_UPDATE_VAR + OPSIZE_POP + OPSIZE_POP;
                    if (node.leadNode != null) {
                        var llen = compileLengthTree(node.leadNode, reg);
                        if (llen < 0) return llen;
                        len += OPSIZE_MOVE + llen;
                    }
                }
            case ANCR_WORD_BOUNDARY, ANCR_NO_WORD_BOUNDARY, ANCR_WORD_BEGIN, ANCR_WORD_END:
                len = OPSIZE_WORD_BOUNDARY;
            case ANCR_TEXT_SEGMENT_BOUNDARY, ANCR_NO_TEXT_SEGMENT_BOUNDARY:
                len = SIZE_OPCODE;
            default:
                len = SIZE_OPCODE;
        }
        return len;
    }

    static function compileAnchorLookBehindNode(node:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        if (node.charMinLen == node.charMaxLen) {
            var mid = env.idNum++;
            r = addOp(reg, OP_MARK);
            if (r != 0) return r;
            COP(reg).id = mid;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_STEP_BACK_START);
            if (r != 0) return r;
            COP(reg).initial = node.charMinLen;
            COP(reg).remaining = 0;
            COP(reg).addr = 1;

            r = compileTree(node.body, reg, env);
            if (r != 0) return r;

            r = addOp(reg, OP_CUT_TO_MARK);
            if (r != 0) return r;
            COP(reg).id = mid;
            COP(reg).flagv = 0;
        }
        else {
            var diff:Int;
            if (node.leadNode != null) {
                var ci = new MinMaxCharLen();
                r = nodeCharLen(node.leadNode, reg, ci, env);
                if (r < 0) return r;
                r = addOp(reg, OP_MOVE);
                if (r != 0) return r;
                COP(reg).moveN = -ci.min;
                r = compileTree(node.leadNode, reg, env);
                if (r != 0) return r;
            }

            var mid1 = env.idNum++;
            r = addOp(reg, OP_SAVE_VAL);
            if (r != 0) return r;
            COP(reg).type = SAVE_RIGHT_RANGE;
            COP(reg).id = mid1;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_TO_S;

            var mid2 = env.idNum++;
            r = addOp(reg, OP_MARK);
            if (r != 0) return r;
            COP(reg).id = mid2;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_PUSH);
            if (r != 0) return r;
            COP(reg).addr = SIZE_INC + OPSIZE_JUMP;

            r = addOp(reg, OP_JUMP);
            if (r != 0) return r;
            COP(reg).addr = SIZE_INC + OPSIZE_UPDATE_VAR + OPSIZE_FAIL;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_FROM_STACK;
            COP(reg).id = mid1;
            COP(reg).flagv = 0;
            r = addOp(reg, OP_FAIL);
            if (r != 0) return r;

            r = addOp(reg, OP_STEP_BACK_START);
            if (r != 0) return r;

            if (node.charMaxLen != INFINITE_LEN)
                diff = node.charMaxLen - node.charMinLen;
            else
                diff = INFINITE_LEN;

            COP(reg).initial = node.charMinLen;
            COP(reg).remaining = diff;
            COP(reg).addr = 2;

            r = addOp(reg, OP_STEP_BACK_NEXT);
            if (r != 0) return r;

            r = compileTree(node.body, reg, env);
            if (r != 0) return r;

            r = addOp(reg, OP_CHECK_POSITION);
            if (r != 0) return r;
            COP(reg).type = CHECK_POSITION_CURRENT_RIGHT_RANGE;

            r = addOp(reg, OP_CUT_TO_MARK);
            if (r != 0) return r;
            COP(reg).id = mid2;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_FROM_STACK;
            COP(reg).id = mid1;
            COP(reg).flagv = 1;
        }
        return r;
    }

    static function compileAnchorLookBehindNotNode(node:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        var len = compileLengthTree(node.body, reg);

        if (node.charMinLen == node.charMaxLen) {
            var mid = env.idNum++;
            r = addOp(reg, OP_MARK);
            if (r != 0) return r;
            COP(reg).id = mid;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_PUSH);
            if (r != 0) return r;
            COP(reg).addr = SIZE_INC + OPSIZE_STEP_BACK_START + len + OPSIZE_POP_TO_MARK + OPSIZE_FAIL;

            r = addOp(reg, OP_STEP_BACK_START);
            if (r != 0) return r;
            COP(reg).initial = node.charMinLen;
            COP(reg).remaining = 0;
            COP(reg).addr = 1;

            r = compileTree(node.body, reg, env);
            if (r != 0) return r;

            r = addOp(reg, OP_POP_TO_MARK);
            if (r != 0) return r;
            COP(reg).id = mid;
            r = addOp(reg, OP_FAIL);
            if (r != 0) return r;
            r = addOp(reg, OP_POP);
        }
        else {
            var diff:Int;
            var mid1 = env.idNum++;
            r = addOp(reg, OP_SAVE_VAL);
            if (r != 0) return r;
            COP(reg).type = SAVE_RIGHT_RANGE;
            COP(reg).id = mid1;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_TO_S;

            var mid2 = env.idNum++;
            r = addOp(reg, OP_MARK);
            if (r != 0) return r;
            COP(reg).id = mid2;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_PUSH);
            if (r != 0) return r;
            COP(reg).addr = SIZE_INC + OPSIZE_STEP_BACK_START + OPSIZE_STEP_BACK_NEXT + len + OPSIZE_CHECK_POSITION
                + OPSIZE_POP_TO_MARK + OPSIZE_UPDATE_VAR + OPSIZE_POP + OPSIZE_FAIL;

            if (node.leadNode != null) {
                var ci = new MinMaxCharLen();
                var clen = compileLengthTree(node.leadNode, reg);
                COP(reg).addr += OPSIZE_MOVE + clen;

                r = nodeCharLen(node.leadNode, reg, ci, env);
                if (r < 0) return r;
                r = addOp(reg, OP_MOVE);
                if (r != 0) return r;
                COP(reg).moveN = -ci.min;

                r = compileTree(node.leadNode, reg, env);
                if (r != 0) return r;
            }

            r = addOp(reg, OP_STEP_BACK_START);
            if (r != 0) return r;

            if (node.charMaxLen != INFINITE_LEN)
                diff = node.charMaxLen - node.charMinLen;
            else
                diff = INFINITE_LEN;

            COP(reg).initial = node.charMinLen;
            COP(reg).remaining = diff;
            COP(reg).addr = 2;

            r = addOp(reg, OP_STEP_BACK_NEXT);
            if (r != 0) return r;

            r = compileTree(node.body, reg, env);
            if (r != 0) return r;

            r = addOp(reg, OP_CHECK_POSITION);
            if (r != 0) return r;
            COP(reg).type = CHECK_POSITION_CURRENT_RIGHT_RANGE;

            r = addOp(reg, OP_POP_TO_MARK);
            if (r != 0) return r;
            COP(reg).id = mid2;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_FROM_STACK;
            COP(reg).id = mid1;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_POP); /* pop save val */
            if (r != 0) return r;
            r = addOp(reg, OP_FAIL);
            if (r != 0) return r;

            r = addOp(reg, OP_UPDATE_VAR);
            if (r != 0) return r;
            COP(reg).type = UPDATE_VAR_RIGHT_RANGE_FROM_STACK;
            COP(reg).id = mid1;
            COP(reg).flagv = 0;

            r = addOp(reg, OP_POP); /* pop mark */
            if (r != 0) return r;
            r = addOp(reg, OP_POP); /* pop save val */
        }
        return r;
    }

    static function compileAnchorNode(node:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        var len:Int;
        var op = 0;
        var word = false;

        switch (node.type) {
            case ANCR_BEGIN_BUF: r = addOp(reg, OP_BEGIN_BUF);
            case ANCR_END_BUF: r = addOp(reg, OP_END_BUF);
            case ANCR_BEGIN_LINE: r = addOp(reg, OP_BEGIN_LINE);
            case ANCR_END_LINE: r = addOp(reg, OP_END_LINE);
            case ANCR_SEMI_END_BUF: r = addOp(reg, OP_SEMI_END_BUF);
            case ANCR_BEGIN_POSITION:
                r = addOp(reg, OP_CHECK_POSITION);
                if (r != 0) return r;
                COP(reg).type = CHECK_POSITION_SEARCH_START;

            case ANCR_WORD_BOUNDARY:
                op = OP_WORD_BOUNDARY; word = true; r = 0;
            case ANCR_NO_WORD_BOUNDARY:
                op = OP_NO_WORD_BOUNDARY; word = true; r = 0;
            case ANCR_WORD_BEGIN:
                op = OP_WORD_BEGIN; word = true; r = 0;
            case ANCR_WORD_END:
                op = OP_WORD_END; word = true; r = 0;

            case ANCR_TEXT_SEGMENT_BOUNDARY, ANCR_NO_TEXT_SEGMENT_BOUNDARY:
                r = addOp(reg, OP_TEXT_SEGMENT_BOUNDARY);
                if (r != 0) return r;
                var type = EXTENDED_GRAPHEME_CLUSTER_BOUNDARY;
                if (node.hasStatus(NODE_ST_TEXT_SEGMENT_WORD))
                    type = WORD_BOUNDARY;
                COP(reg).type = type;
                COP(reg).not = (node.type == ANCR_NO_TEXT_SEGMENT_BOUNDARY ? 1 : 0);

            case ANCR_PREC_READ:
                var mid = env.idNum++;
                r = addOp(reg, OP_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 1;

                r = compileTree(node.body, reg, env);
                if (r != 0) return r;

                r = addOp(reg, OP_CUT_TO_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 1;

            case ANCR_PREC_READ_NOT:
                len = compileLengthTree(node.body, reg);
                if (len < 0) return len;

                var mid = env.idNum++;
                r = addOp(reg, OP_PUSH);
                if (r != 0) return r;
                COP(reg).addr = SIZE_INC + OPSIZE_MARK + len + OPSIZE_POP_TO_MARK + OPSIZE_POP + OPSIZE_FAIL;

                r = addOp(reg, OP_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;
                COP(reg).flagv = 0;

                r = compileTree(node.body, reg, env);
                if (r != 0) return r;

                r = addOp(reg, OP_POP_TO_MARK);
                if (r != 0) return r;
                COP(reg).id = mid;

                r = addOp(reg, OP_POP);
                if (r != 0) return r;
                r = addOp(reg, OP_FAIL);

            case ANCR_LOOK_BEHIND:
                r = compileAnchorLookBehindNode(node, reg, env);

            case ANCR_LOOK_BEHIND_NOT:
                r = compileAnchorLookBehindNotNode(node, reg, env);

            default:
                return ONIGERR_TYPE_BUG;
        }

        if (word) {
            r = addOp(reg, op);
            if (r != 0) return r;
            COP(reg).mode = node.asciiMode;
        }
        return r;
    }

    static function compileGimmickNode(node:Node, reg:Regex):Int {
        var r = 0;
        switch (node.type) {
            case GIMMICK_FAIL:
                r = addOp(reg, OP_FAIL);
            case GIMMICK_SAVE:
                r = addOp(reg, OP_SAVE_VAL);
                if (r != 0) return r;
                COP(reg).type = node.detailType;
                COP(reg).id = node.id;
            case GIMMICK_UPDATE_VAR:
                r = addOp(reg, OP_UPDATE_VAR);
                if (r != 0) return r;
                COP(reg).type = node.detailType;
                COP(reg).id = node.id;
                COP(reg).flagv = 0;
            case GIMMICK_CALLOUT:
                switch (node.detailType) {
                    case ONIG_CALLOUT_OF_CONTENTS, ONIG_CALLOUT_OF_NAME:
                        if (node.detailType == ONIG_CALLOUT_OF_NAME) {
                            r = addOp(reg, OP_CALLOUT_NAME);
                            if (r != 0) return r;
                            COP(reg).id = node.id;
                            COP(reg).num = node.num;
                        }
                        else {
                            r = addOp(reg, OP_CALLOUT_CONTENTS);
                            if (r != 0) return r;
                            COP(reg).num = node.num;
                        }
                    default:
                        r = ONIGERR_TYPE_BUG;
                }
        }
        return r;
    }

    static function compileLengthGimmickNode(node:Node, reg:Regex):Int {
        var len = 0;
        switch (node.type) {
            case GIMMICK_FAIL: len = OPSIZE_FAIL;
            case GIMMICK_SAVE: len = OPSIZE_SAVE_VAL;
            case GIMMICK_UPDATE_VAR: len = OPSIZE_UPDATE_VAR;
            case GIMMICK_CALLOUT:
                switch (node.detailType) {
                    case ONIG_CALLOUT_OF_CONTENTS: len = OPSIZE_CALLOUT_CONTENTS;
                    case ONIG_CALLOUT_OF_NAME: len = OPSIZE_CALLOUT_NAME;
                    default: len = ONIGERR_TYPE_BUG;
                }
        }
        return len;
    }

    static function compileLengthTree(node:Node, reg:Regex):Int {
        var len:Int;
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST:
                len = 0;
                do {
                    r = compileLengthTree(node.car, reg);
                    if (r < 0) return r;
                    len += r;
                } while ((node = node.cdr) != null);
                r = len;
            case NODE_ALT:
                var n = 0;
                r = 0;
                do {
                    r += compileLengthTree(node.car, reg);
                    n++;
                } while ((node = node.cdr) != null);
                r += (OPSIZE_PUSH + OPSIZE_JUMP) * (n - 1);
            case NODE_STRING:
                if (node.isStrCrude())
                    r = compileLengthStringCrudeNode(node, reg);
                else
                    r = compileLengthStringNode(node, reg);
            case NODE_CCLASS:
                r = compileLengthCclassNode(node, reg);
            case NODE_CTYPE:
                r = SIZE_OPCODE;
            case NODE_BACKREF:
                r = OPSIZE_BACKREF;
            case NODE_CALL:
                r = OPSIZE_CALL;
            case NODE_QUANT:
                r = compileLengthQuantifierNode(node, reg);
            case NODE_BAG:
                r = compileLengthBagNode(node, reg);
            case NODE_ANCHOR:
                r = compileLengthAnchorNode(node, reg);
            case NODE_GIMMICK:
                r = compileLengthGimmickNode(node, reg);
            default:
                return ONIGERR_TYPE_BUG;
        }
        return r;
    }

    static function compileTree(node:Node, reg:Regex, env:ParseEnv):Int {
        var r = 0;
        var len:Int;
        switch (node.nodeType) {
            case NODE_LIST:
                do {
                    r = compileTree(node.car, reg, env);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_ALT:
                var x = node;
                len = 0;
                do {
                    len += compileLengthTree(x.car, reg);
                    if (x.cdr != null) {
                        len += OPSIZE_PUSH + OPSIZE_JUMP;
                    }
                } while ((x = x.cdr) != null);
                var pos = COP_CURR_OFFSET(reg) + 1 + len; /* goal position */

                do {
                    len = compileLengthTree(node.car, reg);
                    if (node.cdr != null) {
                        var push = node.hasStatus(NODE_ST_SUPER) ? OP_PUSH_SUPER : OP_PUSH;
                        r = addOp(reg, push);
                        if (r != 0) break;
                        COP(reg).addr = SIZE_INC + len + OPSIZE_JUMP;
                    }
                    r = compileTree(node.car, reg, env);
                    if (r != 0) break;
                    if (node.cdr != null) {
                        len = pos - (COP_CURR_OFFSET(reg) + 1);
                        r = addOp(reg, OP_JUMP);
                        if (r != 0) break;
                        COP(reg).addr = len;
                    }
                } while ((node = node.cdr) != null);

            case NODE_STRING:
                if (node.isStrCrude())
                    r = compileStringCrudeNode(node, reg);
                else
                    r = compileStringNode(node, reg);

            case NODE_CCLASS:
                r = compileCclassNode(node, reg);

            case NODE_CTYPE:
                var op:Int;
                switch (node.ctype) {
                    case CTYPE_ANYCHAR:
                        r = addOp(reg, node.hasStatus(NODE_ST_MULTILINE) ? OP_ANYCHAR_ML : OP_ANYCHAR);
                    case ONIGENC_CTYPE_WORD:
                        if (node.asciiMode == 0) {
                            op = node.not != 0 ? OP_NO_WORD : OP_WORD;
                        }
                        else {
                            op = node.not != 0 ? OP_NO_WORD_ASCII : OP_WORD_ASCII;
                        }
                        r = addOp(reg, op);
                    default:
                        return ONIGERR_TYPE_BUG;
                }

            case NODE_BACKREF:
                var br = node;
                var addMems = false;
                if (node.hasStatus(NODE_ST_CHECKER)) {
                    if (node.hasStatus(NODE_ST_NEST_LEVEL)) {
                        r = addOp(reg, OP_BACKREF_CHECK_WITH_LEVEL);
                        if (r != 0) return r;
                        COP(reg).nestLevel = br.nestLevel;
                    }
                    else {
                        r = addOp(reg, OP_BACKREF_CHECK);
                        if (r != 0) return r;
                    }
                    addMems = true;
                }
                else {
                    if (node.hasStatus(NODE_ST_NEST_LEVEL)) {
                        if (node.hasStatus(NODE_ST_IGNORECASE))
                            r = addOp(reg, OP_BACKREF_WITH_LEVEL_IC);
                        else
                            r = addOp(reg, OP_BACKREF_WITH_LEVEL);
                        if (r != 0) return r;
                        COP(reg).nestLevel = br.nestLevel;
                        addMems = true;
                    }
                    else if (br.backNum == 1) {
                        var n = br.backs[0];
                        if (node.hasStatus(NODE_ST_IGNORECASE)) {
                            r = addOp(reg, OP_BACKREF_N_IC);
                            if (r != 0) return r;
                            COP(reg).n1 = n;
                        }
                        else {
                            switch (n) {
                                case 1: r = addOp(reg, OP_BACKREF1);
                                case 2: r = addOp(reg, OP_BACKREF2);
                                default:
                                    r = addOp(reg, OP_BACKREF_N);
                                    if (r != 0) return r;
                                    COP(reg).n1 = n;
                            }
                        }
                    }
                    else {
                        r = addOp(reg, node.hasStatus(NODE_ST_IGNORECASE) ? OP_BACKREF_MULTI_IC : OP_BACKREF_MULTI);
                        if (r != 0) return r;
                        addMems = true;
                    }
                }
                if (addMems) {
                    // add_bacref_mems:
                    var num = br.backNum;
                    COP(reg).num = num;
                    if (num == 1) {
                        COP(reg).n1 = br.backs[0];
                        COP(reg).ns = [br.backs[0]];
                    }
                    else {
                        var ns = new Array<Int>();
                        var p = br.backs;
                        var i = num - 1;
                        while (i >= 0) {
                            ns.push(p[i]);
                            i--;
                        }
                        COP(reg).ns = ns;
                    }
                }

            case NODE_CALL:
                r = compileCall(node, reg, env);

            case NODE_QUANT:
                r = compileQuantifierNode(node, reg, env);

            case NODE_BAG:
                r = compileBagNode(node, reg, env);

            case NODE_ANCHOR:
                r = compileAnchorNode(node, reg, env);

            case NODE_GIMMICK:
                r = compileGimmickNode(node, reg);

            default:
        }
        return r;
    }

    /**
     * Unsigned 32 bit addition of two OnigLen values (INFINITE_LEN stands for
     * 0xffffffff), for the few places where upstream adds lengths without
     * distance_add.
     */
    static function rawLenAdd(a:Int, b:Int):Int {
        var fa:Float = a == INFINITE_LEN ? 4294967295.0 : a;
        var fb:Float = b == INFINITE_LEN ? 4294967295.0 : b;
        var s = fa + fb;
        if (s >= 4294967296.0) s -= 4294967296.0;
        if (s >= 2147483647.0) return INFINITE_LEN;
        return Std.int(s);
    }

    // slot helpers (Node** of the C code)
    static inline var SLOT_REF:Int = 0;
    static inline var SLOT_BODY:Int = 1;
    static inline var SLOT_THEN:Int = 2;
    static inline var SLOT_ELSE:Int = 3;

    static function slotGet(ref:NodeRef, holder:Node, kind:Int):Node {
        return switch (kind) {
            case SLOT_REF: ref.v;
            case SLOT_BODY: holder.body;
            case SLOT_THEN: holder.Then;
            default: holder.Else;
        }
    }

    static function slotSet(ref:NodeRef, holder:Node, kind:Int, n:Node):Void {
        switch (kind) {
            case SLOT_REF: ref.v = n;
            case SLOT_BODY: holder.body = n;
            case SLOT_THEN: holder.Then = n;
            default: holder.Else = n;
        }
    }

    static function makeNamedCaptureNumberMap(ref:NodeRef, holder:Node, kind:Int, map:Array<Int>, counter:IntRef):Int {
        var r:Int;
        var node = slotGet(ref, holder, kind);

        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = makeNamedCaptureNumberMap(null, node, SLOT_BODY, map, counter);
                } while (r >= 0 && (node = node.cdr) != null);
                if (r < 0) return r;

            case NODE_QUANT:
                r = makeNamedCaptureNumberMap(null, node, SLOT_BODY, map, counter);
                if (r < 0) return r;
                if (r == 1 && node.body.nodeType == NODE_QUANT) {
                    return Regparse.onigReduceNestedQuantifier(node);
                }

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_NAMED_GROUP)) {
                        counter.v++;
                        map[en.regnum] = counter.v;
                        en.regnum = counter.v;
                        r = makeNamedCaptureNumberMap(null, node, SLOT_BODY, map, counter);
                        if (r < 0) return r;
                    }
                    else {
                        slotSet(ref, holder, kind, node.body);
                        node.body = null;
                        r = makeNamedCaptureNumberMap(ref, holder, kind, map, counter);
                        if (r < 0) return r;
                        return 1;
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    r = makeNamedCaptureNumberMap(null, en, SLOT_BODY, map, counter);
                    if (r < 0) return r;
                    if (en.Then != null) {
                        r = makeNamedCaptureNumberMap(null, en, SLOT_THEN, map, counter);
                        if (r < 0) return r;
                    }
                    if (en.Else != null) {
                        r = makeNamedCaptureNumberMap(null, en, SLOT_ELSE, map, counter);
                        if (r < 0) return r;
                    }
                }
                else {
                    r = makeNamedCaptureNumberMap(null, node, SLOT_BODY, map, counter);
                    if (r < 0) return r;
                }

            case NODE_ANCHOR:
                if (node.body != null) {
                    r = makeNamedCaptureNumberMap(null, node, SLOT_BODY, map, counter);
                    if (r < 0) return r;
                }

            default:
        }
        return 0;
    }

    static function renumberBackrefNode(node:Node, map:Array<Int>):Int {
        var bn = node;
        if (!node.hasStatus(NODE_ST_BY_NAME))
            return ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED;
        var oldNum = bn.backNum;
        var backs = bn.backs;
        var pos = 0;
        for (i in 0...oldNum) {
            var n = map[backs[i]];
            if (n > 0) {
                backs[pos] = n;
                pos++;
            }
        }
        bn.backNum = pos;
        return 0;
    }

    static function renumberBackrefTraverse(node:Node, map:Array<Int>):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = renumberBackrefTraverse(node.car, map);
                } while (r == 0 && (node = node.cdr) != null);
            case NODE_QUANT:
                r = renumberBackrefTraverse(node.body, map);
            case NODE_BAG:
                var en = node;
                r = renumberBackrefTraverse(node.body, map);
                if (r != 0) return r;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = renumberBackrefTraverse(en.Then, map);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = renumberBackrefTraverse(en.Else, map);
                        if (r != 0) return r;
                    }
                }
            case NODE_BACKREF:
                r = renumberBackrefNode(node, map);
            case NODE_ANCHOR:
                if (node.body != null)
                    r = renumberBackrefTraverse(node.body, map);
            default:
        }
        return r;
    }

    static function numberedRefCheck(node:Node):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = numberedRefCheck(node.car);
                } while (r == 0 && (node = node.cdr) != null);
            case NODE_ANCHOR, NODE_QUANT:
                if (node.nodeType == NODE_ANCHOR && node.body == null) {
                }
                else
                    r = numberedRefCheck(node.body);
            case NODE_BAG:
                var en = node;
                r = numberedRefCheck(node.body);
                if (r != 0) return r;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = numberedRefCheck(en.Then);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = numberedRefCheck(en.Else);
                        if (r != 0) return r;
                    }
                }
            case NODE_BACKREF:
                if (!node.hasStatus(NODE_ST_BY_NAME))
                    return ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED;
            default:
        }
        return r;
    }

    static function disableNonameGroupCapture(root:NodeRef, reg:Regex, env:ParseEnv):Int {
        var map = [for (i in 0...(env.numMem + 1)) 0];
        var counter = new IntRef(0);
        var r = makeNamedCaptureNumberMap(root, null, SLOT_REF, map, counter);
        if (r < 0) return r;

        r = renumberBackrefTraverse(root.v, map);
        if (r != 0) return r;

        var pos = 1;
        for (i in 1...(env.numMem + 1)) {
            if (map[i] > 0) {
                var m = new MemEnv();
                m.memNode = env.memEnv[i].memNode;
                m.emptyRepeatNode = env.memEnv[i].emptyRepeatNode;
                env.memEnv[pos] = m;
                pos++;
            }
        }

        var loc = env.capHistory;
        env.capHistory = 0;
        for (i in 1...(ONIG_MAX_CAPTURE_HISTORY_GROUP + 1)) {
            if (MEM_STATUS_AT(loc, i)) {
                env.capHistory = MEM_STATUS_ON_SIMPLE(env.capHistory, map[i]);
            }
        }

        env.numMem = env.numNamed;
        reg.numMem = env.numNamed;

        return Regparse.onigRenumberNameTable(reg, map);
    }

    static function fixUnsetAddrList(uslist:Array<UnsetAddr>, reg:Regex):Int {
        for (us in uslist) {
            if (!us.target.hasStatus(NODE_ST_FIXED_ADDR)) {
                if (us.target.hasStatus(NODE_ST_CALLED))
                    return ONIGERR_PARSER_BUG;
                else {
                    /* CASE: called node doesn't have called address. */
                    continue;
                }
            }
            var en = us.target;
            reg.ops[us.offset].addr = en.calledAddr;
        }
        return 0;
    }

    /* x is not included y ==>  1 : 0 */
    static function isExclusive(x:Node, y:Node, reg:Regex):Bool {
        while (true) { // retry:
            var ytype = y.nodeType;
            switch (x.nodeType) {
                case NODE_CTYPE:
                    if (x.ctype == CTYPE_ANYCHAR || y.ctype == CTYPE_ANYCHAR)
                        return false;
                    switch (ytype) {
                        case NODE_CTYPE:
                            if (y.ctype == x.ctype && y.not != x.not && y.asciiMode == x.asciiMode)
                                return true;
                            else
                                return false;
                        case NODE_CCLASS, NODE_STRING:
                            var tmp = x; x = y; y = tmp;
                            continue;
                        default:
                    }

                case NODE_CCLASS:
                    var xc = x;
                    switch (ytype) {
                        case NODE_CTYPE:
                            switch (y.ctype) {
                                case CTYPE_ANYCHAR:
                                    return false;
                                case ONIGENC_CTYPE_WORD:
                                    if (y.not == 0) {
                                        if (xc.mbuf == null && !xc.isNcclassNot()) {
                                            var range = y.asciiMode != 0 ? 128 : SINGLE_BYTE_SIZE;
                                            for (i in 0...range) {
                                                if (BITSET_AT(xc.bs, i)) {
                                                    if (isCodeWord(i)) return false;
                                                }
                                            }
                                            return true;
                                        }
                                        return false;
                                    }
                                    else {
                                        if (xc.mbuf != null) return false;
                                        if (xc.isNcclassNot()) return false;
                                        var range = y.asciiMode != 0 ? 128 : SINGLE_BYTE_SIZE;
                                        for (i in 0...range) {
                                            if (!isCodeWord(i)) {
                                                if (BITSET_AT(xc.bs, i))
                                                    return false;
                                            }
                                        }
                                        for (i in range...SINGLE_BYTE_SIZE) {
                                            if (BITSET_AT(xc.bs, i)) return false;
                                        }
                                        return true;
                                    }
                                default:
                            }

                        case NODE_CCLASS:
                            var yc = y;
                            for (i in 0...SINGLE_BYTE_SIZE) {
                                var v = BITSET_AT(xc.bs, i);
                                if ((v && !xc.isNcclassNot()) || (!v && xc.isNcclassNot())) {
                                    v = BITSET_AT(yc.bs, i);
                                    if ((v && !yc.isNcclassNot()) || (!v && yc.isNcclassNot()))
                                        return false;
                                }
                            }
                            if ((xc.mbuf == null && !xc.isNcclassNot()) || (yc.mbuf == null && !yc.isNcclassNot()))
                                return true;
                            return false;

                        case NODE_STRING:
                            var tmp = x; x = y; y = tmp;
                            continue;

                        default:
                    }

                case NODE_STRING:
                    var xs = x;
                    if (x.strLen() == 0)
                        return false;
                    switch (ytype) {
                        case NODE_CTYPE:
                            switch (y.ctype) {
                                case CTYPE_ANYCHAR:
                                case ONIGENC_CTYPE_WORD:
                                    if (y.asciiMode == 0) {
                                        if (isMbcWord(xs.sbuf, xs.s, xs.end))
                                            return y.not != 0;
                                        else
                                            return y.not == 0;
                                    }
                                    else {
                                        if (isMbcWordAscii(xs.sbuf, xs.s, xs.end))
                                            return y.not != 0;
                                        else
                                            return y.not == 0;
                                    }
                                default:
                            }

                        case NODE_CCLASS:
                            var cc = y;
                            var code = mbcToCode(xs.sbuf, xs.s, xs.s + ONIGENC_MBC_MAXLEN);
                            return !Regparse.onigIsCodeInCc(code, cc);

                        case NODE_STRING:
                            var ys = y;
                            var len = x.strLen();
                            if (len > y.strLen()) len = y.strLen();
                            var p = ys.s;
                            var q = xs.s;
                            for (i in 0...len) {
                                if (ys.sbuf.get(p) != xs.sbuf.get(q)) return true;
                                p++;
                                q++;
                            }

                        default:
                    }

                default:
            }
            return false;
        }
    }

    static function getTreeHeadLiteral(node:Node, exact:Bool, reg:Regex):Node {
        var n:Node = null;
        switch (node.nodeType) {
            case NODE_BACKREF, NODE_ALT, NODE_CALL:

            case NODE_CTYPE, NODE_CCLASS:
                if (node.nodeType == NODE_CTYPE && node.ctype == CTYPE_ANYCHAR) {
                }
                else if (!exact) {
                    n = node;
                }

            case NODE_LIST:
                n = getTreeHeadLiteral(node.car, exact, reg);

            case NODE_STRING:
                if (node.end <= node.s) {
                }
                else if (!exact || !NODE_IS_REAL_IGNORECASE(node)) {
                    n = node;
                }

            case NODE_QUANT:
                var qn = node;
                if (qn.lower > 0) {
                    if (qn.headExact != null)
                        n = qn.headExact;
                    else
                        n = getTreeHeadLiteral(node.body, exact, reg);
                }

            case NODE_BAG:
                switch (node.type) {
                    case BAG_OPTION, BAG_MEMORY, BAG_STOP_BACKTRACK, BAG_IF_ELSE:
                        n = getTreeHeadLiteral(node.body, exact, reg);
                }

            case NODE_ANCHOR:
                if (node.type == ANCR_PREC_READ)
                    n = getTreeHeadLiteral(node.body, exact, reg);

            default:
        }
        return n;
    }

    static inline var GET_VALUE_NONE:Int = -1;
    static inline var GET_VALUE_IGNORE:Int = 0;
    static inline var GET_VALUE_FOUND:Int = 1;
    static inline var MAX_NEST_LEVEL_GET_TREE_TAIL_LITERAL:Int = 16;

    static function getTreeTailLiteral(node:Node, rnode:NodeRef, reg:Regex, nestLevel:Int):Int {
        var r:Int;
        nestLevel++;
        if (nestLevel >= MAX_NEST_LEVEL_GET_TREE_TAIL_LITERAL) {
            return GET_VALUE_NONE;
        }

        switch (node.nodeType) {
            case NODE_LIST:
                if (node.cdr == null) {
                    r = getTreeTailLiteral(node.car, rnode, reg, nestLevel);
                }
                else {
                    r = getTreeTailLiteral(node.cdr, rnode, reg, nestLevel);
                    if (r == GET_VALUE_IGNORE) {
                        r = getTreeTailLiteral(node.car, rnode, reg, nestLevel);
                    }
                }

            case NODE_CALL:
                r = getTreeTailLiteral(node.body, rnode, reg, nestLevel);

            case NODE_CTYPE, NODE_CCLASS:
                if (node.nodeType == NODE_CTYPE && node.ctype == CTYPE_ANYCHAR) {
                    r = GET_VALUE_NONE;
                }
                else {
                    rnode.v = node;
                    r = GET_VALUE_FOUND;
                }

            case NODE_STRING:
                if (node.end <= node.s) {
                    r = GET_VALUE_IGNORE;
                }
                else if (NODE_IS_REAL_IGNORECASE(node)) {
                    r = GET_VALUE_NONE;
                }
                else {
                    rnode.v = node;
                    r = GET_VALUE_FOUND;
                }

            case NODE_QUANT:
                var qn = node;
                if (qn.lower != 0) {
                    r = getTreeTailLiteral(node.body, rnode, reg, nestLevel);
                }
                else
                    r = GET_VALUE_NONE;

            case NODE_BAG:
                if (node.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_MARK1))
                        r = GET_VALUE_NONE;
                    else {
                        node.addStatus(NODE_ST_MARK1);
                        r = getTreeTailLiteral(node.body, rnode, reg, nestLevel);
                        node.removeStatus(NODE_ST_MARK1);
                    }
                }
                else {
                    r = getTreeTailLiteral(node.body, rnode, reg, nestLevel);
                }

            case NODE_ANCHOR, NODE_GIMMICK:
                r = GET_VALUE_IGNORE;

            default:
                r = GET_VALUE_NONE;
        }
        return r;
    }

    static function checkCalledNodeInLookBehind(node:Node, not:Int):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = checkCalledNodeInLookBehind(node.car, not);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_QUANT:
                r = checkCalledNodeInLookBehind(node.body, not);

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_MARK1))
                        return 0;
                    else {
                        node.addStatus(NODE_ST_MARK1);
                        r = checkCalledNodeInLookBehind(node.body, not);
                        node.removeStatus(NODE_ST_MARK1);
                    }
                }
                else {
                    r = checkCalledNodeInLookBehind(node.body, not);
                    if (r == 0 && en.type == BAG_IF_ELSE) {
                        if (en.Then != null) {
                            r = checkCalledNodeInLookBehind(en.Then, not);
                            if (r != 0) return r;
                        }
                        if (en.Else != null) {
                            r = checkCalledNodeInLookBehind(en.Else, not);
                        }
                    }
                }

            case NODE_ANCHOR:
                if (node.body != null)
                    r = checkCalledNodeInLookBehind(node.body, not);

            case NODE_GIMMICK:
                if (node.hasStatus(NODE_ST_ABSENT_WITH_SIDE_EFFECTS))
                    return 1;

            default:
        }
        return r;
    }

    static inline var ALLOWED_TYPE_IN_LB:Int = (1 << NODE_LIST) | (1 << NODE_ALT) | (1 << NODE_STRING) | (1 << NODE_CCLASS)
        | (1 << NODE_CTYPE) | (1 << NODE_ANCHOR) | (1 << NODE_BAG) | (1 << NODE_QUANT) | (1 << NODE_CALL) | (1 << NODE_BACKREF)
        | (1 << NODE_GIMMICK);
    static inline var ALLOWED_BAG_IN_LB:Int = (1 << BAG_MEMORY) | (1 << BAG_OPTION) | (1 << BAG_STOP_BACKTRACK) | (1 << BAG_IF_ELSE);
    static inline var ALLOWED_BAG_IN_LB_NOT:Int = (1 << BAG_OPTION) | (1 << BAG_STOP_BACKTRACK) | (1 << BAG_IF_ELSE);
    static inline var ALLOWED_ANCHOR_IN_LB:Int = ANCR_LOOK_BEHIND | ANCR_BEGIN_LINE | ANCR_END_LINE | ANCR_BEGIN_BUF
        | ANCR_BEGIN_POSITION | ANCR_WORD_BOUNDARY | ANCR_NO_WORD_BOUNDARY | ANCR_WORD_BEGIN | ANCR_WORD_END
        | ANCR_TEXT_SEGMENT_BOUNDARY | ANCR_NO_TEXT_SEGMENT_BOUNDARY;
    static inline var ALLOWED_ANCHOR_IN_LB_NOT:Int = ANCR_LOOK_BEHIND | ANCR_LOOK_BEHIND_NOT | ANCR_BEGIN_LINE | ANCR_END_LINE
        | ANCR_BEGIN_BUF | ANCR_BEGIN_POSITION | ANCR_WORD_BOUNDARY | ANCR_NO_WORD_BOUNDARY | ANCR_WORD_BEGIN | ANCR_WORD_END
        | ANCR_TEXT_SEGMENT_BOUNDARY | ANCR_NO_TEXT_SEGMENT_BOUNDARY;

    static function checkNodeInLookBehind(node:Node, not:Int, used:IntRef):Int {
        var bagMask = not == 0 ? ALLOWED_BAG_IN_LB : ALLOWED_BAG_IN_LB_NOT;
        var anchorMask = not == 0 ? ALLOWED_ANCHOR_IN_LB : ALLOWED_ANCHOR_IN_LB_NOT;
        var r = 0;
        var type = node.nodeType;
        if (((1 << type) & ALLOWED_TYPE_IN_LB) == 0)
            return 1;

        switch (type) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = checkNodeInLookBehind(node.car, not, used);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_QUANT:
                r = checkNodeInLookBehind(node.body, not, used);

            case NODE_BAG:
                var en = node;
                if (((1 << en.type) & bagMask) == 0)
                    return 1;
                r = checkNodeInLookBehind(node.body, not, used);
                if (r != 0) return r;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_BACKREF) || node.hasStatus(NODE_ST_CALLED) || node.hasStatus(NODE_ST_REFERENCED))
                        used.v = 1;
                }
                else if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = checkNodeInLookBehind(en.Then, not, used);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = checkNodeInLookBehind(en.Else, not, used);
                    }
                }

            case NODE_ANCHOR:
                var atype = node.type;
                if ((atype & anchorMask) == 0)
                    return 1;
                if (node.body != null)
                    r = checkNodeInLookBehind(node.body, not, used);

            case NODE_GIMMICK:
                if (node.hasStatus(NODE_ST_ABSENT_WITH_SIDE_EFFECTS))
                    return 1;
                if (node.type == GIMMICK_SAVE && node.detailType == SAVE_KEEP)
                    used.v = 1;

            case NODE_CALL:
                if (node.hasStatus(NODE_ST_RECURSION)) {
                    used.v = 1;
                }
                else
                    r = checkCalledNodeInLookBehind(node.body, not);

            default:
        }
        return r;
    }

    static function nodeMinByteLen(node:Node, env:ParseEnv):Int {
        var len = 0;
        var tmin:Int;
        switch (node.nodeType) {
            case NODE_BACKREF:
                if (!node.hasStatus(NODE_ST_CHECKER)) {
                    var memEnv = env.memEnv;
                    var br = node;
                    if (!node.hasStatus(NODE_ST_RECURSION)) {
                        var backs = br.backs;
                        len = nodeMinByteLen(memEnv[backs[0]].memNode, env);
                        for (i in 1...br.backNum) {
                            tmin = nodeMinByteLen(memEnv[backs[i]].memNode, env);
                            if (len > tmin) len = tmin;
                        }
                    }
                }

            case NODE_CALL:
                var t = node.body;
                if (t.hasStatus(NODE_ST_FIXED_MIN))
                    len = t.minLen;
                else
                    len = nodeMinByteLen(t, env);

            case NODE_LIST:
                do {
                    tmin = nodeMinByteLen(node.car, env);
                    len = distanceAdd(len, tmin);
                } while ((node = node.cdr) != null);

            case NODE_ALT:
                var y = node;
                do {
                    var x = y.car;
                    tmin = nodeMinByteLen(x, env);
                    if (y == node) len = tmin;
                    else if (len > tmin) len = tmin;
                } while ((y = y.cdr) != null);

            case NODE_STRING:
                len = node.end - node.s;

            case NODE_CTYPE, NODE_CCLASS:
                len = ONIGENC_MBC_MINLEN;

            case NODE_QUANT:
                var qn = node;
                if (qn.lower > 0) {
                    len = nodeMinByteLen(node.body, env);
                    len = distanceMultiply(len, qn.lower);
                }

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_MEMORY:
                        if (node.hasStatus(NODE_ST_FIXED_MIN))
                            len = en.minLen;
                        else {
                            if (node.hasStatus(NODE_ST_MARK1))
                                len = 0; /* recursive */
                            else {
                                node.addStatus(NODE_ST_MARK1);
                                len = nodeMinByteLen(node.body, env);
                                node.removeStatus(NODE_ST_MARK1);
                                en.minLen = len;
                                node.addStatus(NODE_ST_FIXED_MIN);
                            }
                        }
                    case BAG_OPTION, BAG_STOP_BACKTRACK:
                        len = nodeMinByteLen(node.body, env);
                    case BAG_IF_ELSE:
                        var elen:Int;
                        len = nodeMinByteLen(node.body, env);
                        if (en.Then != null)
                            len = rawLenAdd(len, nodeMinByteLen(en.Then, env));
                        if (en.Else != null)
                            elen = nodeMinByteLen(en.Else, env);
                        else elen = 0;
                        if (elen < len) len = elen;
                }

            case NODE_GIMMICK:
                if (node.type == GIMMICK_FAIL) {
                    len = INFINITE_LEN;
                }

            default:
        }
        return len;
    }

    static function checkBackrefs(node:Node, env:ParseEnv):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = checkBackrefs(node.car, env);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_ANCHOR, NODE_QUANT:
                if (node.nodeType == NODE_ANCHOR && !ANCHOR_HAS_BODY(node.type)) {
                    r = 0;
                }
                else
                    r = checkBackrefs(node.body, env);

            case NODE_BAG:
                r = checkBackrefs(node.body, env);
                var en = node;
                if (en.type == BAG_IF_ELSE) {
                    if (r != 0) return r;
                    if (en.Then != null) {
                        r = checkBackrefs(en.Then, env);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = checkBackrefs(en.Else, env);
                    }
                }

            case NODE_BACKREF:
                var br = node;
                var backs = br.backs;
                var memEnv = env.memEnv;
                for (i in 0...br.backNum) {
                    if (backs[i] > env.numMem)
                        return ONIGERR_INVALID_BACKREF;
                    memEnv[backs[i]].memNode.addStatus(NODE_ST_BACKREF);
                }
                r = 0;

            default:
                r = 0;
        }
        return r;
    }

    static function setEmptyRepeatNodeTrav(node:Node, empty:Node, env:ParseEnv):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = setEmptyRepeatNodeTrav(node.car, empty, env);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_ANCHOR:
                var an = node;
                if (!ANCHOR_HAS_BODY(an.type)) {
                    r = 0;
                }
                else {
                    switch (an.type) {
                        case ANCR_PREC_READ, ANCR_LOOK_BEHIND:
                            empty = null;
                        default:
                    }
                    r = setEmptyRepeatNodeTrav(node.body, empty, env);
                }

            case NODE_QUANT:
                var qn = node;
                if (qn.emptiness != BODY_IS_NOT_EMPTY) empty = node;
                r = setEmptyRepeatNodeTrav(node.body, empty, env);

            case NODE_BAG:
                if (node.body != null) {
                    r = setEmptyRepeatNodeTrav(node.body, empty, env);
                    if (r != 0) return r;
                }
                var en = node;
                r = 0;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_BACKREF)) {
                        if (empty != null)
                            env.memEnv[en.regnum].emptyRepeatNode = empty;
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = setEmptyRepeatNodeTrav(en.Then, empty, env);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = setEmptyRepeatNodeTrav(en.Else, empty, env);
                    }
                }

            default:
                r = 0;
        }
        return r;
    }

    static function isAncestorNode(node:Node, me:Node):Bool {
        var parent:Node;
        while ((parent = me.parent) != null) {
            if (parent == node) return true;
            me = parent;
        }
        return false;
    }

    static function setEmptyStatusCheckTrav(node:Node, env:ParseEnv):Void {
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    setEmptyStatusCheckTrav(node.car, env);
                } while ((node = node.cdr) != null);

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    setEmptyStatusCheckTrav(node.body, env);

            case NODE_QUANT:
                setEmptyStatusCheckTrav(node.body, env);

            case NODE_BAG:
                if (node.body != null)
                    setEmptyStatusCheckTrav(node.body, env);
                var en = node;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        setEmptyStatusCheckTrav(en.Then, env);
                    }
                    if (en.Else != null) {
                        setEmptyStatusCheckTrav(en.Else, env);
                    }
                }

            case NODE_BACKREF:
                var memEnv = env.memEnv;
                var br = node;
                var backs = br.backs;
                for (i in 0...br.backNum) {
                    var ernode = memEnv[backs[i]].emptyRepeatNode;
                    if (ernode != null) {
                        if (!isAncestorNode(ernode, node)) {
                            ernode.emptyStatusMem = MEM_STATUS_LIMIT_ON(ernode.emptyStatusMem, backs[i]);
                            ernode.addStatus(NODE_ST_EMPTY_STATUS_CHECK);
                            memEnv[backs[i]].memNode.addStatus(NODE_ST_EMPTY_STATUS_CHECK);
                        }
                    }
                }

            default:
        }
    }

    static function setParentNodeTrav(node:Node, parent:Node):Void {
        node.parent = parent;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    setParentNodeTrav(node.car, node);
                } while ((node = node.cdr) != null);

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    setParentNodeTrav(node.body, node);

            case NODE_QUANT:
                setParentNodeTrav(node.body, node);

            case NODE_BAG:
                if (node.body != null)
                    setParentNodeTrav(node.body, node);
                var en = node;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null)
                        setParentNodeTrav(en.Then, node);
                    if (en.Else != null) {
                        setParentNodeTrav(en.Else, node);
                    }
                }

            default:
        }
    }

    static inline var RECURSION_EXIST:Int = 1 << 0;
    static inline var RECURSION_MUST:Int = 1 << 1;
    static inline var RECURSION_INFINITE:Int = 1 << 2;

    static function infiniteRecursiveCallCheck(node:Node, env:ParseEnv, head:Int):Int {
        var ret:Int;
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST:
                var x = node;
                do {
                    ret = infiniteRecursiveCallCheck(x.car, env, head);
                    if (ret < 0 || (ret & RECURSION_INFINITE) != 0) return ret;
                    r |= ret;
                    if (head != 0) {
                        var min = nodeMinByteLen(x.car, env);
                        if (min != 0) head = 0;
                    }
                } while ((x = x.cdr) != null);

            case NODE_ALT:
                var must = RECURSION_MUST;
                do {
                    ret = infiniteRecursiveCallCheck(node.car, env, head);
                    if (ret < 0 || (ret & RECURSION_INFINITE) != 0) return ret;
                    r |= (ret & RECURSION_EXIST);
                    must &= ret;
                } while ((node = node.cdr) != null);
                r |= must;

            case NODE_QUANT:
                if (node.upper != 0) {
                    r = infiniteRecursiveCallCheck(node.body, env, head);
                    if (r < 0) return r;
                    if ((r & RECURSION_MUST) != 0) {
                        if (node.lower == 0)
                            r &= ~RECURSION_MUST;
                    }
                }

            case NODE_ANCHOR, NODE_CALL:
                if (node.nodeType == NODE_ANCHOR && !ANCHOR_HAS_BODY(node.type)) {
                }
                else
                    r = infiniteRecursiveCallCheck(node.body, env, head);

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_MARK2))
                        return 0;
                    else if (node.hasStatus(NODE_ST_MARK1))
                        return (head == 0 ? RECURSION_EXIST | RECURSION_MUST : RECURSION_EXIST | RECURSION_MUST | RECURSION_INFINITE);
                    else {
                        node.addStatus(NODE_ST_MARK2);
                        r = infiniteRecursiveCallCheck(node.body, env, head);
                        node.removeStatus(NODE_ST_MARK2);
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    ret = infiniteRecursiveCallCheck(node.body, env, head);
                    if (ret < 0 || (ret & RECURSION_INFINITE) != 0) return ret;
                    r |= ret;
                    if (en.Then != null) {
                        var min:Int;
                        if (head != 0) {
                            min = nodeMinByteLen(node.body, env);
                        }
                        else min = 0;
                        ret = infiniteRecursiveCallCheck(en.Then, env, min != 0 ? 0 : head);
                        if (ret < 0 || (ret & RECURSION_INFINITE) != 0) return ret;
                        r |= ret;
                    }
                    if (en.Else != null) {
                        var eret = infiniteRecursiveCallCheck(en.Else, env, head);
                        if (eret < 0 || (eret & RECURSION_INFINITE) != 0) return eret;
                        r |= (eret & RECURSION_EXIST);
                        if ((eret & RECURSION_MUST) == 0)
                            r &= ~RECURSION_MUST;
                    }
                    else {
                        r &= ~RECURSION_MUST;
                    }
                }
                else {
                    r = infiniteRecursiveCallCheck(node.body, env, head);
                }

            default:
        }
        return r;
    }

    static function infiniteRecursiveCallCheckTrav(node:Node, env:ParseEnv):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = infiniteRecursiveCallCheckTrav(node.car, env);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_ANCHOR, NODE_QUANT:
                if (node.nodeType == NODE_ANCHOR && !ANCHOR_HAS_BODY(node.type)) {
                    r = 0;
                }
                else
                    r = infiniteRecursiveCallCheckTrav(node.body, env);

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_RECURSION) && node.hasStatus(NODE_ST_CALLED)) {
                        node.addStatus(NODE_ST_MARK1);
                        var ret = infiniteRecursiveCallCheck(node.body, env, 1);
                        if (ret < 0) return ret;
                        else if ((ret & (RECURSION_MUST | RECURSION_INFINITE)) != 0)
                            return ONIGERR_NEVER_ENDING_RECURSION;
                        node.removeStatus(NODE_ST_MARK1);
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = infiniteRecursiveCallCheckTrav(en.Then, env);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = infiniteRecursiveCallCheckTrav(en.Else, env);
                        if (r != 0) return r;
                    }
                }
                r = infiniteRecursiveCallCheckTrav(node.body, env);

            default:
                r = 0;
        }
        return r;
    }

    static function recursiveCallCheck(node:Node):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                r = 0;
                do {
                    r |= recursiveCallCheck(node.car);
                } while ((node = node.cdr) != null);

            case NODE_ANCHOR, NODE_QUANT:
                if (node.nodeType == NODE_ANCHOR && !ANCHOR_HAS_BODY(node.type)) {
                    r = 0;
                }
                else
                    r = recursiveCallCheck(node.body);

            case NODE_CALL:
                r = recursiveCallCheck(node.body);
                if (r != 0) {
                    if (node.body.hasStatus(NODE_ST_MARK1))
                        node.addStatus(NODE_ST_RECURSION);
                }

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_MARK2))
                        return 0;
                    else if (node.hasStatus(NODE_ST_MARK1))
                        return 1; /* recursion */
                    else {
                        node.addStatus(NODE_ST_MARK2);
                        r = recursiveCallCheck(node.body);
                        node.removeStatus(NODE_ST_MARK2);
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    r = 0;
                    if (en.Then != null) {
                        r |= recursiveCallCheck(en.Then);
                    }
                    if (en.Else != null) {
                        r |= recursiveCallCheck(en.Else);
                    }
                    r |= recursiveCallCheck(node.body);
                }
                else {
                    r = recursiveCallCheck(node.body);
                }

            default:
                r = 0;
        }
        return r;
    }

    static inline var IN_RECURSION:Int = 1 << 0;
    static inline var FOUND_CALLED_NODE:Int = 1;

    static function recursiveCallCheckTrav(node:Node, env:ParseEnv, state:Int):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                var ret:Int;
                do {
                    ret = recursiveCallCheckTrav(node.car, env, state);
                    if (ret == FOUND_CALLED_NODE) r = FOUND_CALLED_NODE;
                    else if (ret < 0) return ret;
                } while ((node = node.cdr) != null);

            case NODE_QUANT:
                r = recursiveCallCheckTrav(node.body, env, state);
                if (node.upper == 0) {
                    if (r == FOUND_CALLED_NODE)
                        node.includeReferred = 1;
                }

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    r = recursiveCallCheckTrav(node.body, env, state);

            case NODE_BAG:
                var ret:Int;
                var en = node;
                if (en.type == BAG_MEMORY) {
                    var check = false;
                    if (node.hasStatus(NODE_ST_CALLED)) {
                        r = FOUND_CALLED_NODE;
                        check = true;
                    }
                    else if ((state & IN_RECURSION) != 0) {
                        check = true;
                    }
                    if (check) {
                        // check_recursion:
                        if (!node.hasStatus(NODE_ST_RECURSION)) {
                            node.addStatus(NODE_ST_MARK1);
                            ret = recursiveCallCheck(node.body);
                            if (ret != 0) {
                                node.addStatus(NODE_ST_RECURSION);
                                env.backtrackMem = MEM_STATUS_ON(env.backtrackMem, en.regnum);
                            }
                            node.removeStatus(NODE_ST_MARK1);
                        }
                    }
                }

                var state1 = state;
                if (node.hasStatus(NODE_ST_RECURSION))
                    state1 |= IN_RECURSION;

                ret = recursiveCallCheckTrav(node.body, env, state1);
                if (ret == FOUND_CALLED_NODE)
                    r = FOUND_CALLED_NODE;

                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        ret = recursiveCallCheckTrav(en.Then, env, state1);
                        if (ret == FOUND_CALLED_NODE)
                            r = FOUND_CALLED_NODE;
                    }
                    if (en.Else != null) {
                        ret = recursiveCallCheckTrav(en.Else, env, state1);
                        if (ret == FOUND_CALLED_NODE)
                            r = FOUND_CALLED_NODE;
                    }
                }

            default:
        }
        return r;
    }

    static function removeFromList(prev:Node, a:Node):Void {
        if (prev.cdr != a) return;
        prev.cdr = a.cdr;
        a.cdr = null;
    }

    static function reduceStringList(node:Node):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST:
                var prev:Node = null;
                var prevNode:Node = null;
                var nextNode:Node;
                do {
                    nextNode = node.cdr;
                    var curr = node.car;
                    if (curr.nodeType == NODE_STRING) {
                        if (prev == null || curr.flag != prev.flag || curr.status != prev.status) {
                            prev = curr;
                            prevNode = node;
                        }
                        else {
                            r = nodeStrNodeCat(prev, curr);
                            if (r != 0) return r;
                            removeFromList(prevNode, node);
                        }
                    }
                    else {
                        if (prev != null) {
                            if (!isValidMbcString(prev.sbuf, prev.s, prev.end))
                                return ONIGERR_INVALID_WIDE_CHAR_VALUE;
                            prev = null;
                        }
                        r = reduceStringList(curr);
                        if (r != 0) return r;
                        prevNode = node;
                    }
                    node = nextNode;
                } while (r == 0 && node != null);

                if (prev != null) {
                    if (!isValidMbcString(prev.sbuf, prev.s, prev.end))
                        return ONIGERR_INVALID_WIDE_CHAR_VALUE;
                }

            case NODE_ALT:
                do {
                    r = reduceStringList(node.car);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_STRING:
                if (!isValidMbcString(node.sbuf, node.s, node.end))
                    return ONIGERR_INVALID_WIDE_CHAR_VALUE;

            case NODE_ANCHOR, NODE_QUANT:
                if (node.nodeType == NODE_ANCHOR && node.body == null) {
                }
                else
                    r = reduceStringList(node.body);

            case NODE_BAG:
                var en = node;
                r = reduceStringList(node.body);
                if (r != 0) return r;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = reduceStringList(en.Then);
                        if (r != 0) return r;
                    }
                    if (en.Else != null) {
                        r = reduceStringList(en.Else);
                        if (r != 0) return r;
                    }
                }

            default:
        }
        return r;
    }

    static inline var IN_ALT:Int = 1 << 0;
    static inline var IN_NOT:Int = 1 << 1;
    static inline var IN_REAL_REPEAT:Int = 1 << 2;
    static inline var IN_VAR_REPEAT:Int = 1 << 3;
    static inline var IN_ZERO_REPEAT:Int = 1 << 4;
    static inline var IN_MULTI_ENTRY:Int = 1 << 5;
    static inline var IN_PREC_READ:Int = 1 << 6;
    static inline var IN_LOOK_BEHIND:Int = 1 << 7;
    static inline var IN_PEEK:Int = 1 << 8;

    /* divide different length alternatives in look-behind.
      (?<=A|B) ==> (?<=A)|(?<=B)
      (?<!A|B) ==> (?<!A)(?<!B)
    */
    static function divideLookBehindAlternatives(node:Node):Int {
        var an = node;
        var ancType = an.type;

        var head = an.body;
        var np = head.car;
        nodeSwap(node, head);
        node.car = head;
        head.body = np;

        np = node;
        var insertNode = new NodeRef();
        while ((np = np.cdr) != null) {
            var r = Regparse.onigNodeCopy(insertNode, head);
            if (r != 0) return r;
            insertNode.v.body = np.car;
            np.car = insertNode.v;
        }

        if (ancType == ANCR_LOOK_BEHIND_NOT) {
            np = node;
            do {
                np.nodeType = NODE_LIST; /* alt -> list */
            } while ((np = np.cdr) != null);
        }
        return 0;
    }

    static function nodeReduceInLookBehind(node:Node):Int {
        if (node.nodeType != NODE_QUANT) return 0;
        var body = node.body;
        var type = body.nodeType;
        if (type == NODE_STRING || type == NODE_CTYPE || type == NODE_CCLASS || type == NODE_BACKREF) {
            var qn = node;
            qn.upper = qn.lower;
            if (qn.upper == 0)
                return 1; /* removed */
        }
        return 0;
    }

    static function listReduceInLookBehind(node:Node):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_QUANT:
                r = nodeReduceInLookBehind(node);
                if (r > 0) r = 0;
            case NODE_LIST:
                do {
                    r = nodeReduceInLookBehind(node.car);
                    if (r <= 0) break;
                } while ((node = node.cdr) != null);
            default:
                r = 0;
        }
        return r;
    }

    static function altReduceInLookBehind(node:Node, reg:Regex, env:ParseEnv):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_ALT:
                do {
                    r = listReduceInLookBehind(node.car);
                } while (r == 0 && (node = node.cdr) != null);
            default:
                r = listReduceInLookBehind(node);
        }
        return r;
    }

    static function tuneLookBehind(node:Node, reg:Regex, state:Int, env:ParseEnv):Int {
        var r:Int;
        var state1:Int;
        var used = new IntRef(0);
        var ci = new MinMaxCharLen();
        var an = node;

        r = checkNodeInLookBehind(an.body, an.type == ANCR_LOOK_BEHIND_NOT ? 1 : 0, used);
        if (r < 0) return r;
        if (r > 0) return ONIGERR_INVALID_LOOK_BEHIND_PATTERN;

        if (an.type == ANCR_LOOK_BEHIND_NOT)
            state1 = state | IN_NOT | IN_LOOK_BEHIND;
        else
            state1 = state | IN_LOOK_BEHIND;

        var body = an.body;
        /* Execute tune_tree(body) before call node_char_len().
           Because case-fold expansion must be done before node_char_len().
         */
        r = tuneTree(body, reg, state1, env);
        if (r != 0) return r;

        r = altReduceInLookBehind(body, reg, env);
        if (r != 0) return r;

        r = nodeCharLen(body, reg, ci, env);
        if (r >= 0) {
            /* #177: overflow in onigenc_step_back() */
            if ((ci.max != INFINITE_LEN && ci.max > LOOK_BEHIND_MAX_CHAR_LEN) || ci.min > LOOK_BEHIND_MAX_CHAR_LEN) {
                return ONIGERR_INVALID_LOOK_BEHIND_PATTERN;
            }

            if (ci.min == 0 && ci.minIsSure && used.v == 0) {
                if (an.type == ANCR_LOOK_BEHIND_NOT)
                    r = Regparse.onigNodeResetFail(node);
                else
                    r = Regparse.onigNodeResetEmpty(node);
                return r;
            }

            var normal = false;
            if (r == CHAR_LEN_TOP_ALT_FIXED) {
                if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_DIFFERENT_LEN_ALT_LOOK_BEHIND)) {
                    r = divideLookBehindAlternatives(node);
                    if (r == 0)
                        r = tuneTree(node, reg, state, env);
                }
                else if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND))
                    normal = true;
                else
                    r = ONIGERR_INVALID_LOOK_BEHIND_PATTERN;
            }
            else { /* CHAR_LEN_NORMAL */
                normal = true;
            }
            if (normal) {
                if (ci.min == INFINITE_LEN) {
                    r = ONIGERR_INVALID_LOOK_BEHIND_PATTERN;
                }
                else {
                    if (ci.min != ci.max && !IS_SYNTAX_BV(env.syntax, ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND)) {
                        r = ONIGERR_INVALID_LOOK_BEHIND_PATTERN;
                    }
                    else {
                        /* check lead_node is already set by double call after
                           divide_look_behind_alternatives() */
                        if (an.leadNode == null) {
                            an.charMinLen = ci.min;
                            an.charMaxLen = ci.max;
                            var tail = new NodeRef();
                            r = getTreeTailLiteral(body, tail, reg, 0);
                            if (r == GET_VALUE_FOUND) {
                                var lr = new NodeRef();
                                r = Regparse.onigNodeCopy(lr, tail.v);
                                an.leadNode = lr.v;
                                if (r != 0) return r;
                            }
                        }
                        r = ONIG_NORMAL;
                    }
                }
            }
        }
        return r;
    }

    static function tuneNext(node:Node, nextNode:Node, reg:Regex):Int {
        var called = false;
        while (true) { // retry:
            var type = node.nodeType;
            if (type == NODE_QUANT) {
                var qn = node;
                if (qn.greedy != 0 && qn.upper == INFINITE_REPEAT) {
                    if (!called) {
                        var n = getTreeHeadLiteral(nextNode, true, reg);
                        /* '\0': for UTF-16BE etc... */
                        if (n != null && n.sbuf.get(n.s) != 0) {
                            qn.nextHeadExact = n;
                        }
                    }
                    /* automatic posseivation a*b ==> (?>a*)b */
                    if (qn.lower <= 1) {
                        if (isStrictRealNode(node.body)) {
                            var x = getTreeHeadLiteral(node.body, false, reg);
                            if (x != null) {
                                var y = getTreeHeadLiteral(nextNode, false, reg);
                                if (y != null && isExclusive(x, y, reg)) {
                                    var en = Regparse.onigNodeNewBag(BAG_STOP_BACKTRACK);
                                    en.addStatus(NODE_ST_STRICT_REAL_REPEAT);
                                    nodeSwap(node, en);
                                    node.body = en;
                                }
                            }
                        }
                    }
                }
            }
            else if (type == NODE_BAG) {
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_CALLED))
                        called = true;
                    node = node.body;
                    continue;
                }
            }
            return 0;
        }
    }

    static function isAllCodeLen1Items(n:Int, items:Array<OnigCaseFoldCodeItem>):Bool {
        for (i in 0...n) {
            if (items[i].codeLen != 1) return false;
        }
        return true;
    }

    static function makeCodeListToString(rnode:NodeRef, n:Int, codes:Vector<Int>):Int {
        var buf = Bytes.alloc(ONIGENC_CODE_TO_MBC_MAXLEN);
        rnode.v = null;
        var node = Regparse.onigNodeNewStr(null, 0, 0);
        for (i in 0...n) {
            var len = codeToMbc(codes[i], buf, 0);
            if (len < 0) {
                return len;
            }
            var r = Regparse.onigNodeStrCat(node, buf, 0, len);
            if (r != 0) return r;
        }
        rnode.v = node;
        return 0;
    }

    static function unravelCfNodeAdd(rlist:NodeRef, add:Node):Int {
        var list = rlist.v;
        if (list == null) {
            list = Regparse.onigNodeNewList(add, null);
            rlist.v = list;
        }
        else {
            nodeListAdd(list, add);
        }
        return 0;
    }

    static function unravelCfStringAdd(rlist:NodeRef, rsn:NodeRef, sb:Bytes, s:Int, end:Int, flag:Int):Int {
        var r:Int;
        var list = new NodeRef(rlist.v);
        var sn = rsn.v;
        if (sn != null && sn.flag == flag) {
            r = Regparse.onigNodeStrCat(sn, sb, s, end);
        }
        else {
            sn = Regparse.onigNodeNewStr(sb, s, end);
            sn.flag = flag;
            r = unravelCfNodeAdd(list, sn);
        }
        if (r == 0) {
            rlist.v = list.v;
            rsn.v = sn;
        }
        return r;
    }

    static function unravelCfStringAltOrCcAdd(rlist:NodeRef, n:Int, items:Array<OnigCaseFoldCodeItem>, caseFoldFlag:Int,
            sb:Bytes, s:Int, end:Int):Int {
        var r:Int;
        var node:Node;
        if (isAllCodeLen1Items(n, items)) {
            var codes = new Array<Int>();
            codes.push(mbcToCode(sb, s, end));
            for (i in 0...n) {
                codes.push(items[i].code[0]);
            }
            var nr = new NodeRef();
            r = Regparse.onigNewCclassWithCodeList(nr, n + 1, codes);
            if (r != 0) return r;
            node = nr.v;
        }
        else {
            var snode = Regparse.onigNodeNewStr(sb, s, end);
            var curr = Regparse.onigNodeNewAlt(snode, null);
            node = curr;
            var sr = new NodeRef();
            for (i in 0...n) {
                var item = items[i];
                r = makeCodeListToString(sr, item.codeLen, item.code);
                if (r != 0) {
                    return r;
                }
                var alt = Regparse.onigNodeNewAlt(sr.v, null);
                curr.cdr = alt;
                curr = alt;
            }
        }
        return unravelCfNodeAdd(rlist, node);
    }

    static function unravelCfLookBehindAdd(rlist:NodeRef, rsn:NodeRef, n:Int, items:Array<OnigCaseFoldCodeItem>,
            sb:Bytes, s:Int, oneLen:Int):Int {
        var r:Int;
        var found = false;
        for (i in 0...n) {
            var item = items[i];
            if (item.byteLen == oneLen) {
                if (item.codeLen == 1) {
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            r = unravelCfStringAdd(rlist, rsn, sb, s, s + oneLen, 0 /* flag */);
        }
        else {
            var codes = new Array<Int>();
            codes.push(mbcToCode(sb, s, s + oneLen));
            for (i in 0...n) {
                var item = items[i];
                if (item.byteLen == oneLen) {
                    if (item.codeLen == 1) {
                        codes.push(item.code[0]);
                    }
                }
            }
            var nr = new NodeRef();
            r = Regparse.onigNewCclassWithCodeList(nr, codes.length, codes);
            if (r != 0) return r;
            r = unravelCfNodeAdd(rlist, nr.v);
            rsn.v = null;
        }
        return r;
    }

    static function unravelCaseFoldString(node:Node, reg:Regex, state:Int):Int {
        var r:Int;
        var n:Int;
        var items = OnigCaseFoldCodeItem.newArray();

        if (node.isStrCaseExpanded()) return 0;

        node.removeStatus(NODE_ST_IGNORECASE);
        var sb = node.sbuf;
        var start = node.s;
        var end = node.end;
        if (start >= end) return 0;

        var inLookBehind = (state & IN_LOOK_BEHIND) != 0;

        var list = new NodeRef();
        var sn = new NodeRef();
        var p = start;
        var q:Int;
        while (p < end) {
            n = Unicode.onigencUnicodeGetCaseFoldCodesByStr(reg.caseFoldFlag, sb, p, end, items);
            if (n < 0) {
                return n;
            }

            var oneLen = enclen(sb, p);
            if (n == 0) {
                q = p + oneLen;
                if (q > end) q = end;
                r = unravelCfStringAdd(list, sn, sb, p, q, 0 /* flag */);
                if (r != 0) return r;
            }
            else {
                if (inLookBehind) {
                    q = p + oneLen;
                    if (items[0].byteLen != oneLen) {
                        r = Unicode.onigencUnicodeGetCaseFoldCodesByStr(reg.caseFoldFlag, sb, p, q, items);
                        if (r < 0) return r;
                        n = r;
                    }
                    r = unravelCfLookBehindAdd(list, sn, n, items, sb, p, oneLen);
                    if (r != 0) return r;
                }
                else {
                    var minLen = INFINITE_LEN;
                    var maxLen = 0;
                    for (i in 0...n) {
                        var len = items[i].byteLen;
                        if (len < minLen) minLen = len;
                        if (len > maxLen) maxLen = len;
                    }
                    if (minLen != maxLen) {
                        return ONIGERR_PARSER_BUG;
                    }
                    q = p + maxLen;
                    r = unravelCfStringAltOrCcAdd(list, n, items, reg.caseFoldFlag, sb, p, q);
                    if (r != 0) return r;
                    sn.v = null;
                }
            }
            p = q;
        }

        if (list.v != null) {
            if (nodeListLen(list.v) == 1) {
                nodeSwap(node, list.v.car);
            }
            else {
                nodeSwap(node, list.v);
            }
        }
        else {
            nodeSwap(node, sn.v);
        }
        return 0;
    }

    static function quantifiersMemoryNodeInfo(node:Node):Int {
        var r = BODY_MAY_BE_EMPTY;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                var v:Int;
                do {
                    v = quantifiersMemoryNodeInfo(node.car);
                    if (v > r) r = v;
                } while ((node = node.cdr) != null);

            case NODE_CALL:
                if (node.hasStatus(NODE_ST_RECURSION)) {
                    return BODY_MAY_BE_EMPTY_REC; /* tiny version */
                }
                else
                    r = quantifiersMemoryNodeInfo(node.body);

            case NODE_QUANT:
                if (node.upper != 0) {
                    r = quantifiersMemoryNodeInfo(node.body);
                }

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_MEMORY:
                        if (node.hasStatus(NODE_ST_RECURSION)) {
                            return BODY_MAY_BE_EMPTY_REC;
                        }
                        return BODY_MAY_BE_EMPTY_MEM;
                    case BAG_OPTION, BAG_STOP_BACKTRACK:
                        r = quantifiersMemoryNodeInfo(node.body);
                    case BAG_IF_ELSE:
                        var v:Int;
                        r = quantifiersMemoryNodeInfo(node.body);
                        if (en.Then != null) {
                            v = quantifiersMemoryNodeInfo(en.Then);
                            if (v > r) r = v;
                        }
                        if (en.Else != null) {
                            v = quantifiersMemoryNodeInfo(en.Else);
                            if (v > r) r = v;
                        }
                }

            default:
        }
        return r;
    }

    static function checkCallReference(cn:Node, env:ParseEnv, state:Int):Int {
        var memEnv = env.memEnv;
        if (cn.byNumber != 0) {
            var gnum = cn.calledGnum;
            if (env.numNamed > 0 && IS_SYNTAX_BV(env.syntax, ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP) && !OPTON_CAPTURE_GROUP(env.options)) {
                return ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED;
            }
            if (gnum > env.numMem) {
                Regparse.onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_GROUP_REFERENCE, cn.name, cn.nameStart, cn.nameEnd);
                return ONIGERR_UNDEFINED_GROUP_REFERENCE;
            }
        }
        else {
            var refs:Array<Array<Int>> = [null];
            var n = Regparse.onigNameToGroupNumbers(env.reg, cn.name, cn.nameStart, cn.nameEnd, refs);
            if (n <= 0) {
                Regparse.onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_NAME_REFERENCE, cn.name, cn.nameStart, cn.nameEnd);
                return ONIGERR_UNDEFINED_NAME_REFERENCE;
            }
            else if (n > 1) {
                Regparse.onigScanEnvSetErrorString(env, ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL, cn.name, cn.nameStart, cn.nameEnd);
                return ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL;
            }
            else {
                cn.calledGnum = refs[0][0];
            }
        }
        // set_call_attr:
        cn.body = memEnv[cn.calledGnum].memNode;
        if (cn.body == null) {
            Regparse.onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_NAME_REFERENCE, cn.name, cn.nameStart, cn.nameEnd);
            return ONIGERR_UNDEFINED_NAME_REFERENCE;
        }
        cn.body.addStatus(NODE_ST_REFERENCED);
        return 0;
    }

    static function checkWholeOptionsPosition(node:Node):Int {
        var isList = false;
        while (true) { // start:
            switch (node.nodeType) {
                case NODE_LIST:
                    if (node.cdr != null)
                        isList = true;
                    node = node.car;
                    continue;
                case NODE_BAG:
                    if (node.type == BAG_OPTION) {
                        if (node.hasStatus(NODE_ST_WHOLE_OPTIONS)) {
                            if (isList && node.body != null) {
                            }
                            else
                                return 0;
                        }
                    }
                default:
            }
            return ONIGERR_INVALID_GROUP_OPTION;
        }
    }

    static function tuneCall2Call(node:Node):Void {
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    tuneCall2Call(node.car);
                } while ((node = node.cdr) != null);

            case NODE_QUANT:
                tuneCall2Call(node.body);

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    tuneCall2Call(node.body);

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (!node.hasStatus(NODE_ST_MARK1)) {
                        node.addStatus(NODE_ST_MARK1);
                        tuneCall2Call(node.body);
                        node.removeStatus(NODE_ST_MARK1);
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    tuneCall2Call(node.body);
                    if (en.Then != null)
                        tuneCall2Call(en.Then);
                    if (en.Else != null)
                        tuneCall2Call(en.Else);
                }
                else {
                    tuneCall2Call(node.body);
                }

            case NODE_CALL:
                if (!node.hasStatus(NODE_ST_MARK1)) {
                    node.addStatus(NODE_ST_MARK1);
                    var cn = node;
                    var called = cn.body;
                    cn.callEntryCount++;
                    called.addStatus(NODE_ST_CALLED);
                    called.entryCount++;
                    tuneCall2Call(called);
                    node.removeStatus(NODE_ST_MARK1);
                }

            default:
        }
    }

    static function tuneCall(node:Node, env:ParseEnv, state:Int):Int {
        var r:Int;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = tuneCall(node.car, env, state);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_QUANT:
                if (node.upper == 0)
                    state |= IN_ZERO_REPEAT;
                r = tuneCall(node.body, env, state);

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    r = tuneCall(node.body, env, state);
                else
                    r = 0;

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if ((state & IN_ZERO_REPEAT) != 0) {
                        node.addStatus(NODE_ST_IN_ZERO_REPEAT);
                        node.entryCount--;
                    }
                    r = tuneCall(node.body, env, state);
                }
                else if (en.type == BAG_IF_ELSE) {
                    r = tuneCall(node.body, env, state);
                    if (r != 0) return r;
                    if (en.Then != null) {
                        r = tuneCall(en.Then, env, state);
                        if (r != 0) return r;
                    }
                    if (en.Else != null)
                        r = tuneCall(en.Else, env, state);
                }
                else
                    r = tuneCall(node.body, env, state);

            case NODE_CALL:
                if ((state & IN_ZERO_REPEAT) != 0) {
                    node.addStatus(NODE_ST_IN_ZERO_REPEAT);
                    node.callEntryCount--;
                }
                r = checkCallReference(node, env, state);

            default:
                r = 0;
        }
        return r;
    }

    static function tuneCall2(node:Node):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST, NODE_ALT:
                do {
                    r = tuneCall2(node.car);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_QUANT:
                if (node.upper != 0)
                    r = tuneCall2(node.body);

            case NODE_ANCHOR:
                if (ANCHOR_HAS_BODY(node.type))
                    r = tuneCall2(node.body);

            case NODE_BAG:
                if (!node.hasStatus(NODE_ST_IN_ZERO_REPEAT))
                    r = tuneCall2(node.body);
                var en = node;
                if (r != 0) return r;
                if (en.type == BAG_IF_ELSE) {
                    if (en.Then != null) {
                        r = tuneCall2(en.Then);
                        if (r != 0) return r;
                    }
                    if (en.Else != null)
                        r = tuneCall2(en.Else);
                }

            case NODE_CALL:
                if (!node.hasStatus(NODE_ST_IN_ZERO_REPEAT)) {
                    tuneCall2Call(node);
                }

            default:
        }
        return r;
    }

    static function tuneCalledStateCall(node:Node, state:Int):Void {
        switch (node.nodeType) {
            case NODE_ALT, NODE_LIST:
                if (node.nodeType == NODE_ALT) state |= IN_ALT;
                do {
                    tuneCalledStateCall(node.car, state);
                } while ((node = node.cdr) != null);

            case NODE_QUANT:
                var qn = node;
                if (qn.upper == INFINITE_REPEAT || qn.upper >= 2)
                    state |= IN_REAL_REPEAT;
                if (qn.lower != qn.upper)
                    state |= IN_VAR_REPEAT;
                if ((state & IN_PEEK) != 0)
                    node.addStatus(NODE_ST_INPEEK);
                tuneCalledStateCall(qn.body, state);

            case NODE_ANCHOR:
                var an = node;
                switch (an.type) {
                    case ANCR_PREC_READ_NOT, ANCR_LOOK_BEHIND_NOT:
                        state |= (IN_NOT | IN_PEEK);
                        tuneCalledStateCall(an.body, state);
                    case ANCR_PREC_READ, ANCR_LOOK_BEHIND:
                        state |= IN_PEEK;
                        tuneCalledStateCall(an.body, state);
                    default:
                }

            case NODE_BAG:
                var en = node;
                if (en.type == BAG_MEMORY) {
                    if (node.hasStatus(NODE_ST_MARK1)) {
                        if ((~en.calledState & state) != 0) {
                            en.calledState |= state;
                            tuneCalledStateCall(node.body, state);
                        }
                    }
                    else {
                        node.addStatus(NODE_ST_MARK1);
                        en.calledState |= state;
                        tuneCalledStateCall(node.body, state);
                        node.removeStatus(NODE_ST_MARK1);
                    }
                }
                else if (en.type == BAG_IF_ELSE) {
                    state |= IN_ALT;
                    tuneCalledStateCall(node.body, state);
                    if (en.Then != null) {
                        tuneCalledStateCall(en.Then, state);
                    }
                    if (en.Else != null)
                        tuneCalledStateCall(en.Else, state);
                }
                else {
                    tuneCalledStateCall(node.body, state);
                }

            case NODE_CALL:
                if ((state & IN_PEEK) != 0)
                    node.addStatus(NODE_ST_INPEEK);
                if ((state & IN_REAL_REPEAT) != 0)
                    node.addStatus(NODE_ST_IN_REAL_REPEAT);
                tuneCalledStateCall(node.body, state);

            default:
        }
    }

    static function tuneCalledState(node:Node, state:Int):Void {
        switch (node.nodeType) {
            case NODE_ALT, NODE_LIST:
                if (node.nodeType == NODE_ALT) state |= IN_ALT;
                do {
                    tuneCalledState(node.car, state);
                } while ((node = node.cdr) != null);

            case NODE_CALL:
                if ((state & IN_PEEK) != 0)
                    node.addStatus(NODE_ST_INPEEK);
                if ((state & IN_REAL_REPEAT) != 0)
                    node.addStatus(NODE_ST_IN_REAL_REPEAT);
                tuneCalledStateCall(node, state);

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_MEMORY, BAG_OPTION, BAG_STOP_BACKTRACK:
                        if (en.type == BAG_MEMORY) {
                            if (en.entryCount > 1)
                                state |= IN_MULTI_ENTRY;
                            en.calledState |= state;
                        }
                        tuneCalledState(node.body, state);
                    case BAG_IF_ELSE:
                        state |= IN_ALT;
                        tuneCalledState(node.body, state);
                        if (en.Then != null)
                            tuneCalledState(en.Then, state);
                        if (en.Else != null)
                            tuneCalledState(en.Else, state);
                }

            case NODE_QUANT:
                var qn = node;
                if (qn.upper == INFINITE_REPEAT || qn.upper >= 2)
                    state |= IN_REAL_REPEAT;
                if (qn.lower != qn.upper)
                    state |= IN_VAR_REPEAT;
                if ((state & IN_PEEK) != 0)
                    node.addStatus(NODE_ST_INPEEK);
                tuneCalledState(qn.body, state);

            case NODE_ANCHOR:
                var an = node;
                switch (an.type) {
                    case ANCR_PREC_READ_NOT, ANCR_LOOK_BEHIND_NOT:
                        state |= (IN_NOT | IN_PEEK);
                        tuneCalledState(an.body, state);
                    case ANCR_PREC_READ, ANCR_LOOK_BEHIND:
                        state |= IN_PEEK;
                        tuneCalledState(an.body, state);
                    default:
                }

            default:
        }
    }

    static function tuneAnchor(node:Node, reg:Regex, state:Int, env:ParseEnv):Int {
        var r:Int;
        var an = node;
        switch (an.type) {
            case ANCR_PREC_READ:
                r = tuneTree(an.body, reg, (state | IN_PREC_READ), env);
            case ANCR_PREC_READ_NOT:
                r = tuneTree(an.body, reg, (state | IN_PREC_READ | IN_NOT), env);
            case ANCR_LOOK_BEHIND, ANCR_LOOK_BEHIND_NOT:
                r = tuneLookBehind(node, reg, state, env);
            default:
                r = 0;
        }
        return r;
    }

    static inline var EXPAND_STRING_MAX_LENGTH:Int = 100;

    static function tuneQuant(node:Node, reg:Regex, state:Int, env:ParseEnv):Int {
        var r:Int;
        var qn = node;
        var body = node.body;

        if ((state & IN_REAL_REPEAT) != 0) {
            node.addStatus(NODE_ST_IN_REAL_REPEAT);
        }
        if ((state & IN_MULTI_ENTRY) != 0) {
            node.addStatus(NODE_ST_IN_MULTI_ENTRY);
        }

        if (qn.upper == INFINITE_REPEAT || qn.upper >= 1) {
            var d = nodeMinByteLen(body, env);
            if (d == 0) {
                qn.emptiness = quantifiersMemoryNodeInfo(body);
            }
        }

        if (qn.upper == INFINITE_REPEAT || qn.upper >= 2)
            state |= IN_REAL_REPEAT;
        if (qn.lower != qn.upper)
            state |= IN_VAR_REPEAT;

        r = tuneTree(body, reg, state, env);
        if (r != 0) return r;

        /* expand string */
        if (body.nodeType == NODE_STRING) {
            if (qn.lower != INFINITE_REPEAT && qn.lower == qn.upper && qn.lower > 1 && qn.lower <= EXPAND_STRING_MAX_LENGTH) {
                var len = body.strLen();
                if (len * qn.lower <= EXPAND_STRING_MAX_LENGTH) {
                    var n = qn.lower;
                    nodeConvToStrNode(node, body);
                    for (i in 0...n) {
                        r = nodeStrNodeCat(node, body);
                        if (r != 0) return r;
                    }
                    return r;
                }
            }
        }

        if (qn.greedy != 0 && (qn.emptiness == BODY_IS_NOT_EMPTY)) {
            if (body.nodeType == NODE_QUANT) {
                var tqn = body;
                if (tqn.headExact != null) {
                    qn.headExact = tqn.headExact;
                    tqn.headExact = null;
                }
            }
            else {
                qn.headExact = getTreeHeadLiteral(node.body, true, reg);
            }
        }
        return r;
    }

    /* tune_tree does the following work.
     1. check empty loop. (set qn->emptiness)
     2. expand ignore-case in char class.
     3. set memory status bit flags. (reg->mem_stats)
     4. set qn->head_exact for [push, exact] -> [push_or_jump_exact1, exact].
     5. find invalid patterns in look-behind.
     6. expand repeated string.
     */
    static function tuneTree(node:Node, reg:Regex, state:Int, env:ParseEnv):Int {
        var r = 0;
        switch (node.nodeType) {
            case NODE_LIST:
                var prev:Node = null;
                do {
                    r = tuneTree(node.car, reg, state, env);
                    if (prev != null && r == 0) {
                        r = tuneNext(prev, node.car, reg);
                    }
                    prev = node.car;
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_ALT:
                do {
                    r = tuneTree(node.car, reg, (state | IN_ALT), env);
                } while (r == 0 && (node = node.cdr) != null);

            case NODE_STRING:
                if (NODE_IS_REAL_IGNORECASE(node)) {
                    r = unravelCaseFoldString(node, reg, state);
                }

            case NODE_BACKREF:
                var br = node;
                var p = br.backs;
                for (i in 0...br.backNum) {
                    if (p[i] > env.numMem) return ONIGERR_INVALID_BACKREF;
                    env.backrefedMem = MEM_STATUS_ON(env.backrefedMem, p[i]);
                    env.backtrackMem = MEM_STATUS_ON(env.backtrackMem, p[i]);
                }

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_OPTION:
                        var options = reg.options;
                        reg.options = node.options;
                        r = tuneTree(node.body, reg, state, env);
                        reg.options = options;

                    case BAG_MEMORY:
                        state |= en.calledState;
                        if ((state & (IN_ALT | IN_NOT | IN_VAR_REPEAT | IN_MULTI_ENTRY)) != 0 || node.hasStatus(NODE_ST_RECURSION)) {
                            env.backtrackMem = MEM_STATUS_ON(env.backtrackMem, en.regnum);
                        }
                        r = tuneTree(node.body, reg, state, env);

                    case BAG_STOP_BACKTRACK:
                        var target = node.body;
                        r = tuneTree(target, reg, state, env);
                        if (target.nodeType == NODE_QUANT) {
                            var tqn = target;
                            if (tqn.upper == INFINITE_REPEAT && tqn.lower <= 1 && tqn.greedy != 0) { /* (?>a*), a*+ etc... */
                                if (isStrictRealNode(target.body))
                                    node.addStatus(NODE_ST_STRICT_REAL_REPEAT);
                            }
                        }

                    case BAG_IF_ELSE:
                        r = tuneTree(node.body, reg, (state | IN_ALT), env);
                        if (r != 0) return r;
                        if (en.Then != null) {
                            r = tuneTree(en.Then, reg, (state | IN_ALT), env);
                            if (r != 0) return r;
                        }
                        if (en.Else != null)
                            r = tuneTree(en.Else, reg, (state | IN_ALT), env);
                }

            case NODE_QUANT:
                if ((state & (IN_PREC_READ | IN_LOOK_BEHIND)) != 0)
                    node.addStatus(NODE_ST_INPEEK);
                r = tuneQuant(node, reg, state, env);

            case NODE_ANCHOR:
                r = tuneAnchor(node, reg, state, env);

            default:
        }
        return r;
    }

    static function setSundayQuickSearchOrBmhSkipTable(reg:Regex, caseExpand:Bool, sb:Bytes, s:Int, end:Int, skip:Bytes,
            roffset:IntRef):Int {
        var len:Int;
        var items = OnigCaseFoldCodeItem.newArray();
        var buf = Bytes.alloc(ONIGENC_MBC_CASE_FOLD_MAXLEN);

        // ENC_GET_SKIP_OFFSET(UTF-8) == ENC_SKIP_OFFSET_1_OR_0
        var offset:Int = 0;
        var p = s;
        while (true) {
            len = enclen(sb, p);
            if (p + len >= end) {
                if (len == 1) offset = 1;
                else offset = 0;
                break;
            }
            p += len;
        }

        len = end - s;
        if (len + offset >= 255)
            return ONIGERR_PARSER_BUG;

        roffset.v = offset;

        for (i in 0...CHAR_MAP_SIZE) {
            skip.set(i, (len + offset) & 0xff);
        }

        p = s;
        while (p < end) {
            var clen = enclen(sb, p);
            if (p + clen > end) clen = end - p;

            len = end - p;
            for (j in 0...clen) {
                var z = len - j + (offset - 1);
                if (z <= 0) break;
                skip.set(sb.get(p + j), z & 0xff);
            }

            if (caseExpand) {
                var n = Unicode.onigencUnicodeGetCaseFoldCodesByStr(reg.caseFoldFlag, sb, p, end, items);
                for (k in 0...n) {
                    codeToMbc(items[k].code[0], buf, 0);
                    for (j in 0...clen) {
                        var z = len - j + (offset - 1);
                        if (z <= 0) break;
                        if (skip.get(buf.get(j)) > z)
                            skip.set(buf.get(j), z & 0xff);
                    }
                }
            }
            p += clen;
        }
        return 0;
    }

    static inline var OPT_EXACT_MAXLEN:Int = 24;

    static final MAP_POSITION_VALS:Array<Int> = [
        5, 1, 1, 1, 1, 1, 1, 1, 1, 10, 10, 1, 1, 10, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        12, 4, 7, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5,
        6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5, 5, 5, 5, 5,
        5, 6, 6, 6, 6, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
        6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 6, 5, 5, 5,
        5, 6, 6, 6, 6, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
        6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5, 5, 5, 1
    ];

    static function mapPositionValue(i:Int):Int {
        if (i < MAP_POSITION_VALS.length) {
            return MAP_POSITION_VALS[i];
        }
        else
            return 4; /* Take it easy. */
    }

    static final DIST_VALS:Array<Int> = [
        1000, 500, 333, 250, 200, 167, 143, 125, 111, 100,
        91, 83, 77, 71, 67, 63, 59, 56, 53, 50,
        48, 45, 43, 42, 40, 38, 37, 36, 34, 33,
        32, 31, 30, 29, 29, 28, 27, 26, 26, 25,
        24, 24, 23, 23, 22, 22, 21, 21, 20, 20,
        20, 19, 19, 19, 18, 18, 18, 17, 17, 17,
        16, 16, 16, 16, 15, 15, 15, 15, 14, 14,
        14, 14, 14, 14, 13, 13, 13, 13, 13, 13,
        12, 12, 12, 12, 12, 12, 11, 11, 11, 11,
        11, 11, 11, 11, 11, 10, 10, 10, 10, 10
    ];

    static function distanceValue(mm:MinMaxLen):Int {
        /* 1000 / (min-max-dist + 1) */
        if (mm.max == INFINITE_LEN) return 0;
        var d = mm.max - mm.min;
        if (d >= 0 && d < DIST_VALS.length)
            return DIST_VALS[d];
        else
            return 1;
    }

    static function compDistanceValue(d1:MinMaxLen, d2:MinMaxLen, v1:Int, v2:Int):Int {
        if (v2 <= 0) return -1;
        if (v1 <= 0) return 1;

        v1 *= distanceValue(d1);
        v2 *= distanceValue(d2);

        if (v2 > v1) return 1;
        if (v2 < v1) return -1;

        if (d2.min < d1.min) return 1;
        if (d2.min > d1.min) return -1;
        return 0;
    }

    static function concatOptAncInfo(to:OptAnc, left:OptAnc, right:OptAnc, leftLen:Int, rightLen:Int):Void {
        to.left = 0;
        to.right = 0;
        to.left = left.left;
        if (leftLen == 0) {
            to.left |= right.left;
        }
        to.right = right.right;
        if (rightLen == 0) {
            to.right |= left.right;
        }
        else {
            to.right |= (left.right & ANCR_PREC_READ_NOT);
        }
    }

    static function isLeft(a:Int):Bool {
        if (a == ANCR_END_BUF || a == ANCR_SEMI_END_BUF || a == ANCR_END_LINE || a == ANCR_PREC_READ || a == ANCR_PREC_READ_NOT)
            return false;
        return true;
    }

    static function isSetOptAncInfo(to:OptAnc, anc:Int):Bool {
        if ((to.left & anc) != 0) return true;
        return (to.right & anc) != 0;
    }

    static function addOptAncInfo(to:OptAnc, anc:Int):Void {
        if (isLeft(anc))
            to.left |= anc;
        else
            to.right |= anc;
    }

    static function removeOptAncInfo(to:OptAnc, anc:Int):Void {
        if (isLeft(anc))
            to.left &= ~anc;
        else
            to.right &= ~anc;
    }

    static function altMergeOptAncInfo(to:OptAnc, add:OptAnc):Void {
        to.left &= add.left;
        to.right &= add.right;
    }

    static inline function isFullOptExact(e:OptStr):Bool {
        return e.len >= OPT_EXACT_MAXLEN;
    }

    static function clearOptExact(e:OptStr):Void {
        mmlClear(e.mm);
        e.anc.left = 0;
        e.anc.right = 0;
        e.reachEnd = false;
        e.len = 0;
        e.s.set(0, 0);
    }

    static function concatOptExact(to:OptStr, add:OptStr):Int {
        var r = 0;
        var p = 0;
        var end = add.len;
        var i = to.len;
        while (p < end) {
            var len = EncLen_UTF8[add.s.get(p)];
            if (i + len > OPT_EXACT_MAXLEN) {
                r = 1; /* 1:full */
                break;
            }
            var j = 0;
            while (j < len && p < end) {
                to.s.set(i++, add.s.get(p++));
                j++;
            }
        }
        to.len = i;
        to.reachEnd = (p == end ? add.reachEnd : false);

        var tanc = new OptAnc();
        concatOptAncInfo(tanc, to.anc, add.anc, 1, 1);
        if (!to.reachEnd) tanc.right = 0;
        to.anc.copyFrom(tanc);
        return r;
    }

    static function concatOptExactStr(to:OptStr, sb:Bytes, s:Int, end:Int):Void {
        var i = to.len;
        var p = s;
        while (p < end && i < OPT_EXACT_MAXLEN) {
            var len = enclen(sb, p);
            if (i + len > OPT_EXACT_MAXLEN) break;
            var j = 0;
            while (j < len && p < end) {
                to.s.set(i++, sb.get(p++));
                j++;
            }
        }
        to.len = i;
        if (p >= end)
            to.reachEnd = true;
    }

    static function altMergeOptExact(to:OptStr, add:OptStr, env:OptEnv):Void {
        if (add.len == 0 || to.len == 0) {
            clearOptExact(to);
            return;
        }
        if (!mmlIsEqual(to.mm, add.mm)) {
            clearOptExact(to);
            return;
        }

        var i = 0;
        while (i < to.len && i < add.len) {
            if (to.s.get(i) != add.s.get(i)) break;
            var len = EncLen_UTF8[to.s.get(i)];
            var j = 1;
            while (j < len) {
                if (to.s.get(i + j) != add.s.get(i + j)) break;
                j++;
            }
            if (j < len) break;
            i += len;
        }

        if (!add.reachEnd || i < add.len || i < to.len) {
            to.reachEnd = false;
        }
        to.len = i;

        altMergeOptAncInfo(to.anc, add.anc);
        if (!to.reachEnd) to.anc.right = 0;
    }

    static function selectOptExact(now:OptStr, alt:OptStr):Void {
        var vn = now.len;
        var va = alt.len;

        if (va == 0) {
            return;
        }
        else if (vn == 0) {
            now.copyFrom(alt);
            return;
        }
        else if (vn <= 2 && va <= 2) {
            /* ByteValTable[x] is big value --> low price */
            va = mapPositionValue(now.s.get(0));
            vn = mapPositionValue(alt.s.get(0));

            if (now.len > 1) vn += 5;
            if (alt.len > 1) va += 5;
        }

        vn *= 2;
        va *= 2;

        if (compDistanceValue(now.mm, alt.mm, vn, va) > 0)
            now.copyFrom(alt);
    }

    static function clearOptMap(map:OptMap):Void {
        map.mm.min = 0;
        map.mm.max = 0;
        map.anc.left = 0;
        map.anc.right = 0;
        map.value = 0;
        for (i in 0...CHAR_MAP_SIZE) map.map[i] = 0;
    }

    static function addCharOptMap(m:OptMap, c:Int):Void {
        if (m.map[c] == 0) {
            m.map[c] = 1;
            m.value += mapPositionValue(c);
        }
    }

    static function selectOptMap(now:OptMap, alt:OptMap):Void {
        var z = 1 << 15; /* 32768: something big value */
        if (alt.value == 0) return;
        if (now.value == 0) {
            now.copyFrom(alt);
            return;
        }
        var vn = Std.int(z / now.value);
        var va = Std.int(z / alt.value);
        if (compDistanceValue(now.mm, alt.mm, vn, va) > 0)
            now.copyFrom(alt);
    }

    static function compOptExactOrMap(e:OptStr, m:OptMap):Int {
        var COMP_EM_BASE = 20;
        if (m.value <= 0) return -1;
        var caseValue = 3;
        var ae = COMP_EM_BASE * e.len * caseValue;
        var am = Std.int(COMP_EM_BASE * 5 * 2 / m.value);
        return compDistanceValue(e.mm, m.mm, ae, am);
    }

    static function altMergeOptMap(to:OptMap, add:OptMap):Void {
        if (to.value == 0) return;
        if (add.value == 0 || to.mm.max < add.mm.min) {
            clearOptMap(to);
            return;
        }

        mmlAltMerge(to.mm, add.mm);

        var val = 0;
        for (i in 0...CHAR_MAP_SIZE) {
            if (add.map[i] != 0)
                to.map[i] = 1;
            if (to.map[i] != 0)
                val += mapPositionValue(i);
        }
        to.value = val;

        altMergeOptAncInfo(to.anc, add.anc);
    }

    static function setBoundNodeOptInfo(opt:OptNode, plen:MinMaxLen):Void {
        mmlCopy(opt.sb.mm, plen);
        mmlCopy(opt.spr.mm, plen);
        mmlCopy(opt.map.mm, plen);
    }

    static function clearNodeOptInfo(opt:OptNode):Void {
        mmlClear(opt.len);
        opt.anc.left = 0;
        opt.anc.right = 0;
        clearOptExact(opt.sb);
        clearOptExact(opt.sm);
        clearOptExact(opt.spr);
        clearOptMap(opt.map);
    }

    static function concatLeftNodeOptInfo(to:OptNode, add:OptNode):Void {
        var tanc = new OptAnc();

        concatOptAncInfo(tanc, to.anc, add.anc, to.len.max, add.len.max);
        to.anc.copyFrom(tanc);

        if (add.sb.len > 0 && to.len.max == 0) {
            concatOptAncInfo(tanc, to.anc, add.sb.anc, to.len.max, add.len.max);
            add.sb.anc.copyFrom(tanc);
        }

        if (add.map.value > 0 && to.len.max == 0) {
            if (add.map.mm.max == 0)
                add.map.anc.left |= to.anc.left;
        }

        var sbReach = to.sb.reachEnd;
        var smReach = to.sm.reachEnd;

        if (add.len.max != 0)
            to.sb.reachEnd = to.sm.reachEnd = false;

        if (add.sb.len > 0) {
            if (sbReach) {
                concatOptExact(to.sb, add.sb);
                clearOptExact(add.sb);
            }
            else if (smReach) {
                concatOptExact(to.sm, add.sb);
                clearOptExact(add.sb);
            }
        }
        selectOptExact(to.sm, add.sb);
        selectOptExact(to.sm, add.sm);

        if (to.spr.len > 0) {
            if (add.len.max > 0) {
                if (to.spr.mm.max == 0)
                    selectOptExact(to.sb, to.spr);
                else
                    selectOptExact(to.sm, to.spr);
            }
        }
        else if (add.spr.len > 0) {
            to.spr.copyFrom(add.spr);
        }

        selectOptMap(to.map, add.map);
        mmlAdd(to.len, add.len);
    }

    static function altMergeNodeOptInfo(to:OptNode, add:OptNode, env:OptEnv):Void {
        altMergeOptAncInfo(to.anc, add.anc);
        altMergeOptExact(to.sb, add.sb, env);
        altMergeOptExact(to.sm, add.sm, env);
        altMergeOptExact(to.spr, add.spr, env);
        altMergeOptMap(to.map, add.map);
        mmlAltMerge(to.len, add.len);
    }

    static function nodeMaxByteLen(node:Node, env:ParseEnv):Int {
        var len = 0;
        var tmax:Int;
        switch (node.nodeType) {
            case NODE_LIST:
                do {
                    tmax = nodeMaxByteLen(node.car, env);
                    len = distanceAdd(len, tmax);
                } while ((node = node.cdr) != null);

            case NODE_ALT:
                do {
                    tmax = nodeMaxByteLen(node.car, env);
                    if (len < tmax) len = tmax;
                } while ((node = node.cdr) != null);

            case NODE_STRING:
                len = node.end - node.s;

            case NODE_CTYPE, NODE_CCLASS:
                len = ONIGENC_MBC_MAXLEN;

            case NODE_BACKREF:
                if (!node.hasStatus(NODE_ST_CHECKER)) {
                    var memEnv = env.memEnv;
                    var br = node;
                    if (node.hasStatus(NODE_ST_RECURSION)) {
                        if (node.hasStatus(NODE_ST_NEST_LEVEL)) {
                            len = INFINITE_LEN;
                        }
                    }
                    else {
                        var backs = br.backs;
                        for (i in 0...br.backNum) {
                            tmax = nodeMaxByteLen(memEnv[backs[i]].memNode, env);
                            if (len < tmax) len = tmax;
                        }
                    }
                }

            case NODE_CALL:
                if (!node.hasStatus(NODE_ST_RECURSION))
                    len = nodeMaxByteLen(node.body, env);
                else
                    len = INFINITE_LEN;

            case NODE_QUANT:
                var qn = node;
                if (qn.upper != 0) {
                    len = nodeMaxByteLen(node.body, env);
                    if (len != 0) {
                        if (qn.upper != INFINITE_REPEAT)
                            len = distanceMultiply(len, qn.upper);
                        else
                            len = INFINITE_LEN;
                    }
                }

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_MEMORY:
                        if (node.hasStatus(NODE_ST_FIXED_MAX))
                            len = en.maxLen;
                        else {
                            if (node.hasStatus(NODE_ST_MARK1))
                                len = INFINITE_LEN;
                            else {
                                node.addStatus(NODE_ST_MARK1);
                                len = nodeMaxByteLen(node.body, env);
                                node.removeStatus(NODE_ST_MARK1);
                                en.maxLen = len;
                                node.addStatus(NODE_ST_FIXED_MAX);
                            }
                        }
                    case BAG_OPTION, BAG_STOP_BACKTRACK:
                        len = nodeMaxByteLen(node.body, env);
                    case BAG_IF_ELSE:
                        var elen:Int;
                        len = nodeMaxByteLen(node.body, env);
                        if (en.Then != null) {
                            var tlen = nodeMaxByteLen(en.Then, env);
                            len = distanceAdd(len, tlen);
                        }
                        if (en.Else != null)
                            elen = nodeMaxByteLen(en.Else, env);
                        else elen = 0;
                        if (elen > len) len = elen;
                }

            default:
        }
        return len;
    }

    static inline var MAX_NODE_OPT_INFO_REF_COUNT:Int = 5;

    static function optimizeNodes(node:Node, opt:OptNode, env:OptEnv):Int {
        var r = 0;
        var xo:OptNode = null;
        clearNodeOptInfo(opt);
        setBoundNodeOptInfo(opt, env.mm);

        switch (node.nodeType) {
            case NODE_LIST:
                xo = new OptNode();
                var nenv = new OptEnv();
                nenv.copyFrom(env);
                var nd = node;
                do {
                    r = optimizeNodes(nd.car, xo, nenv);
                    if (r == 0) {
                        mmlAdd(nenv.mm, xo.len);
                        concatLeftNodeOptInfo(opt, xo);
                    }
                } while (r == 0 && (nd = nd.cdr) != null);

            case NODE_ALT:
                xo = new OptNode();
                var nd = node;
                do {
                    r = optimizeNodes(nd.car, xo, env);
                    if (r == 0) {
                        if (nd == node) opt.copyFrom(xo);
                        else altMergeNodeOptInfo(opt, xo, env);
                    }
                } while ((r == 0) && (nd = nd.cdr) != null);

            case NODE_STRING:
                var slen = node.end - node.s;
                concatOptExactStr(opt.sb, node.sbuf, node.s, node.end);
                if (slen > 0) {
                    addCharOptMap(opt.map, node.sbuf.get(node.s));
                }
                mmlSetMinMax(opt.len, slen, slen);

            case NODE_CCLASS:
                var cc = node;
                /* no need to check ignore case. (set in tune_tree()) */
                if (cc.mbuf != null || cc.isNcclassNot()) {
                    mmlSetMinMax(opt.len, ONIGENC_MBC_MINLEN, ONIGENC_MBC_MAXLEN);
                }
                else {
                    for (i in 0...SINGLE_BYTE_SIZE) {
                        var z = BITSET_AT(cc.bs, i);
                        if ((z && !cc.isNcclassNot()) || (!z && cc.isNcclassNot())) {
                            addCharOptMap(opt.map, i);
                        }
                    }
                    mmlSetMinMax(opt.len, 1, 1);
                }

            case NODE_CTYPE:
                // ONIGENC_MBC_MAXLEN_DIST(UTF-8) is 4: no map
                mmlSetMinMax(opt.len, ONIGENC_MBC_MINLEN, ONIGENC_MBC_MAXLEN);

            case NODE_ANCHOR:
                switch (node.type) {
                    case ANCR_BEGIN_BUF, ANCR_BEGIN_POSITION, ANCR_BEGIN_LINE, ANCR_END_BUF, ANCR_SEMI_END_BUF, ANCR_END_LINE,
                        ANCR_PREC_READ_NOT, ANCR_LOOK_BEHIND:
                        addOptAncInfo(opt.anc, node.type);

                    case ANCR_PREC_READ:
                        xo = new OptNode();
                        r = optimizeNodes(node.body, xo, env);
                        if (r == 0) {
                            if (xo.sb.len > 0)
                                opt.spr.copyFrom(xo.sb);
                            else if (xo.sm.len > 0)
                                opt.spr.copyFrom(xo.sm);
                            opt.spr.reachEnd = false;
                            if (xo.map.value > 0)
                                opt.map.copyFrom(xo.map);
                        }

                    case ANCR_LOOK_BEHIND_NOT:
                    default:
                }

            case NODE_BACKREF:
                if (!node.hasStatus(NODE_ST_CHECKER)) {
                    var min = nodeMinByteLen(node, env.scanEnv);
                    var max = nodeMaxByteLen(node, env.scanEnv);
                    mmlSetMinMax(opt.len, min, max);
                }

            case NODE_CALL:
                if (node.hasStatus(NODE_ST_RECURSION))
                    mmlSetMinMax(opt.len, 0, INFINITE_LEN);
                else {
                    r = optimizeNodes(node.body, opt, env);
                }

            case NODE_QUANT:
                var min:Int;
                var max:Int;
                var qn = node;
                /* Issue #175 */
                if (qn.upper == 0) {
                    mmlSetMinMax(opt.len, 0, 0);
                }
                else {
                    xo = new OptNode();
                    r = optimizeNodes(node.body, xo, env);
                    if (r == 0) {
                        if (qn.lower > 0) {
                            opt.copyFrom(xo);
                            if (xo.sb.len > 0) {
                                if (xo.sb.reachEnd) {
                                    var i = 2;
                                    while (i <= qn.lower && !isFullOptExact(opt.sb)) {
                                        var rc = concatOptExact(opt.sb, xo.sb);
                                        if (rc > 0) break;
                                        i++;
                                    }
                                    if (i < qn.lower) opt.sb.reachEnd = false;
                                }
                            }
                            if (qn.lower != qn.upper) {
                                opt.sb.reachEnd = false;
                                opt.sm.reachEnd = false;
                            }
                            if (qn.lower > 1)
                                opt.sm.reachEnd = false;
                        }

                        if (qn.upper == INFINITE_REPEAT) {
                            if (env.mm.max == 0 && node.body.isAnychar() && qn.greedy != 0) {
                                if (qn.body.hasStatus(NODE_ST_MULTILINE))
                                    addOptAncInfo(opt.anc, ANCR_ANYCHAR_INF_ML);
                                else
                                    addOptAncInfo(opt.anc, ANCR_ANYCHAR_INF);
                            }
                            max = (xo.len.max > 0 ? INFINITE_LEN : 0);
                        }
                        else {
                            max = distanceMultiply(xo.len.max, qn.upper);
                        }
                        min = distanceMultiply(xo.len.min, qn.lower);
                        mmlSetMinMax(opt.len, min, max);
                    }
                }

            case NODE_BAG:
                var en = node;
                switch (en.type) {
                    case BAG_STOP_BACKTRACK, BAG_OPTION:
                        r = optimizeNodes(node.body, opt, env);

                    case BAG_MEMORY:
                        en.optCount++;
                        if (en.optCount > MAX_NODE_OPT_INFO_REF_COUNT) {
                            var min = 0;
                            var max = INFINITE_LEN;
                            if (node.hasStatus(NODE_ST_FIXED_MIN)) min = en.minLen;
                            if (node.hasStatus(NODE_ST_FIXED_MAX)) max = en.maxLen;
                            mmlSetMinMax(opt.len, min, max);
                        }
                        else {
                            r = optimizeNodes(node.body, opt, env);
                            if (isSetOptAncInfo(opt.anc, ANCR_ANYCHAR_INF_MASK)) {
                                if (MEM_STATUS_AT0(env.scanEnv.backrefedMem, en.regnum))
                                    removeOptAncInfo(opt.anc, ANCR_ANYCHAR_INF_MASK);
                            }
                        }

                    case BAG_IF_ELSE:
                        if (en.Else != null) {
                            xo = new OptNode();
                            var nenv = new OptEnv();
                            nenv.copyFrom(env);
                            r = optimizeNodes(en.body, xo, nenv);
                            if (r == 0) {
                                mmlAdd(nenv.mm, xo.len);
                                concatLeftNodeOptInfo(opt, xo);
                                if (en.Then != null) {
                                    r = optimizeNodes(en.Then, xo, nenv);
                                    if (r == 0) {
                                        concatLeftNodeOptInfo(opt, xo);
                                    }
                                }
                                r = optimizeNodes(en.Else, xo, env);
                                if (r == 0)
                                    altMergeNodeOptInfo(opt, xo, env);
                            }
                        }
                }

            case NODE_GIMMICK:

            default:
                r = ONIGERR_TYPE_BUG;
        }
        return r;
    }

    static function setOptimizeExact(reg:Regex, e:OptStr):Int {
        if (e.len == 0) return 0;

        reg.exact = Bytes.alloc(e.len);
        reg.exact.blit(0, e.s, 0, e.len);
        reg.exactStart = 0;
        reg.exactEnd = e.len;

        var allowReverse = true; // ONIGENC_IS_ALLOWED_REVERSE_MATCH(UTF-8)

        if (e.len >= 2 || (e.len >= 1 && allowReverse)) {
            var mo = new IntRef();
            if (reg.map == null) reg.map = Bytes.alloc(CHAR_MAP_SIZE);
            var r = setSundayQuickSearchOrBmhSkipTable(reg, false, reg.exact, 0, reg.exactEnd, reg.map, mo);
            if (r != 0) return r;
            reg.mapOffset = mo.v;
            reg.optimize = (allowReverse ? OPTIMIZE_STR_FAST : OPTIMIZE_STR_FAST_STEP_FORWARD);
        }
        else {
            reg.optimize = OPTIMIZE_STR;
        }

        reg.distMin = e.mm.min;
        reg.distMax = e.mm.max;

        if (reg.distMin != INFINITE_LEN) {
            var n = reg.exactEnd - reg.exactStart;
            reg.thresholdLen = reg.distMin + n;
        }
        return 0;
    }

    static function setOptimizeMap(reg:Regex, m:OptMap):Void {
        if (reg.map == null) reg.map = Bytes.alloc(CHAR_MAP_SIZE);
        for (i in 0...CHAR_MAP_SIZE)
            reg.map.set(i, m.map[i]);
        reg.optimize = OPTIMIZE_MAP;
        reg.distMin = m.mm.min;
        reg.distMax = m.mm.max;
        if (reg.distMin != INFINITE_LEN) {
            reg.thresholdLen = reg.distMin + ONIGENC_MBC_MINLEN;
        }
    }

    static function setSubAnchor(reg:Regex, anc:OptAnc):Void {
        reg.subAnchor |= anc.left & ANCR_BEGIN_LINE;
        reg.subAnchor |= anc.right & ANCR_END_LINE;
    }

    static function setOptimizeInfoFromTree(node:Node, reg:Regex, scanEnv:ParseEnv):Int {
        var r:Int;
        var opt = new OptNode();
        var env = new OptEnv();

        env.caseFoldFlag = reg.caseFoldFlag;
        env.scanEnv = scanEnv;
        mmlClear(env.mm);

        r = optimizeNodes(node, opt, env);
        if (r != 0) return r;

        reg.anchor = opt.anc.left & (ANCR_BEGIN_BUF | ANCR_BEGIN_POSITION | ANCR_ANYCHAR_INF | ANCR_ANYCHAR_INF_ML | ANCR_LOOK_BEHIND);

        if ((opt.anc.left & (ANCR_LOOK_BEHIND | ANCR_PREC_READ_NOT)) != 0)
            reg.anchor &= ~ANCR_ANYCHAR_INF_ML;

        reg.anchor |= opt.anc.right & (ANCR_END_BUF | ANCR_SEMI_END_BUF | ANCR_PREC_READ_NOT);

        if ((reg.anchor & (ANCR_END_BUF | ANCR_SEMI_END_BUF)) != 0) {
            reg.ancDistMin = opt.len.min;
            reg.ancDistMax = opt.len.max;
        }

        var setMap = false;
        if (opt.sb.len > 0 || opt.sm.len > 0) {
            selectOptExact(opt.sb, opt.sm);
            if (opt.map.value > 0 && compOptExactOrMap(opt.sb, opt.map) > 0) {
                setMap = true;
            }
            else {
                r = setOptimizeExact(reg, opt.sb);
                setSubAnchor(reg, opt.sb.anc);
            }
        }
        else if (opt.map.value > 0) {
            setMap = true;
        }
        else {
            reg.subAnchor |= opt.anc.left & ANCR_BEGIN_LINE;
            if (opt.len.max == 0)
                reg.subAnchor |= opt.anc.right & ANCR_END_LINE;
        }
        if (setMap) {
            setOptimizeMap(reg, opt.map);
            setSubAnchor(reg, opt.map.anc);
        }
        return r;
    }

    static function clearOptimizeInfo(reg:Regex):Void {
        reg.optimize = OPTIMIZE_NONE;
        reg.anchor = 0;
        reg.ancDistMin = 0;
        reg.ancDistMax = 0;
        reg.subAnchor = 0;
        reg.exactEnd = 0;
        reg.mapOffset = 0;
        reg.thresholdLen = 0;
        reg.exact = null;
    }

    public static inline var OP_STRIDE:Int = 5;

    /**
     * Packs the operations into flat integer arrays (OP_STRIDE ints per operation):
     *   [0] opcode, [1] x, [2] y, [3] z, [4] w
     * x: addr, n (chars of a string), mode, type, n1, move.n, mem (empty check id), bitset offset
     * y: len (char byte length), c, not, num, id, initial, code range index
     * z: string offset, nest_level, empty_status_mem, remaining, flag (save_pos, restore_pos, clear), callout name id
     * w: backref list offset
     * Strings go to one string pool (ops_make_string_pool of regcomp.c), bitsets and
     * backref lists to an int pool, code ranges are shared between identical ones.
     */
    static function packOps(reg:Regex):Void {
        var ops = reg.ops;
        var n = ops.length;
        var code = new IntArray(n * OP_STRIDE);
        var strLen = 0;
        var intLen = 0;
        for (op in ops) {
            if (op.s != null) strLen += op.s.length;
            if (op.bsp != null) intLen += BITSET_REAL_SIZE;
            if (op.ns != null) intLen += op.ns.length;
        }
        var strPool = strLen > 0 ? Bytes.alloc(strLen) : null;
        var intPool = intLen > 0 ? new IntArray(intLen) : null;
        var ranges:Array<IntArray> = null;
        var sp = 0;
        var ip = 0;
        for (i in 0...n) {
            var op = ops[i];
            var b = i * OP_STRIDE;
            var oc = op.opcode;
            code[b] = oc;
            var x = 0, y = 0, z = 0, w = 0;
            switch (oc) {
                case OP_STR_1, OP_STR_2, OP_STR_3, OP_STR_4, OP_STR_5, OP_STR_N, OP_STR_MB2N1, OP_STR_MB2N2, OP_STR_MB2N3, OP_STR_MB2N,
                    OP_STR_MB3N, OP_STR_MBN:
                    x = op.n;
                    y = op.len;
                    z = sp;
                    strPool.blit(sp, op.s, 0, op.s.length);
                    sp += op.s.length;
                case OP_CCLASS, OP_CCLASS_NOT, OP_CCLASS_MB, OP_CCLASS_MB_NOT, OP_CCLASS_MIX, OP_CCLASS_MIX_NOT:
                    if (op.bsp != null) {
                        x = ip;
                        for (k in 0...BITSET_REAL_SIZE) intPool[ip++] = op.bsp[k];
                    }
                    if (op.mb != null) {
                        if (ranges == null) ranges = [];
                        y = ranges.length;
                        ranges.push(internCodeRange(op.mb));
                    }
                case OP_ANYCHAR_STAR_PEEK_NEXT, OP_ANYCHAR_ML_STAR_PEEK_NEXT:
                    y = op.c;
                case OP_WORD_BOUNDARY, OP_NO_WORD_BOUNDARY, OP_WORD_BEGIN, OP_WORD_END:
                    x = op.mode;
                case OP_TEXT_SEGMENT_BOUNDARY:
                    x = op.type;
                    y = op.not;
                case OP_CHECK_POSITION:
                    x = op.type;
                case OP_BACKREF_N, OP_BACKREF_N_IC:
                    x = op.n1;
                case OP_BACKREF_MULTI, OP_BACKREF_MULTI_IC, OP_BACKREF_WITH_LEVEL, OP_BACKREF_WITH_LEVEL_IC, OP_BACKREF_CHECK,
                    OP_BACKREF_CHECK_WITH_LEVEL:
                    x = op.n1;
                    y = op.num;
                    z = op.nestLevel;
                    w = ip;
                    if (op.ns != null) for (k in op.ns) intPool[ip++] = k;
                case OP_MEM_START, OP_MEM_START_PUSH, OP_MEM_END_PUSH, OP_MEM_END_PUSH_REC, OP_MEM_END, OP_MEM_END_REC:
                    y = op.num;
                case OP_EMPTY_CHECK_START, OP_EMPTY_CHECK_END, OP_EMPTY_CHECK_END_MEMST, OP_EMPTY_CHECK_END_MEMST_PUSH:
                    x = op.mem;
                    z = op.emptyStatusMem;
                case OP_JUMP, OP_PUSH, OP_PUSH_SUPER, OP_CALL:
                    x = op.addr;
                case OP_PUSH_OR_JUMP_EXACT1, OP_PUSH_IF_PEEK_NEXT:
                    x = op.addr;
                    y = op.c;
                case OP_POP_TO_MARK, OP_REPEAT_INC, OP_REPEAT_INC_NG:
                    y = op.id;
                case OP_REPEAT, OP_REPEAT_NG:
                    x = op.addr;
                    y = op.id;
                case OP_MOVE:
                    x = op.moveN;
                case OP_STEP_BACK_START:
                    x = op.addr;
                    y = op.initial;
                    z = op.remaining;
                case OP_CUT_TO_MARK, OP_MARK:
                    y = op.id;
                    z = op.flagv;
                case OP_SAVE_VAL:
                    x = op.type;
                    y = op.id;
                case OP_UPDATE_VAR:
                    x = op.type;
                    y = op.id;
                    z = op.flagv;
                case OP_CALLOUT_NAME:
                    y = op.num;
                    z = op.id;
                case OP_CALLOUT_CONTENTS:
                    y = op.num;
                default:
            }
            code[b + 1] = x;
            code[b + 2] = y;
            code[b + 3] = z;
            code[b + 4] = w;
        }
        reg.code = code;
        reg.strPool = strPool;
        reg.intPool = intPool;
        reg.ranges = ranges;
        reg.ops = null;
    }

    static var internedRanges:Map<Int, Array<IntArray>> = new Map();
    static var internedCount:Int = 0;
    static inline var MAX_INTERNED_RANGES:Int = 8192;

    /**
     * Shares identical code ranges between the compiled regexes (they are never
     * modified). The table keeps at most MAX_INTERNED_RANGES ranges.
     */
    static function internCodeRange(mb:Array<Int>):IntArray {
        var h = 0x811c9dc5;
        for (v in mb) h = (h ^ v) * 16777619;
        var list = internedRanges.get(h);
        if (list != null) {
            for (r in list) {
                if (r.length == mb.length) {
                    var same = true;
                    for (k in 0...mb.length) {
                        if (r[k] != mb[k]) {
                            same = false;
                            break;
                        }
                    }
                    if (same) return r;
                }
            }
        }
        var r = IntArray.fromArray(mb);
        if (internedCount < MAX_INTERNED_RANGES) {
            if (list == null) {
                list = [];
                internedRanges.set(h, list);
            }
            list.push(r);
            internedCount++;
        }
        return r;
    }

    public static function onigGetRegexExt(reg:Regex):RegexExt {
        if (reg.extp == null) {
            reg.extp = new RegexExt();
        }
        return reg.extp;
    }

    public static function onigExtSetPattern(reg:Regex, pattern:Bytes, start:Int, end:Int):Int {
        var ext = onigGetRegexExt(reg);
        ext.pattern = pattern.sub(start, end - start);
        ext.patternStart = 0;
        ext.patternEnd = end - start;
        return ONIG_NORMAL;
    }

    static function parseAndTune(reg:Regex, pattern:Bytes, start:Int, end:Int, scanEnv:ParseEnv, rroot:NodeRef, einfo:OnigErrorInfo):Int {
        var r:Int;
        var root = new NodeRef();

        if (einfo != null) {
            einfo.par = -1;
        }

        do {
            r = Regparse.onigParseTree(root, pattern, start, end, reg, scanEnv);
            if (r != 0) break;

            if ((scanEnv.flags & Regparse.PE_FLAG_HAS_WHOLE_OPTIONS) != 0) {
                r = checkWholeOptionsPosition(root.v);
                if (r != 0) break;
            }

            r = reduceStringList(root.v);
            if (r != 0) break;

            /* mixed use named group and no-named group */
            if (scanEnv.numNamed > 0 && IS_SYNTAX_BV(scanEnv.syntax, ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)
                    && !OPTON_CAPTURE_GROUP(reg.options)) {
                if (scanEnv.numNamed != scanEnv.numMem)
                    r = disableNonameGroupCapture(root, reg, scanEnv);
                else
                    r = numberedRefCheck(root.v);
                if (r != 0) break;
            }

            r = checkBackrefs(root.v, scanEnv);
            if (r != 0) break;

            if (scanEnv.numCall > 0) {
                scanEnv.unsetAddrList = [];
                r = tuneCall(root.v, scanEnv, 0);
                if (r != 0) break;
                r = tuneCall2(root.v);
                if (r != 0) break;
                r = recursiveCallCheckTrav(root.v, scanEnv, 0);
                if (r < 0) break;
                r = infiniteRecursiveCallCheckTrav(root.v, scanEnv);
                if (r != 0) break;
                tuneCalledState(root.v, 0);
            }

            reg.numCall = scanEnv.numCall;

            r = tuneTree(root.v, reg, 0, scanEnv);
            if (r != 0) break;

            if (scanEnv.backrefNum != 0) {
                setParentNodeTrav(root.v, null);
                r = setEmptyRepeatNodeTrav(root.v, null, scanEnv);
                if (r != 0) break;
                setEmptyStatusCheckTrav(root.v, scanEnv);
            }

            rroot.v = root.v;
            return r;
        } while (false);

        // err:
        if (scanEnv.error != -1) {
            if (einfo != null) {
                einfo.pattern = scanEnv.errorBytes;
                einfo.par = scanEnv.error;
                einfo.parEnd = scanEnv.errorEnd;
            }
        }
        rroot.v = null;
        return r;
    }

    public static function onigCompile(reg:Regex, pattern:Bytes, start:Int, end:Int, einfo:OnigErrorInfo):Int {
        var r:Int;
        var root = new NodeRef();
        var scanEnv = new ParseEnv();

        r = opsInit(reg, 8);
        if (r != 0) return r;

        r = parseAndTune(reg, pattern, start, end, scanEnv, root, einfo);
        if (r != 0) return r;

        reg.captureHistory = scanEnv.capHistory;
        reg.pushMemStart = scanEnv.backtrackMem | scanEnv.capHistory;

        if (reg.extp != null && reg.extp.calloutNum != 0) {
            reg.pushMemEnd = reg.pushMemStart;
        }
        else {
            if (MEM_STATUS_IS_ALL_ON(reg.pushMemStart))
                reg.pushMemEnd = scanEnv.backrefedMem | scanEnv.capHistory;
            else
                reg.pushMemEnd = reg.pushMemStart & (scanEnv.backrefedMem | scanEnv.capHistory);
        }

        clearOptimizeInfo(reg);
        r = setOptimizeInfoFromTree(root.v, reg, scanEnv);
        if (r == 0) {
            r = compileTree(root.v, reg, scanEnv);
        }
        if (r == 0) {
            if (scanEnv.keepNum > 0) {
                r = addOp(reg, OP_UPDATE_VAR);
                if (r != 0) return r;
                COP(reg).type = UPDATE_VAR_KEEP_FROM_STACK_LAST;
                COP(reg).id = 0; /* not used */
                COP(reg).flagv = 0;
            }

            r = addOp(reg, OP_END);
            if (r != 0) return r;

            if (scanEnv.numCall > 0) {
                r = fixUnsetAddrList(scanEnv.unsetAddrList, reg);
                if (r != 0) return r;
            }

            setAddrInRepeatRange(reg);

            if (reg.pushMemEnd != 0 || (reg.extp != null && reg.extp.calloutNum != 0) || scanEnv.numCall > 0)
                reg.stackPopLevel = STACK_POP_LEVEL_ALL;
            else {
                if (reg.pushMemStart != 0)
                    reg.stackPopLevel = STACK_POP_LEVEL_MEM_START;
                else
                    reg.stackPopLevel = STACK_POP_LEVEL_FREE;
            }

            // FinishCode of match_at: a FINISH operation after the program
            var fin = new Operation();
            fin.opcode = OP_FINISH;
            reg.finishIndex = reg.ops.length;
            reg.ops.push(fin);
            packOps(reg);
            return 0;
        }

        // err:
        if (scanEnv.error != -1) {
            if (einfo != null) {
                einfo.pattern = scanEnv.errorBytes;
                einfo.par = scanEnv.error;
                einfo.parEnd = scanEnv.errorEnd;
            }
        }
        return r;
    }

}

/** OptAnc */
class OptAnc {
    public var left:Int = 0;
    public var right:Int = 0;
    public function new() {}
    public inline function copyFrom(f:OptAnc):Void {
        left = f.left;
        right = f.right;
    }
}

/** OptStr */
class OptStr {
    public var mm:MinMaxLen;
    public var anc:OptAnc;
    public var reachEnd:Bool = false;
    public var len:Int = 0;
    public var s:Bytes;
    public function new() {
        mm = new MinMaxLen();
        anc = new OptAnc();
        s = Bytes.alloc(24);
    }
    public function copyFrom(f:OptStr):Void {
        mm.copyFrom(f.mm);
        anc.copyFrom(f.anc);
        reachEnd = f.reachEnd;
        len = f.len;
        s.blit(0, f.s, 0, 24);
    }
}

/** OptMap */
class OptMap {
    public var mm:MinMaxLen;
    public var anc:OptAnc;
    public var value:Int = 0;
    public var map:Vector<Int>;
    public function new() {
        mm = new MinMaxLen();
        anc = new OptAnc();
        map = new Vector<Int>(256);
        for (i in 0...256) map[i] = 0;
    }
    public function copyFrom(f:OptMap):Void {
        mm.copyFrom(f.mm);
        anc.copyFrom(f.anc);
        value = f.value;
        for (i in 0...256) map[i] = f.map[i];
    }
}

/** OptNode */
class OptNode {
    public var len:MinMaxLen;
    public var anc:OptAnc;
    public var sb:OptStr;
    public var sm:OptStr;
    public var spr:OptStr;
    public var map:OptMap;
    public function new() {
        len = new MinMaxLen();
        anc = new OptAnc();
        sb = new OptStr();
        sm = new OptStr();
        spr = new OptStr();
        map = new OptMap();
    }
    public function copyFrom(f:OptNode):Void {
        len.copyFrom(f.len);
        anc.copyFrom(f.anc);
        sb.copyFrom(f.sb);
        sm.copyFrom(f.sm);
        spr.copyFrom(f.spr);
        map.copyFrom(f.map);
    }
}

/** OptEnv */
class OptEnv {
    public var mm:MinMaxLen;
    public var caseFoldFlag:Int = 0;
    public var scanEnv:ParseEnv = null;
    public function new() {
        mm = new MinMaxLen();
    }
    public function copyFrom(f:OptEnv):Void {
        mm.copyFrom(f.mm);
        caseFoldFlag = f.caseFoldFlag;
        scanEnv = f.scanEnv;
    }
}
