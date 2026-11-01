// Ported from Oniguruma 6.9.8: src/regparse.c, src/regparse.h
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. Pointers into the pattern are offsets in a Bytes,
// out parameters use small reference objects. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regint.*;
import oniguruma.onig.Regenc.*;
import oniguruma.onig.Node.*;
import oniguruma.onig.Regenc.OnigCaseFoldCodeItem;
import oniguruma.onig.Regex.NameEntry;
import oniguruma.onig.Node.BBuf;

/** An Int passed by reference (pointer arguments of the C code). */
class IntRef {
    public var v:Int;
    public inline function new(v:Int = 0) {
        this.v = v;
    }
}

/** A Node passed by reference (Node** arguments of the C code). */
class NodeRef {
    public var v:Node;
    public inline function new(?v:Node) {
        this.v = v;
    }
}

/** MemEnv */
class MemEnv {
    public var memNode:Node = null;
    public var emptyRepeatNode:Node = null;
    public function new() {}
}

/** UnsetAddr / UnsetAddrList */
class UnsetAddr {
    public var offset:Int;
    public var target:Node;
    public function new(offset:Int, target:Node) {
        this.offset = offset;
        this.target = target;
    }
}

/** ParseEnv */
class ParseEnv {
    public var options:Int = 0;
    public var caseFoldFlag:Int = 0;
    public var syntax:OnigSyntaxType = null;
    public var capHistory:Int = 0;
    public var backtrackMem:Int = 0;
    public var backrefedMem:Int = 0;
    public var pattern:Bytes = null;
    public var patternStart:Int = 0;
    public var patternEnd:Int = 0;
    public var error:Int = -1;
    public var errorEnd:Int = -1;
    public var errorBytes:Bytes = null;
    public var reg:Regex = null;
    public var numCall:Int = 0;
    public var numMem:Int = 0;
    public var numNamed:Int = 0;
    public var memEnv:Array<MemEnv> = null;
    public var backrefNum:Int = 0;
    public var keepNum:Int = 0;
    public var idNum:Int = 0;
    public var saveAllocNum:Int = 0;
    public var unsetAddrList:Array<UnsetAddr> = null;
    public var parseDepth:Int = 0;
    public var flags:Int = 0;
    public function new() {}
}

/** A BBuf passed by reference (BBuf** arguments). */
class BBufRef {
    public var v:BBuf;
    public inline function new(?v:BBuf) {
        this.v = v;
    }
}

/**
 * PToken. The C union `u` is kept as int slots so that members sharing the
 * same memory in C (wasm32 layout) share the same slot here.
 */
class PToken {
    public var type:Int = 0;
    public var codePointContinue:Int = 0;
    public var escaped:Bool = false;
    public var base_num:Int = 0;
    public var backp:Int = 0;
    public var u0:Int = 0;
    public var u1:Int = 0;
    public var u2:Int = 0;
    public var u3:Int = 0;
    public var u4:Int = 0;
    public var u5:Int = 0;
    /** u.backref.refs (slot 2 in C, kept apart because it is a pointer to an int array) */
    public var backrefRefs:Array<Int> = null;

    public var code(get, set):Int;
    inline function get_code() return u0;
    inline function set_code(v) return u0 = v;
    public var byte(get, set):Int;
    inline function get_byte() return u0 & 0xff;
    inline function set_byte(v) return u0 = (u0 & ~0xff) | (v & 0xff);
    public var anchor(get, set):Int;
    inline function get_anchor() return u0;
    inline function set_anchor(v) return u0 = v;
    public var subtype(get, set):Int;
    inline function get_subtype() return u0;
    inline function set_subtype(v) return u0 = v;
    public var s(get, set):Int;
    inline function get_s() return u0;
    inline function set_s(v) return u0 = v;
    public var repeatLower(get, set):Int;
    inline function get_repeatLower() return u0;
    inline function set_repeatLower(v) return u0 = v;
    public var repeatUpper(get, set):Int;
    inline function get_repeatUpper() return u1;
    inline function set_repeatUpper(v) return u1 = v;
    public var repeatGreedy(get, set):Int;
    inline function get_repeatGreedy() return u2;
    inline function set_repeatGreedy(v) return u2 = v;
    public var repeatPossessive(get, set):Int;
    inline function get_repeatPossessive() return u3;
    inline function set_repeatPossessive(v) return u3 = v;
    public var backrefNum(get, set):Int;
    inline function get_backrefNum() return u0;
    inline function set_backrefNum(v) return u0 = v;
    public var backrefRef1(get, set):Int;
    inline function get_backrefRef1() return u1;
    inline function set_backrefRef1(v) return u1 = v;
    public var backrefByName(get, set):Int;
    inline function get_backrefByName() return u3;
    inline function set_backrefByName(v) return u3 = v;
    public var backrefExistLevel(get, set):Int;
    inline function get_backrefExistLevel() return u4;
    inline function set_backrefExistLevel(v) return u4 = v;
    public var backrefLevel(get, set):Int;
    inline function get_backrefLevel() return u5;
    inline function set_backrefLevel(v) return u5 = v;
    public var callName(get, set):Int;
    inline function get_callName() return u0;
    inline function set_callName(v) return u0 = v;
    public var callNameEnd(get, set):Int;
    inline function get_callNameEnd() return u1;
    inline function set_callNameEnd(v) return u1 = v;
    public var callGnum(get, set):Int;
    inline function get_callGnum() return u2;
    inline function set_callGnum(v) return u2 = v;
    public var callByNumber(get, set):Int;
    inline function get_callByNumber() return u3;
    inline function set_callByNumber(v) return u3 = v;
    public var propCtype(get, set):Int;
    inline function get_propCtype() return u0;
    inline function set_propCtype(v) return u0 = v;
    public var propNot(get, set):Int;
    inline function get_propNot() return u1;
    inline function set_propNot(v) return u1 = v;

    public function new() {}

    public function copyFrom(t:PToken):Void {
        type = t.type; codePointContinue = t.codePointContinue; escaped = t.escaped; base_num = t.base_num;
        backp = t.backp; u0 = t.u0; u1 = t.u1; u2 = t.u2; u3 = t.u3; u4 = t.u4; u5 = t.u5;
        backrefRefs = t.backrefRefs;
    }
}

class Regparse {

    public static inline var PE_FLAG_HAS_CALL_ZERO:Int = 1 << 0;
    public static inline var PE_FLAG_HAS_WHOLE_OPTIONS:Int = 1 << 1;

    static inline var NODE_STRING_MARGIN:Int = 16;
    static inline var NODE_BACKREFS_SIZE:Int = 6;
    static inline var DEFAULT_MAX_CAPTURE_NUM:Int = 32767;
    static var MaxCaptureNum:Int = DEFAULT_MAX_CAPTURE_NUM;
    static var ParseDepthLimit:Int = DEFAULT_PARSE_DEPTH_LIMIT;

    // CSTATE
    static inline var CS_VALUE:Int = 0;
    static inline var CS_RANGE:Int = 1;
    static inline var CS_COMPLETE:Int = 2;
    static inline var CS_START:Int = 3;
    // CVAL
    static inline var CV_UNDEF:Int = 0;
    static inline var CV_SB:Int = 1;
    static inline var CV_MB:Int = 2;
    static inline var CV_CPROP:Int = 3;

    // ---- helpers ----

    static inline function PEND(p:Int, end:Int):Bool {
        return p >= end;
    }

    static function backrefRelToAbs(relNo:Int, env:ParseEnv):Int {
        if (relNo > 0) {
            if (relNo > ONIG_INT_MAX - env.numMem)
                return ONIGERR_INVALID_BACKREF;
            return env.numMem + relNo;
        }
        else {
            return env.numMem + 1 + relNo;
        }
    }

    static inline function MBCODE_START_POS():Int {
        return 0x80;
    }

    static function bitsetIsEmpty(bs:Vector<Int>):Bool {
        for (i in 0...BITSET_REAL_SIZE) {
            if (bs[i] != 0) return false;
        }
        return true;
    }

    static function bitsetSetRange(bs:Vector<Int>, from:Int, to:Int):Void {
        if (from < 0) return; // unsigned value above 0x7fffffff
        var i = from;
        while (i <= to && i < SINGLE_BYTE_SIZE) {
            BITSET_SET_BIT(bs, i);
            i++;
        }
    }

    static function bitsetInvert(bs:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) bs[i] = ~bs[i];
    }

    static function bitsetInvertTo(from:Vector<Int>, to:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) to[i] = ~from[i];
    }

    static function bitsetAnd(dest:Vector<Int>, bs:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) dest[i] &= bs[i];
    }

    static function bitsetOr(dest:Vector<Int>, bs:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) dest[i] |= bs[i];
    }

    static function bitsetCopy(dest:Vector<Int>, bs:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) dest[i] = bs[i];
    }

    public static function onigStrncmp(s1:Bytes, p1:Int, s2:Bytes, p2:Int, n:Int):Int {
        while (n-- > 0) {
            var x = s2.get(p2++) - s1.get(p1++);
            if (x != 0) return x;
        }
        return 0;
    }

    /** A Bytes copy of [s, end) (used as name table key). */
    static function bytesKey(b:Bytes, s:Int, end:Int):String {
        return b.getString(s, end - s, RawNative);
    }

    // ---- name table ----

    static function nameFind(reg:Regex, b:Bytes, name:Int, nameEnd:Int):NameEntry {
        var t = reg.nameTable;
        if (t != null) {
            return t.get(nameKey(b, name, nameEnd));
        }
        return null;
    }

    static function nameKey(b:Bytes, s:Int, end:Int):String {
        var sb = new StringBuf();
        for (i in s...end) sb.addChar(b.get(i) + 1); // byte values shifted to stay non zero
        return sb.toString();
    }

    public static function onigRenumberNameTable(reg:Regex, map:Array<Int>):Int {
        var t = reg.nameTable;
        if (t != null) {
            for (e in t) {
                if (e.backNum >= 1) {
                    for (i in 0...e.backNum) {
                        e.backRefs[i] = map[e.backRefs[i]];
                    }
                }
            }
        }
        return 0;
    }

    public static function onigNumberOfNames(reg:Regex):Int {
        var t = reg.nameTable;
        if (t != null) {
            var n = 0;
            for (k in t.keys()) n++;
            return n;
        }
        return 0;
    }

    static function nameAdd(reg:Regex, b:Bytes, name:Int, nameEnd:Int, backref:Int, env:ParseEnv):Int {
        if (nameEnd - name <= 0)
            return ONIGERR_EMPTY_GROUP_NAME;

        var e = nameFind(reg, b, name, nameEnd);
        if (e == null) {
            if (reg.nameTable == null) {
                reg.nameTable = new Map();
            }
            e = new NameEntry(b.getString(name, nameEnd - name), nameEnd - name);
            reg.nameTable.set(nameKey(b, name, nameEnd), e);
        }

        if (e.backNum >= 1 && !IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_MULTIPLEX_DEFINITION_NAME)) {
            onigScanEnvSetErrorString(env, ONIGERR_MULTIPLEX_DEFINED_NAME, b, name, nameEnd);
            return ONIGERR_MULTIPLEX_DEFINED_NAME;
        }

        e.backNum++;
        e.backRefs.push(backref);
        return 0;
    }

    /** onig_name_to_group_numbers: returns the number of groups (nums receives them) or an error. */
    public static function onigNameToGroupNumbers(reg:Regex, b:Bytes, name:Int, nameEnd:Int, nums:Array<Array<Int>>):Int {
        var e = nameFind(reg, b, name, nameEnd);
        if (e == null) return ONIGERR_UNDEFINED_NAME_REFERENCE;
        nums[0] = e.backRefs;
        return e.backNum;
    }

    static function nameToGroupNumbers(env:ParseEnv, b:Bytes, name:Int, nameEnd:Int, nums:Array<Array<Int>>):Int {
        var reg = env.reg;
        var e = nameFind(reg, b, name, nameEnd);
        if (e == null) {
            onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_NAME_REFERENCE, b, name, nameEnd);
            return ONIGERR_UNDEFINED_NAME_REFERENCE;
        }
        nums[0] = e.backRefs;
        return e.backNum;
    }

    public static function onigNonameGroupCaptureIsActive(reg:Regex):Bool {
        if (OPTON_DONT_CAPTURE_GROUP(reg.options))
            return false;
        if (onigNumberOfNames(reg) > 0 && IS_SYNTAX_BV(reg.syntax, ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)
            && !OPTON_CAPTURE_GROUP(reg.options)) {
            return false;
        }
        return true;
    }

    // ---- ParseEnv ----

    static function scanEnvClear(env:ParseEnv):Void {
        env.capHistory = 0;
        env.backtrackMem = 0;
        env.backrefedMem = 0;
        env.error = -1;
        env.errorEnd = -1;
        env.numCall = 0;
        env.unsetAddrList = null;
        env.numMem = 0;
        env.numNamed = 0;
        env.memEnv = [for (i in 0...8) new MemEnv()];
        env.parseDepth = 0;
        env.backrefNum = 0;
        env.keepNum = 0;
        env.idNum = 0;
        env.saveAllocNum = 0;
        env.flags = 0;
    }

    static function scanEnvAddMemEntry(env:ParseEnv):Int {
        var need = env.numMem + 1;
        if (need > MaxCaptureNum && MaxCaptureNum != 0)
            return ONIGERR_TOO_MANY_CAPTURES;
        while (env.memEnv.length <= need) {
            env.memEnv.push(new MemEnv());
        }
        env.numMem++;
        return env.numMem;
    }

    static function scanEnvSetMemNode(env:ParseEnv, num:Int, node:Node):Int {
        if (env.numMem >= num)
            env.memEnv[num].memNode = node;
        else
            return ONIGERR_PARSER_BUG;
        return 0;
    }

    // ---- node constructors ----

    static inline function nodeNew():Node {
        return new Node();
    }

    public static function onigNodeFree(node:Node):Void {
        // garbage collected
    }

    static function nodeFreeBody(node:Node):Void {
        // garbage collected
    }

    static function consNodeFreeAlone(node:Node):Void {
        node.car = null;
        node.cdr = null;
    }

    public static function onigNodeCopy(rcopy:NodeRef, from:Node):Int {
        rcopy.v = null;
        switch (from.nodeType) {
            case NODE_LIST, NODE_ALT, NODE_ANCHOR:
                /* These node's link to other nodes are processed by caller. */
            case NODE_STRING, NODE_CCLASS, NODE_CTYPE:
                /* Fixed contents after copy. */
            default:
                /* Not supported yet. */
                return ONIGERR_TYPE_BUG;
        }

        var copy = nodeNew();
        copy.copyFrom(from);

        switch (copy.nodeType) {
            case NODE_STRING:
                var r = onigNodeStrSet(copy, from.sbuf, from.s, from.end, false);
                if (r != 0) return r;
            case NODE_CCLASS:
                if (from.mbuf != null) {
                    copy.mbuf = from.mbuf.clone();
                }
            default:
        }
        rcopy.v = copy;
        return ONIG_NORMAL;
    }

    static function initializeCclass(cc:Node):Void {
        cc.bs = newBitSet();
        cc.flags = 0;
        cc.mbuf = null;
    }

    static function nodeNewCclass():Node {
        var node = nodeNew();
        node.nodeType = NODE_CCLASS;
        initializeCclass(node);
        return node;
    }

    static function nodeNewCtype(type:Int, not:Bool, options:Int):Node {
        var node = nodeNew();
        node.nodeType = NODE_CTYPE;
        node.ctype = type;
        node.not = not ? 1 : 0;
        node.asciiMode = OPTON_IS_ASCII_MODE_CTYPE(type, options) ? 1 : 0;
        return node;
    }

    static function nodeNewAnychar(options:Int):Node {
        var node = nodeNewCtype(CTYPE_ANYCHAR, false, options);
        if (OPTON_MULTILINE(options))
            node.addStatus(NODE_ST_MULTILINE);
        return node;
    }

    static function nodeNewNoNewline(node:NodeRef, env:ParseEnv):Int {
        node.v = nodeNewAnychar(ONIG_OPTION_NONE);
        return 0;
    }

    static function nodeNewTrueAnychar(node:NodeRef):Int {
        node.v = nodeNewAnychar(ONIG_OPTION_MULTILINE);
        return 0;
    }

    static function nodeNewList(left:Node, right:Node):Node {
        var node = nodeNew();
        node.nodeType = NODE_LIST;
        node.car = left;
        node.cdr = right;
        return node;
    }

    public static function onigNodeNewList(left:Node, right:Node):Node {
        return nodeNewList(left, right);
    }

    public static function onigNodeNewAlt(left:Node, right:Node):Node {
        var node = nodeNew();
        node.nodeType = NODE_ALT;
        node.car = left;
        node.cdr = right;
        return node;
    }

    static function makeListOrAlt(type:Int, n:Int, ns:Array<Node>, off:Int):Node {
        if (n <= 0) return null;
        var r = nodeNew();
        if (n == 1) {
            r.nodeType = type;
            r.car = ns[off];
            r.cdr = null;
        }
        else {
            var right = makeListOrAlt(type, n - 1, ns, off + 1);
            r.nodeType = type;
            r.car = ns[off];
            r.cdr = right;
        }
        return r;
    }

    static inline function makeList(n:Int, ns:Array<Node>, off:Int = 0):Node {
        return makeListOrAlt(NODE_LIST, n, ns, off);
    }

    static inline function makeAlt(n:Int, ns:Array<Node>, off:Int = 0):Node {
        return makeListOrAlt(NODE_ALT, n, ns, off);
    }

    static function nodeNewAnchor(type:Int):Node {
        var node = nodeNew();
        node.nodeType = NODE_ANCHOR;
        node.type = type;
        node.charMinLen = 0;
        node.charMaxLen = INFINITE_LEN;
        node.asciiMode = 0;
        node.leadNode = null;
        return node;
    }

    static function nodeNewAnchorWithOptions(type:Int, options:Int):Node {
        var node = nodeNewAnchor(type);
        var asciiMode = OPTON_WORD_ASCII(options) && IS_WORD_ANCHOR_TYPE(type) ? 1 : 0;
        node.asciiMode = asciiMode;
        if (type == ANCR_TEXT_SEGMENT_BOUNDARY || type == ANCR_NO_TEXT_SEGMENT_BOUNDARY) {
            if (OPTON_TEXT_SEGMENT_WORD(options))
                node.addStatus(NODE_ST_TEXT_SEGMENT_WORD);
        }
        return node;
    }

    static function nodeNewBackref(backNum:Int, backrefs:Array<Int>, byName:Bool, existLevel:Bool, nestLevel:Int, env:ParseEnv):Node {
        var node = nodeNew();
        node.nodeType = NODE_BACKREF;
        node.backNum = backNum;
        if (byName)
            node.addStatus(NODE_ST_BY_NAME);
        if (OPTON_IGNORECASE(env.options))
            node.addStatus(NODE_ST_IGNORECASE);
        if (existLevel) {
            node.addStatus(NODE_ST_NEST_LEVEL);
            node.nestLevel = nestLevel;
        }
        for (i in 0...backNum) {
            if (backrefs[i] <= env.numMem && env.memEnv[backrefs[i]].memNode == null) {
                node.addStatus(NODE_ST_RECURSION); /* /...(\1).../ */
                break;
            }
        }
        node.backs = [for (i in 0...backNum) backrefs[i]];
        env.backrefNum++;
        return node;
    }

    static function nodeNewBackrefChecker(backNum:Int, backrefs:Array<Int>, byName:Bool, existLevel:Bool, nestLevel:Int, env:ParseEnv):Node {
        var node = nodeNewBackref(backNum, backrefs, byName, existLevel, nestLevel, env);
        node.addStatus(NODE_ST_CHECKER);
        return node;
    }

    static function nodeNewCall(name:Bytes, nameStart:Int, nameEnd:Int, gnum:Int, byNumber:Bool):Node {
        var node = nodeNew();
        node.nodeType = NODE_CALL;
        node.byNumber = byNumber ? 1 : 0;
        node.name = name;
        node.nameStart = nameStart;
        node.nameEnd = nameEnd;
        node.calledGnum = gnum;
        node.callEntryCount = 1;
        return node;
    }

    static function nodeNewQuantifier(lower:Int, upper:Int, byNumber:Bool):Node {
        var node = nodeNew();
        node.nodeType = NODE_QUANT;
        node.lower = lower;
        node.upper = upper;
        node.greedy = 1;
        node.emptiness = BODY_IS_NOT_EMPTY;
        node.headExact = null;
        node.nextHeadExact = null;
        node.includeReferred = 0;
        node.emptyStatusMem = 0;
        if (byNumber)
            node.addStatus(NODE_ST_BY_NUMBER);
        return node;
    }

    static function nodeNewBag(type:Int):Node {
        var node = nodeNew();
        node.nodeType = NODE_BAG;
        node.type = type;
        switch (type) {
            case BAG_MEMORY:
                node.regnum = 0;
                node.calledAddr = -1;
                node.entryCount = 1;
                node.calledState = 0;
            case BAG_OPTION:
                node.options = 0;
            case BAG_STOP_BACKTRACK:
            case BAG_IF_ELSE:
                node.Then = null;
                node.Else = null;
        }
        node.optCount = 0;
        return node;
    }

    public static function onigNodeNewBag(type:Int):Node {
        return nodeNewBag(type);
    }

    static function nodeNewBagIfElse(cond:Node, Then:Node, Else:Node):Node {
        var n = nodeNewBag(BAG_IF_ELSE);
        n.body = cond;
        n.Then = Then;
        n.Else = Else;
        return n;
    }

    static function nodeNewMemory(isNamed:Bool):Node {
        var node = nodeNewBag(BAG_MEMORY);
        if (isNamed)
            node.addStatus(NODE_ST_NAMED_GROUP);
        return node;
    }

    static function nodeNewOption(option:Int):Node {
        var node = nodeNewBag(BAG_OPTION);
        node.options = option;
        return node;
    }

    static function nodeNewGroup(content:Node):Node {
        var node = nodeNew();
        node.nodeType = NODE_LIST;
        node.car = content;
        node.cdr = null;
        return node;
    }

    static function nodeDropGroup(group:Node):Node {
        var content = group.car;
        group.car = null;
        return content;
    }

    static function nodeSetFail(node:Node):Int {
        node.nodeType = NODE_GIMMICK;
        node.type = GIMMICK_FAIL;
        return ONIG_NORMAL;
    }

    static function nodeNewFail(node:NodeRef, env:ParseEnv):Int {
        node.v = nodeNew();
        return nodeSetFail(node.v);
    }

    public static function onigNodeResetFail(node:Node):Int {
        nodeFreeBody(node);
        return nodeSetFail(node);
    }

    static function nodeNewSaveGimmick(node:NodeRef, saveType:Int, env:ParseEnv):Int {
        var id = env.idNum++;
        node.v = nodeNew();
        node.v.nodeType = NODE_GIMMICK;
        node.v.id = id;
        node.v.type = GIMMICK_SAVE;
        node.v.detailType = saveType;
        return ONIG_NORMAL;
    }

    static function nodeNewUpdateVarGimmick(node:NodeRef, updateVarType:Int, id:Int, env:ParseEnv):Int {
        node.v = nodeNew();
        node.v.nodeType = NODE_GIMMICK;
        node.v.id = id;
        node.v.type = GIMMICK_UPDATE_VAR;
        node.v.detailType = updateVarType;
        return ONIG_NORMAL;
    }

    static function nodeNewKeep(node:NodeRef, env:ParseEnv):Int {
        var r = nodeNewSaveGimmick(node, SAVE_KEEP, env);
        if (r != 0) return r;
        env.keepNum++;
        return ONIG_NORMAL;
    }

    static function nodeNewCallout(node:NodeRef, calloutOf:Int, num:Int, id:Int, env:ParseEnv):Int {
        node.v = nodeNew();
        node.v.nodeType = NODE_GIMMICK;
        node.v.id = id;
        node.v.num = num;
        node.v.type = GIMMICK_CALLOUT;
        node.v.detailType = calloutOf;
        return ONIG_NORMAL;
    }

    static function makeTextSegment(node:NodeRef, env:ParseEnv):Int {
        /* \X == (?>\O(?:\Y\O)*) */
        var ns:Array<Node> = [null, null];
        var t = new NodeRef();

        ns[0] = nodeNewAnchorWithOptions(ANCR_NO_TEXT_SEGMENT_BOUNDARY, env.options);
        nodeNewTrueAnychar(t);
        ns[1] = t.v;

        var x = makeList(2, ns);
        ns[0] = x;
        ns[1] = null;

        x = nodeNewQuantifier(0, INFINITE_REPEAT, true);
        x.body = ns[0];
        ns[0] = null;
        ns[1] = x;

        nodeNewTrueAnychar(t);
        ns[0] = t.v;

        x = makeList(2, ns);
        ns[0] = x;
        ns[1] = null;

        x = nodeNewBag(BAG_STOP_BACKTRACK);
        x.body = ns[0];
        node.v = x;
        return ONIG_NORMAL;
    }

    static function makeAbsentEngine(node:NodeRef, preSaveRightId:Int, absent:Node, stepOne:Node, lower:Int, upper:Int,
            possessive:Bool, isRangeCutter:Bool, env:ParseEnv):Int {
        var ns:Array<Node> = [null, null, null, null];
        var t = new NodeRef();

        ns[1] = absent;
        ns[3] = stepOne; /* for err */
        nodeNewSaveGimmick(t, SAVE_S, env);
        ns[0] = t.v;

        var id = ns[0].id;
        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK, id, env);
        ns[2] = t.v;

        if (isRangeCutter)
            ns[2].addStatus(NODE_ST_ABSENT_WITH_SIDE_EFFECTS);

        nodeNewFail(t, env);
        ns[3] = t.v;

        var x = makeList(4, ns);
        ns[0] = x;
        ns[1] = stepOne;
        ns[2] = ns[3] = null;

        x = makeAlt(2, ns);
        ns[0] = x;

        x = nodeNewQuantifier(lower, upper, false);
        x.body = ns[0];
        ns[0] = x;

        if (possessive) {
            x = nodeNewBag(BAG_STOP_BACKTRACK);
            x.body = ns[0];
            ns[0] = x;
        }

        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_STACK, preSaveRightId, env);
        ns[1] = t.v;

        nodeNewFail(t, env);
        ns[2] = t.v;

        x = makeList(2, ns, 1);
        ns[1] = x;
        ns[2] = null;

        x = makeAlt(2, ns);
        if (isRangeCutter)
            x.addStatus(NODE_ST_SUPER);

        node.v = x;
        return ONIG_NORMAL;
    }

    static function makeAbsentTail(node1:NodeRef, node2:NodeRef, preSaveRightId:Int, env:ParseEnv):Int {
        var ns:Array<Node> = [null, null];
        var t = new NodeRef();
        node1.v = node2.v = null;

        nodeNewSaveGimmick(t, SAVE_RIGHT_RANGE, env);
        var save = t.v;

        var id = save.id;
        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_STACK, id, env);
        ns[0] = t.v;

        nodeNewFail(t, env);
        ns[1] = t.v;

        var x = makeList(2, ns);
        ns[0] = null;
        ns[1] = x;

        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_STACK, preSaveRightId, env);
        ns[0] = t.v;

        x = makeAlt(2, ns);

        node1.v = save;
        node2.v = x;
        return ONIG_NORMAL;
    }

    static function makeRangeClear(node:NodeRef, env:ParseEnv):Int {
        var ns:Array<Node> = [null, null];
        var t = new NodeRef();
        node.v = null;

        nodeNewSaveGimmick(t, SAVE_RIGHT_RANGE, env);
        var save = t.v;

        var id = save.id;
        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_STACK, id, env);
        ns[0] = t.v;

        nodeNewFail(t, env);
        ns[1] = t.v;

        var x = makeList(2, ns);
        ns[0] = null;
        ns[1] = x;

        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_INIT, 0, env);
        ns[0] = t.v;
        ns[0].addStatus(NODE_ST_ABSENT_WITH_SIDE_EFFECTS);

        x = makeAlt(2, ns);
        x.addStatus(NODE_ST_SUPER);

        ns[0] = save;
        ns[1] = x;
        x = makeList(2, ns);

        node.v = x;
        return ONIG_NORMAL;
    }

    /** is_simple_one_char_repeat: returns the quantifier and its body in rquant/rbody, or false. */
    static function isSimpleOneCharRepeat(node:Node, rquant:NodeRef, rbody:NodeRef, isPossessive:IntRef, env:ParseEnv):Bool {
        var quant:Node;
        rquant.v = rbody.v = null;
        isPossessive.v = 0;

        if (node.nodeType == NODE_QUANT) {
            quant = node;
        }
        else {
            if (node.nodeType == NODE_BAG) {
                if (node.type == BAG_STOP_BACKTRACK) {
                    isPossessive.v = 1;
                    quant = node.body;
                    if (quant.nodeType != NODE_QUANT)
                        return false;
                }
                else
                    return false;
            }
            else
                return false;
        }

        if (quant.greedy == 0)
            return false;

        var body = quant.body;
        switch (body.nodeType) {
            case NODE_STRING:
                var len = 0;
                var s = body.s;
                while (s < body.end) {
                    s += enclen(body.sbuf, s);
                    len++;
                }
                if (len != 1)
                    return false;
            case NODE_CCLASS:
            default:
                return false;
        }

        if (node != quant) {
            node.body = null;
        }
        quant.body = null;
        rquant.v = quant;
        rbody.v = body;
        return true;
    }

    static function makeAbsentTreeForSimpleOneCharRepeat(node:NodeRef, absent:Node, quant:Node, body:Node, possessive:Bool, env:ParseEnv):Int {
        var ns:Array<Node> = [null, null, body, absent];
        var t = new NodeRef();
        node.v = null;

        var lower = quant.lower;
        var upper = quant.upper;

        nodeNewSaveGimmick(t, SAVE_RIGHT_RANGE, env);
        ns[0] = t.v;

        var id1 = ns[0].id;

        var r = makeAbsentEngine(t, id1, absent, body, lower, upper, possessive, false, env);
        if (r != 0) return r;
        ns[1] = t.v;

        ns[2] = ns[3] = null;

        nodeNewUpdateVarGimmick(t, UPDATE_VAR_RIGHT_RANGE_FROM_STACK, id1, env);
        ns[2] = t.v;

        node.v = makeList(3, ns);
        return ONIG_NORMAL;
    }

    static function makeAbsentTree(node:NodeRef, absent:Node, expr:Node, isRangeCutter:Bool, env:ParseEnv):Int {
        var ns:Array<Node> = [null, null, null, null, expr, absent, null];
        var t = new NodeRef();
        var r:Int;

        if (!isRangeCutter) {
            var quantRef = new NodeRef();
            var bodyRef = new NodeRef();
            var possessive = new IntRef();
            var simple = false;
            if (expr == null) {
                /* default expr \O* */
                quantRef.v = nodeNewQuantifier(0, INFINITE_REPEAT, false);
                nodeNewTrueAnychar(bodyRef);
                possessive.v = 0;
                simple = true;
            }
            else {
                simple = isSimpleOneCharRepeat(expr, quantRef, bodyRef, possessive, env);
            }
            if (simple) {
                r = makeAbsentTreeForSimpleOneCharRepeat(node, absent, quantRef.v, bodyRef.v, possessive.v != 0, env);
                if (r != 0) return r;
                return ONIG_NORMAL;
            }
        }

        nodeNewSaveGimmick(t, SAVE_RIGHT_RANGE, env);
        ns[0] = t.v;
        var id1 = ns[0].id;

        nodeNewSaveGimmick(t, SAVE_S, env);
        ns[1] = t.v;
        var id2 = ns[1].id;

        nodeNewTrueAnychar(t);
        ns[3] = t.v;

        r = makeAbsentEngine(t, id1, absent, ns[3], 0, INFINITE_REPEAT, true, isRangeCutter, env);
        if (r != 0) return r;
        ns[2] = t.v;

        ns[3] = null;
        ns[5] = null;

        nodeNewUpdateVarGimmick(t, UPDATE_VAR_S_FROM_STACK, id2, env);
        ns[3] = t.v;

        var x:Node;
        if (isRangeCutter) {
            x = makeList(4, ns);
        }
        else {
            var n5 = new NodeRef();
            var n6 = new NodeRef();
            r = makeAbsentTail(n5, n6, id1, env);
            if (r != 0) return r;
            ns[5] = n5.v;
            ns[6] = n6.v;
            x = makeList(7, ns);
        }

        node.v = x;
        return ONIG_NORMAL;
    }

    // ---- string nodes ----

    public static function onigNodeStrCat(node:Node, src:Bytes, s:Int, end:Int):Int {
        var addlen = end - s;
        if (addlen > 0) {
            var len = node.end - node.s;
            var buf = node.sbuf;
            if (buf == null || node.s + len + addlen > buf.length) {
                var nb = Bytes.alloc(len + addlen + NODE_STRING_MARGIN);
                if (len > 0) nb.blit(0, buf, node.s, len);
                node.sbuf = nb;
                node.s = 0;
                buf = nb;
            }
            buf.blit(node.s + len, src, s, addlen);
            node.end = node.s + len + addlen;
        }
        return 0;
    }

    public static function onigNodeStrSet(node:Node, src:Bytes, s:Int, end:Int, needFree:Bool):Int {
        onigNodeStrClear(node, needFree);
        return onigNodeStrCat(node, src, s, end);
    }

    static var oneByte:Bytes = Bytes.alloc(1);

    static function nodeStrCatChar(node:Node, c:Int):Int {
        oneByte.set(0, c);
        return onigNodeStrCat(node, oneByte, 0, 1);
    }

    public static function onigNodeStrClear(node:Node, needFree:Bool):Void {
        node.flag = 0;
        node.sbuf = null;
        node.s = 0;
        node.end = 0;
    }

    static function nodeSetStr(node:Node, src:Bytes, s:Int, end:Int):Int {
        node.nodeType = NODE_STRING;
        node.flag = 0;
        node.sbuf = null;
        node.s = 0;
        node.end = 0;
        return onigNodeStrCat(node, src, s, end);
    }

    static function nodeNewStr(src:Bytes, s:Int, end:Int):Node {
        var node = nodeNew();
        nodeSetStr(node, src, s, end);
        return node;
    }

    static function nodeResetStr(node:Node, src:Bytes, s:Int, end:Int):Int {
        nodeFreeBody(node);
        return nodeSetStr(node, src, s, end);
    }

    public static function onigNodeResetEmpty(node:Node):Int {
        return nodeResetStr(node, null, 0, 0);
    }

    public static function onigNodeNewStr(src:Bytes, s:Int, end:Int):Node {
        return nodeNewStr(src, s, end);
    }

    static function nodeNewStrWithOptions(src:Bytes, s:Int, end:Int, options:Int):Node {
        var node = nodeNewStr(src, s, end);
        if (OPTON_IGNORECASE(options))
            node.addStatus(NODE_ST_IGNORECASE);
        return node;
    }

    static function nodeNewStrCrude(src:Bytes, s:Int, end:Int, options:Int):Node {
        var node = nodeNewStrWithOptions(src, s, end, options);
        node.flag |= NODE_STRING_CRUDE;
        return node;
    }

    static function nodeNewEmpty():Node {
        return nodeNewStr(null, 0, 0);
    }

    static function nodeNewStrCrudeChar(c:Int, options:Int):Node {
        var b = Bytes.alloc(1);
        b.set(0, c);
        return nodeNewStrCrude(b, 0, 1, options);
    }

    static function strNodeSplitLastChar(node:Node):Node {
        var rn:Node = null;
        if (node.end > node.s) {
            var p = onigencGetPrevCharHead(node.sbuf, node.s, node.end);
            if (p != NULL_UCHARP && p > node.s) { /* can be split. */
                rn = nodeNewStr(node.sbuf, p, node.end);
                node.end = p;
                rn.flag = node.flag;
                rn.status = node.status;
            }
        }
        return rn;
    }

    static function strNodeCanBeSplit(node:Node):Bool {
        if (node.end > node.s) {
            return enclen(node.sbuf, node.s) < node.end - node.s;
        }
        return false;
    }

    // ---- numbers ----

    /** scan_number: returns the number (or -1 on overflow), src is advanced. */
    static function scanNumber(src:IntRef, end:Int, pat:Bytes):Int {
        var p = src.v;
        var num = 0;
        while (p < end) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (IS_CODE_DIGIT_ASCII(c)) {
                var val = DIGITVAL(c);
                if (Std.int((ONIG_INT_MAX - val) / 10) < num)
                    return -1; /* overflow */
                num = num * 10 + val;
            }
            else {
                p = pfetchPrev;
                break;
            }
        }
        src.v = p;
        return num;
    }

    static function scanHexadecimalNumber(src:IntRef, end:Int, minlen:Int, maxlen:Int, pat:Bytes, rcode:IntRef):Int {
        var p = src.v;
        var code:Float = 0;
        var n = 0;
        while (p < end && n < maxlen) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (IS_CODE_XDIGIT_ASCII(c)) {
                n++;
                var val = XDIGITVAL(c);
                if (Math.ffloor((4294967295.0 - val) / 16) < code)
                    return ONIGERR_TOO_BIG_NUMBER; /* overflow */
                code = code * 16 + val;
            }
            else {
                p = pfetchPrev;
                break;
            }
        }
        if (n < minlen)
            return ONIGERR_INVALID_CODE_POINT_VALUE;
        rcode.v = floatToUInt(code);
        src.v = p;
        return ONIG_NORMAL;
    }

    static inline function floatToUInt(f:Float):Int {
        return f >= 2147483648.0 ? Std.int(f - 4294967296.0) : Std.int(f);
    }

    static function scanOctalNumber(src:IntRef, end:Int, minlen:Int, maxlen:Int, pat:Bytes, rcode:IntRef):Int {
        var p = src.v;
        var code:Float = 0;
        var n = 0;
        while (p < end && n < maxlen) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (IS_CODE_DIGIT_ASCII(c) && c < '8'.code) {
                n++;
                var val = c - '0'.code;
                if (Math.ffloor((4294967295.0 - val) / 8) < code)
                    return ONIGERR_TOO_BIG_NUMBER; /* overflow */
                code = code * 8 + val;
            }
            else {
                p = pfetchPrev;
                break;
            }
        }
        if (n < minlen)
            return ONIGERR_INVALID_CODE_POINT_VALUE;
        rcode.v = floatToUInt(code);
        src.v = p;
        return ONIG_NORMAL;
    }

    static function scanNumberOfBase(src:IntRef, end:Int, minlen:Int, pat:Bytes, rcode:IntRef, base:Int):Int {
        if (base == 16)
            return scanHexadecimalNumber(src, end, minlen, 8, pat, rcode);
        else if (base == 8)
            return scanOctalNumber(src, end, minlen, 11, pat, rcode);
        else
            return ONIGERR_INVALID_CODE_POINT_VALUE;
    }

    static inline function IS_CODE_POINT_DIVIDE(c:Int):Bool {
        return c == ' '.code || c == '\n'.code;
    }

    static inline var CPS_EMPTY:Int = 0;
    static inline var CPS_START:Int = 1;
    static inline var CPS_RANGE:Int = 2;

    static function checkCodePointSequenceCc(p:Int, end:Int, base:Int, pat:Bytes, state:Int):Int {
        var endDigit = false;
        var n = 0;
        var code = new IntRef();
        var src = new IntRef();
        while (p < end) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            var restart = false;
            while (true) {
                if (c == '}'.code) {
                    if (state == CPS_RANGE) return ONIGERR_INVALID_CODE_POINT_VALUE;
                    return n;
                }
                if (IS_CODE_POINT_DIVIDE(c)) {
                    while (p < end) {
                        pfetchPrev = p;
                        c = mbcToCode(pat, p, end);
                        p += enclen(pat, p);
                        if (!IS_CODE_POINT_DIVIDE(c)) break;
                    }
                    if (IS_CODE_POINT_DIVIDE(c))
                        return ONIGERR_INVALID_CODE_POINT_VALUE;
                }
                else if (c == '-'.code) {
                    // range:
                    if (state != CPS_START) return ONIGERR_INVALID_CODE_POINT_VALUE;
                    if (p >= end) return ONIGERR_INVALID_CODE_POINT_VALUE;
                    endDigit = false;
                    state = CPS_RANGE;
                    restart = true;
                    break;
                }
                else if (endDigit) {
                    if (base == 16) {
                        if (IS_CODE_XDIGIT_ASCII(c))
                            return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                    }
                    else if (base == 8) {
                        if (IS_CODE_DIGIT_ASCII(c) && c < '8'.code)
                            return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                    }
                    return ONIGERR_INVALID_CODE_POINT_VALUE;
                }

                if (c == '}'.code) continue; // goto end_char
                if (c == '-'.code) continue; // goto range
                break;
            }
            if (restart) {
                // goto start: fetch the next char even if the loop condition is not checked
                if (p >= end) return ONIGERR_INVALID_CODE_POINT_VALUE;
                continue;
            }

            p = pfetchPrev;
            src.v = p;
            var r = scanNumberOfBase(src, end, 1, pat, code, base);
            if (r != 0) return r;
            p = src.v;
            n++;
            endDigit = true;
            state = (state == CPS_RANGE) ? CPS_EMPTY : CPS_START;
        }
        return ONIGERR_INVALID_CODE_POINT_VALUE;
    }

    static function checkCodePointSequence(p:Int, end:Int, base:Int, pat:Bytes):Int {
        var endDigit = false;
        var n = 0;
        var code = new IntRef();
        var src = new IntRef();
        while (p < end) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == '}'.code) {
                return n;
            }
            if (IS_CODE_POINT_DIVIDE(c)) {
                while (p < end) {
                    pfetchPrev = p;
                    c = mbcToCode(pat, p, end);
                    p += enclen(pat, p);
                    if (!IS_CODE_POINT_DIVIDE(c)) break;
                }
                if (IS_CODE_POINT_DIVIDE(c))
                    return ONIGERR_INVALID_CODE_POINT_VALUE;
            }
            else if (endDigit) {
                if (base == 16) {
                    if (IS_CODE_XDIGIT_ASCII(c))
                        return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                }
                else if (base == 8) {
                    if (IS_CODE_DIGIT_ASCII(c) && c < '8'.code)
                        return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                }
                return ONIGERR_INVALID_CODE_POINT_VALUE;
            }

            if (c == '}'.code) return n;

            p = pfetchPrev;
            src.v = p;
            var r = scanNumberOfBase(src, end, 1, pat, code, base);
            if (r != 0) return r;
            p = src.v;
            n++;
            endDigit = true;
        }
        return ONIGERR_INVALID_CODE_POINT_VALUE;
    }

    static function getNextCodePoint(src:IntRef, end:Int, base:Int, pat:Bytes, inCc:Bool, rcode:IntRef):Int {
        var p = src.v;
        while (p < end) {
            var pfetchPrev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (!IS_CODE_POINT_DIVIDE(c)) {
                if (c == '}'.code) {
                    src.v = p;
                    return 1; /* end of sequence */
                }
                else if (c == '-'.code && inCc) {
                    src.v = p;
                    return 2; /* range */
                }
                p = pfetchPrev;
                break;
            }
            else {
                if (p >= end)
                    return ONIGERR_INVALID_CODE_POINT_VALUE;
            }
        }
        var s = new IntRef(p);
        var r = scanNumberOfBase(s, end, 1, pat, rcode, base);
        if (r != 0) return r;
        src.v = s.v;
        return ONIG_NORMAL;
    }

    // ---- code ranges ----

    static function newCodeRange():BBuf {
        var b = new BBuf();
        b.p = [0];
        b.used = 1;
        return b;
    }

    /** add_code_range_to_buf: pbuf.v is created when null. */
    static function addCodeRangeToBuf(pbuf:BBufRef, from:Int, to:Int):Int {
        var n:Int;
        if (ugt(from, to)) {
            n = from; from = to; to = n;
        }
        var bbuf:BBuf;
        if (pbuf.v == null) {
            pbuf.v = newCodeRange();
            bbuf = pbuf.v;
            n = 0;
        }
        else {
            bbuf = pbuf.v;
            n = bbuf.p[0];
        }
        var data = bbuf.p; // data[k] is data[k + 1] in C (after data++)

        var low = 0;
        var bound = n;
        while (low < bound) {
            var x = (low + bound) >> 1;
            if (ugt(from, data[x * 2 + 1 + 1]))
                low = x + 1;
            else
                bound = x;
        }

        var high = (to == MAX_CODE_POINT) ? n : low;
        bound = n;
        while (high < bound) {
            var x = (high + bound) >> 1;
            if (uge(to + 1, data[x * 2 + 1]))
                high = x + 1;
            else
                bound = x;
        }

        var incN = low + 1 - high;
        if (n + incN > ONIG_MAX_MULTI_BYTE_RANGES_NUM)
            return ONIGERR_TOO_MANY_MULTI_BYTE_RANGES;

        if (incN != 1) {
            if (ugt(from, data[low * 2 + 1]))
                from = data[low * 2 + 1];
            if (ult(to, data[(high - 1) * 2 + 1 + 1]))
                to = data[(high - 1) * 2 + 1 + 1];
        }

        if (incN != 0 && high < n) {
            var fromPos = 1 + high * 2;
            var toPos = 1 + (low + 1) * 2;
            var size = (n - high) * 2;
            if (incN > 0) {
                // BB_MOVE_RIGHT
                while (data.length < toPos + size) data.push(0);
                var i = size - 1;
                while (i >= 0) {
                    data[toPos + i] = data[fromPos + i];
                    i--;
                }
                if (toPos + size > bbuf.used) bbuf.used = toPos + size;
            }
            else {
                // BB_MOVE_LEFT_REDUCE
                var cnt = bbuf.used - fromPos;
                for (i in 0...cnt) {
                    data[toPos + i] = data[fromPos + i];
                }
                bbuf.used -= (fromPos - toPos);
            }
        }

        var pos = 1 + low * 2;
        while (data.length < pos + 2) data.push(0);
        data[pos] = from;
        data[pos + 1] = to;
        if (pos + 2 > bbuf.used) bbuf.used = pos + 2;
        n += incN;
        data[0] = n;
        return 0;
    }

    static function addCodeRange(pbuf:BBufRef, env:ParseEnv, from:Int, to:Int):Int {
        if (ugt(from, to)) {
            if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC))
                return 0;
            else
                return ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS;
        }
        return addCodeRangeToBuf(pbuf, from, to);
    }

    static inline function SET_ALL_MULTI_BYTE_RANGE(pbuf:BBufRef):Int {
        return addCodeRangeToBuf(pbuf, MBCODE_START_POS(), MAX_CODE_POINT);
    }

    static function notCodeRangeBuf(bbuf:BBuf, pbuf:BBufRef):Int {
        pbuf.v = null;
        if (bbuf == null) {
            return SET_ALL_MULTI_BYTE_RANGE(pbuf);
        }
        var data = bbuf.p;
        var n = data[0];
        if (n <= 0) return SET_ALL_MULTI_BYTE_RANGE(pbuf);

        var r = 0;
        var pre = MBCODE_START_POS();
        var to = 0;
        for (i in 0...n) {
            var from = data[i * 2 + 1];
            to = data[i * 2 + 2];
            if (ule(pre, from - 1)) {
                r = addCodeRangeToBuf(pbuf, pre, from - 1);
                if (r != 0) return r;
            }
            if (to == MAX_CODE_POINT) break;
            pre = to + 1;
        }
        if (ult(to, MAX_CODE_POINT)) {
            r = addCodeRangeToBuf(pbuf, to + 1, MAX_CODE_POINT);
        }
        return r;
    }

    static function orCodeRangeBuf(bbuf1:BBuf, not1:Bool, bbuf2:BBuf, not2:Bool, pbuf:BBufRef):Int {
        pbuf.v = null;
        if (bbuf1 == null && bbuf2 == null) {
            if (not1 || not2)
                return SET_ALL_MULTI_BYTE_RANGE(pbuf);
            return 0;
        }

        var r = 0;
        if (bbuf2 == null) {
            var tb = bbuf1; bbuf1 = bbuf2; bbuf2 = tb;
            var tn = not1; not1 = not2; not2 = tn;
        }

        if (bbuf1 == null) {
            if (not1) {
                return SET_ALL_MULTI_BYTE_RANGE(pbuf);
            }
            else {
                if (!not2) {
                    pbuf.v = bbuf2.clone();
                    return 0;
                }
                else {
                    return notCodeRangeBuf(bbuf2, pbuf);
                }
            }
        }

        if (not1) {
            var tb = bbuf1; bbuf1 = bbuf2; bbuf2 = tb;
            var tn = not1; not1 = not2; not2 = tn;
        }

        var data1 = bbuf1.p;
        var n1 = data1[0];

        if (!not2 && !not1) { /* 1 OR 2 */
            pbuf.v = bbuf2.clone();
        }
        else if (!not1) { /* 1 OR (not 2) */
            r = notCodeRangeBuf(bbuf2, pbuf);
        }
        if (r != 0) return r;

        for (i in 0...n1) {
            var from = data1[i * 2 + 1];
            var to = data1[i * 2 + 2];
            r = addCodeRangeToBuf(pbuf, from, to);
            if (r != 0) return r;
        }
        return 0;
    }

    static function andCodeRange1(pbuf:BBufRef, from1:Int, to1:Int, data:Array<Int>, n:Int):Int {
        var r:Int;
        for (i in 0...n) {
            var from2 = data[i * 2 + 1];
            var to2 = data[i * 2 + 2];
            if (ult(from2, from1)) {
                if (ult(to2, from1)) continue;
                else {
                    from1 = to2 + 1;
                }
            }
            else if (ule(from2, to1)) {
                if (ult(to2, to1)) {
                    if (ule(from1, from2 - 1)) {
                        r = addCodeRangeToBuf(pbuf, from1, from2 - 1);
                        if (r != 0) return r;
                    }
                    from1 = to2 + 1;
                }
                else {
                    to1 = from2 - 1;
                }
            }
            else {
                from1 = from2;
            }
            if (ugt(from1, to1)) break;
        }
        if (ule(from1, to1)) {
            r = addCodeRangeToBuf(pbuf, from1, to1);
            if (r != 0) return r;
        }
        return 0;
    }

    static function andCodeRangeBuf(bbuf1:BBuf, not1:Bool, bbuf2:BBuf, not2:Bool, pbuf:BBufRef):Int {
        pbuf.v = null;
        if (bbuf1 == null) {
            if (not1 && bbuf2 != null) { /* not1 != 0 -> not2 == 0 */
                pbuf.v = bbuf2.clone();
                return 0;
            }
            return 0;
        }
        else if (bbuf2 == null) {
            if (not2) {
                pbuf.v = bbuf1.clone();
                return 0;
            }
            return 0;
        }

        if (not1) {
            var tb = bbuf1; bbuf1 = bbuf2; bbuf2 = tb;
            var tn = not1; not1 = not2; not2 = tn;
        }

        var data1 = bbuf1.p;
        var data2 = bbuf2.p;
        var n1 = data1[0];
        var n2 = data2[0];

        if (!not2 && !not1) { /* 1 AND 2 */
            for (i in 0...n1) {
                var from1 = data1[i * 2 + 1];
                var to1 = data1[i * 2 + 2];
                for (j in 0...n2) {
                    var from2 = data2[j * 2 + 1];
                    var to2 = data2[j * 2 + 2];
                    if (ugt(from2, to1)) break;
                    if (ult(to2, from1)) continue;
                    var from = ult(from1, from2) ? from2 : from1;
                    var to = ugt(to1, to2) ? to2 : to1;
                    var r = addCodeRangeToBuf(pbuf, from, to);
                    if (r != 0) return r;
                }
            }
        }
        else if (!not1) { /* 1 AND (not 2) */
            for (i in 0...n1) {
                var from1 = data1[i * 2 + 1];
                var to1 = data1[i * 2 + 2];
                var r = andCodeRange1(pbuf, from1, to1, data2, n2);
                if (r != 0) return r;
            }
        }
        return 0;
    }

    static function andCclass(dest:Node, cc:Node):Int {
        var not1 = dest.isNcclassNot();
        var bsr1 = dest.bs;
        var buf1 = dest.mbuf;
        var not2 = cc.isNcclassNot();
        var bsr2 = cc.bs;
        var buf2 = cc.mbuf;
        var r:Int;

        if (not1) {
            var bs1 = newBitSet();
            bitsetInvertTo(bsr1, bs1);
            bsr1 = bs1;
        }
        if (not2) {
            var bs2 = newBitSet();
            bitsetInvertTo(bsr2, bs2);
            bsr2 = bs2;
        }
        bitsetAnd(bsr1, bsr2);
        if (bsr1 != dest.bs) {
            bitsetCopy(dest.bs, bsr1);
        }
        if (not1) {
            bitsetInvert(dest.bs);
        }

        var pbuf = new BBufRef();
        if (not1 && not2) {
            r = orCodeRangeBuf(buf1, false, buf2, false, pbuf);
        }
        else {
            r = andCodeRangeBuf(buf1, not1, buf2, not2, pbuf);
            if (r == 0 && not1) {
                var tbuf = new BBufRef();
                r = notCodeRangeBuf(pbuf.v, tbuf);
                if (r != 0) {
                    return r;
                }
                pbuf.v = tbuf.v;
            }
        }
        if (r != 0) return r;
        dest.mbuf = pbuf.v;
        return r;
    }

    static function orCclass(dest:Node, cc:Node):Int {
        var not1 = dest.isNcclassNot();
        var bsr1 = dest.bs;
        var buf1 = dest.mbuf;
        var not2 = cc.isNcclassNot();
        var bsr2 = cc.bs;
        var buf2 = cc.mbuf;
        var r:Int;

        if (not1) {
            var bs1 = newBitSet();
            bitsetInvertTo(bsr1, bs1);
            bsr1 = bs1;
        }
        if (not2) {
            var bs2 = newBitSet();
            bitsetInvertTo(bsr2, bs2);
            bsr2 = bs2;
        }
        bitsetOr(bsr1, bsr2);
        if (bsr1 != dest.bs) {
            bitsetCopy(dest.bs, bsr1);
        }
        if (not1) {
            bitsetInvert(dest.bs);
        }

        var pbuf = new BBufRef();
        if (not1 && not2) {
            r = andCodeRangeBuf(buf1, false, buf2, false, pbuf);
        }
        else {
            r = orCodeRangeBuf(buf1, not1, buf2, not2, pbuf);
            if (r == 0 && not1) {
                var tbuf = new BBufRef();
                r = notCodeRangeBuf(pbuf.v, tbuf);
                if (r != 0) {
                    return r;
                }
                pbuf.v = tbuf.v;
            }
        }
        if (r != 0) return r;
        dest.mbuf = pbuf.v;
        return r;
    }

    static function convBackslashValue(c:Int, env:ParseEnv):Int {
        if (IS_SYNTAX_OP(env.syntax, ONIG_SYN_OP_ESC_CONTROL_CHARS)) {
            switch (c) {
                case 'n'.code: return '\n'.code;
                case 't'.code: return '\t'.code;
                case 'r'.code: return '\r'.code;
                case 'f'.code: return 0x0c;
                case 'a'.code: return 0x07;
                case 'b'.code: return 0x08;
                case 'e'.code: return 0x1b;
                case 'v'.code:
                    if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_ESC_V_VTAB))
                        return 0x0b;
                default:
            }
        }
        return c;
    }

    static function isInvalidQuantifierTarget(node:Node):Bool {
        switch (node.nodeType) {
            case NODE_ANCHOR, NODE_GIMMICK:
                return true;
            case NODE_BAG:
                /* allow enclosed elements */
            case NODE_LIST:
                do {
                    if (!isInvalidQuantifierTarget(node.car)) return false;
                } while ((node = node.cdr) != null);
                return false;
            case NODE_ALT:
                do {
                    if (isInvalidQuantifierTarget(node.car)) return true;
                } while ((node = node.cdr) != null);
            default:
        }
        return false;
    }

    /* ?:0, *:1, +:2, ??:3, *?:4, +?:5 */
    static function quantifierTypeNum(q:Node):Int {
        if (q.greedy != 0) {
            if (q.lower == 0) {
                if (q.upper == 1) return 0;
                else if (q.upper == INFINITE_REPEAT) return 1;
            }
            else if (q.lower == 1) {
                if (q.upper == INFINITE_REPEAT) return 2;
            }
        }
        else {
            if (q.lower == 0) {
                if (q.upper == 1) return 3;
                else if (q.upper == INFINITE_REPEAT) return 4;
            }
            else if (q.lower == 1) {
                if (q.upper == INFINITE_REPEAT) return 5;
            }
        }
        return -1;
    }

    static inline var RQ_ASIS:Int = 0;
    static inline var RQ_DEL:Int = 1;
    static inline var RQ_A:Int = 2;
    static inline var RQ_P:Int = 3;
    static inline var RQ_AQ:Int = 4;
    static inline var RQ_QQ:Int = 5;
    static inline var RQ_P_QQ:Int = 6;

    static final ReduceTypeTable:Array<Array<Int>> = [
        [RQ_DEL, RQ_A, RQ_A, RQ_QQ, RQ_AQ, RQ_ASIS], /* '?'  */
        [RQ_DEL, RQ_DEL, RQ_DEL, RQ_P_QQ, RQ_P_QQ, RQ_DEL], /* '*'  */
        [RQ_A, RQ_A, RQ_DEL, RQ_ASIS, RQ_P_QQ, RQ_DEL], /* '+'  */
        [RQ_DEL, RQ_AQ, RQ_AQ, RQ_DEL, RQ_AQ, RQ_AQ], /* '??' */
        [RQ_DEL, RQ_DEL, RQ_DEL, RQ_DEL, RQ_DEL, RQ_DEL], /* '*?' */
        [RQ_ASIS, RQ_A, RQ_P, RQ_AQ, RQ_AQ, RQ_DEL] /* '+?' */
    ];

    public static function onigPositiveIntMultiply(x:Int, y:Int):Int {
        if (x == 0 || y == 0) return 0;
        if (x < Std.int(ONIG_INT_MAX / y))
            return x * y;
        else
            return -1;
    }

    public static function onigReduceNestedQuantifier(pnode:Node):Int {
        var cnode = pnode.body;
        var p = pnode;
        var c = cnode;
        var pnum = quantifierTypeNum(p);
        var cnum = quantifierTypeNum(c);
        if (pnum < 0 || cnum < 0) {
            if (p.lower == p.upper && c.lower == c.upper) {
                var n = onigPositiveIntMultiply(p.lower, c.lower);
                if (n < 0) return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
                p.lower = p.upper = n;
                pnode.body = cnode.body;
                cnode.body = null;
                return 0;
            }
            return 0;
        }

        switch (ReduceTypeTable[cnum][pnum]) {
            case RQ_DEL:
                pnode.copyFrom(cnode);
            case RQ_A:
                pnode.body = cnode.body;
                p.lower = 0; p.upper = INFINITE_REPEAT; p.greedy = 1;
            case RQ_P:
                pnode.body = cnode.body;
                p.lower = 1; p.upper = INFINITE_REPEAT; p.greedy = 1;
            case RQ_AQ:
                pnode.body = cnode.body;
                p.lower = 0; p.upper = INFINITE_REPEAT; p.greedy = 0;
            case RQ_QQ:
                pnode.body = cnode.body;
                p.lower = 0; p.upper = 1; p.greedy = 0;
            case RQ_P_QQ:
                p.lower = 0; p.upper = 1; p.greedy = 0;
                c.lower = 1; c.upper = INFINITE_REPEAT; c.greedy = 1;
                return 0;
            case RQ_ASIS:
                return 0;
        }
        // remove_cnode:
        cnode.body = null;
        return 0;
    }

    static function nodeNewGeneralNewline(node:NodeRef, env:ParseEnv):Int {
        var buf = Bytes.alloc(ONIGENC_CODE_TO_MBC_MAXLEN * 2);
        var dlen = codeToMbc(0x0d, buf, 0);
        if (dlen < 0) return dlen;
        var alen = codeToMbc(NEWLINE_CODE, buf, dlen);
        if (alen < 0) return alen;

        var crnl = nodeNewStrCrude(buf, 0, dlen + alen, ONIG_OPTION_NONE);
        var ncc = nodeNewCclass();
        var cc = ncc;
        var r:Int;
        var mb = new BBufRef(cc.mbuf);
        if (dlen == 1) {
            bitsetSetRange(cc.bs, NEWLINE_CODE, 0x0d);
        }
        else {
            r = addCodeRange(mb, env, NEWLINE_CODE, 0x0d);
            if (r != 0) return ONIGERR_MEMORY;
        }
        r = addCodeRange(mb, env, 0x85, 0x85);
        if (r != 0) return ONIGERR_MEMORY;
        r = addCodeRange(mb, env, 0x2028, 0x2029);
        if (r != 0) return ONIGERR_MEMORY;
        cc.mbuf = mb.v;

        node.v = nodeNewBagIfElse(crnl, null, ncc);
        return 0;
    }

    // TokenSyms
    static inline var TK_EOT:Int = 0;
    static inline var TK_CRUDE_BYTE:Int = 1;
    static inline var TK_CHAR:Int = 2;
    static inline var TK_STRING:Int = 3;
    static inline var TK_CODE_POINT:Int = 4;
    static inline var TK_ANYCHAR:Int = 5;
    static inline var TK_CHAR_TYPE:Int = 6;
    static inline var TK_BACKREF:Int = 7;
    static inline var TK_CALL:Int = 8;
    static inline var TK_ANCHOR:Int = 9;
    static inline var TK_REPEAT:Int = 10;
    static inline var TK_INTERVAL:Int = 11;
    static inline var TK_ANYCHAR_ANYTIME:Int = 12;
    static inline var TK_ALT:Int = 13;
    static inline var TK_SUBEXP_OPEN:Int = 14;
    static inline var TK_SUBEXP_CLOSE:Int = 15;
    static inline var TK_OPEN_CC:Int = 16;
    static inline var TK_QUOTE_OPEN:Int = 17;
    static inline var TK_CHAR_PROPERTY:Int = 18;
    static inline var TK_KEEP:Int = 19;
    static inline var TK_GENERAL_NEWLINE:Int = 20;
    static inline var TK_NO_NEWLINE:Int = 21;
    static inline var TK_TRUE_ANYCHAR:Int = 22;
    static inline var TK_TEXT_SEGMENT:Int = 23;
    static inline var TK_CC_CLOSE:Int = 24;
    static inline var TK_CC_RANGE:Int = 25;
    static inline var TK_CC_POSIX_BRACKET_OPEN:Int = 26;
    static inline var TK_CC_AND:Int = 27;
    static inline var TK_CC_OPEN_CC:Int = 28;

    static function ptokenInit(tok:PToken):Void {
        tok.codePointContinue = 0;
    }

    static function fetchInterval(src:IntRef, end:Int, tok:PToken, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var pfetchPrev = p;
        var r = 0;
        var nonLow = false;
        var low:Int;
        var up:Int;
        var c:Int;
        var synAllow = IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_INVALID_INTERVAL);

        if (p >= end) {
            if (synAllow)
                return 1; /* "....{" : OK! */
            else
                return ONIGERR_END_PATTERN_AT_LEFT_BRACE; /* "....{" syntax error */
        }

        if (!synAllow) {
            c = mbcToCode(pat, p, end);
            if (c == ')'.code || c == '('.code || c == '|'.code) {
                return ONIGERR_END_PATTERN_AT_LEFT_BRACE;
            }
        }

        var pr = new IntRef(p);
        low = scanNumber(pr, end, pat);
        p = pr.v;
        if (low < 0) return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
        if (low > ONIG_MAX_REPEAT_NUM)
            return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;

        var invalid = false;
        do {
            if (p == src.v) { /* can't read low */
                if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV)) {
                    /* allow {,n} as {0,n} */
                    low = 0;
                    nonLow = true;
                }
                else {
                    invalid = true;
                    break;
                }
            }

            if (p >= end) { invalid = true; break; }
            pfetchPrev = p;
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == ','.code) {
                var prev = p;
                pr.v = p;
                up = scanNumber(pr, end, pat);
                p = pr.v;
                if (up < 0) return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
                if (up > ONIG_MAX_REPEAT_NUM)
                    return ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE;
                if (p == prev) {
                    if (nonLow) { invalid = true; break; }
                    up = INFINITE_REPEAT; /* {n,} : {n,infinite} */
                }
            }
            else {
                if (nonLow) { invalid = true; break; }
                p = pfetchPrev;
                up = low; /* {n} : exact n times */
                r = 2; /* fixed */
            }

            if (p >= end) { invalid = true; break; }
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (IS_SYNTAX_OP(env.syntax, ONIG_SYN_OP_ESC_BRACE_INTERVAL)) {
                if (c != env.syntax.metaEsc || p >= end) { invalid = true; break; }
                c = mbcToCode(pat, p, end);
                p += enclen(pat, p);
            }
            if (c != '}'.code) { invalid = true; break; }

            if (up != INFINITE_REPEAT && low > up) {
                /* {n,m}+ supported case */
                if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL))
                    return ONIGERR_UPPER_SMALLER_THAN_LOWER_IN_REPEAT_RANGE;
                tok.repeatPossessive = 1;
                var tmp = low; low = up; up = tmp;
            }
            else
                tok.repeatPossessive = 0;

            tok.type = TK_INTERVAL;
            tok.repeatLower = low;
            tok.repeatUpper = up;
            src.v = p;
            return r; /* 0: normal {n,m}, 2: fixed {n} */
        } while (false);

        // invalid:
        if (synAllow) {
            return 1; /* OK */
        }
        else
            return ONIGERR_INVALID_REPEAT_RANGE_PATTERN;
    }

    /* \M-, \C-, \c, or \... */
    static function fetchEscapedValueRaw(src:IntRef, end:Int, env:ParseEnv, val:IntRef):Int {
        var pat = env.pattern;
        var p = src.v;
        var c:Int;
        var v:Int;

        if (p >= end) return ONIGERR_END_PATTERN_AT_ESCAPE;

        c = mbcToCode(pat, p, end);
        p += enclen(pat, p);
        var doControl = false;
        var doBackslash = false;
        switch (c) {
            case 'M'.code:
                if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_ESC_CAPITAL_M_BAR_META)) {
                    if (p >= end) return ONIGERR_END_PATTERN_AT_META;
                    c = mbcToCode(pat, p, end);
                    p += enclen(pat, p);
                    if (c != '-'.code) return ONIGERR_META_CODE_SYNTAX;
                    if (p >= end) return ONIGERR_END_PATTERN_AT_META;
                    c = mbcToCode(pat, p, end);
                    p += enclen(pat, p);
                    if (c == env.syntax.metaEsc) {
                        var pr = new IntRef(p);
                        var cr = new IntRef(c);
                        v = fetchEscapedValueRaw(pr, end, env, cr);
                        if (v < 0) return v;
                        p = pr.v;
                        c = cr.v;
                    }
                    c = ((c & 0xff) | 0x80);
                }
                else
                    doBackslash = true;

            case 'C'.code:
                if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_ESC_CAPITAL_C_BAR_CONTROL)) {
                    if (p >= end) return ONIGERR_END_PATTERN_AT_CONTROL;
                    c = mbcToCode(pat, p, end);
                    p += enclen(pat, p);
                    if (c != '-'.code) return ONIGERR_CONTROL_CODE_SYNTAX;
                    doControl = true;
                }
                else
                    doBackslash = true;

            case 'c'.code:
                if (IS_SYNTAX_OP(env.syntax, ONIG_SYN_OP_ESC_C_CONTROL)) {
                    doControl = true;
                }
                else
                    doBackslash = true;

            default:
                doBackslash = true;
        }

        if (doControl) {
            if (p >= end) return ONIGERR_END_PATTERN_AT_CONTROL;
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == '?'.code) {
                c = 0x7f;
            }
            else {
                if (c == env.syntax.metaEsc) {
                    var pr = new IntRef(p);
                    var cr = new IntRef(c);
                    v = fetchEscapedValueRaw(pr, end, env, cr);
                    if (v < 0) return v;
                    p = pr.v;
                    c = cr.v;
                }
                c &= 0x9f;
            }
        }
        else if (doBackslash) {
            c = convBackslashValue(c, env);
        }

        src.v = p;
        val.v = c;
        return 0;
    }

    static function fetchEscapedValue(src:IntRef, end:Int, env:ParseEnv, val:IntRef):Int {
        var r = fetchEscapedValueRaw(src, end, env, val);
        if (r != 0) return r;
        var len = codeToMbclen(val.v);
        if (len < 0) return len;
        return 0;
    }

    static function getNameEndCodePoint(start:Int):Int {
        switch (start) {
            case '<'.code: return '>'.code;
            case "'".code: return "'".code;
            case '('.code: return ')'.code;
            default:
        }
        return 0;
    }

    static inline var IS_NOT_NUM:Int = 0;
    static inline var IS_ABS_NUM:Int = 1;
    static inline var IS_REL_NUM:Int = 2;

    /*
       \k<name+n>, \k<name-n>
       \k<num+n>,  \k<num-n>
       \k<-num+n>, \k<-num-n>
       \k<+num+n>, \k<+num-n>
    */
    static function fetchNameWithLevel(startCode:Int, src:IntRef, end:Int, rnameEnd:IntRef, env:ParseEnv,
            rbackNum:IntRef, rlevel:IntRef, numType:IntRef):Int {
        var pat = env.pattern;
        var p = src.v;
        var pfetchPrev = p;
        var c = 0;
        rbackNum.v = 0;
        var existLevel = false;
        numType.v = IS_NOT_NUM;
        var sign = 1;
        var pnumHead = src.v;

        var endCode = getNameEndCodePoint(startCode);

        var digitCount = 0;
        var nameEnd = end;
        var r = 0;
        if (p >= end) {
            return ONIGERR_EMPTY_GROUP_NAME;
        }
        else {
            pfetchPrev = p;
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == endCode)
                return ONIGERR_EMPTY_GROUP_NAME;

            if (IS_CODE_DIGIT_ASCII(c)) {
                numType.v = IS_ABS_NUM;
                digitCount++;
            }
            else if (c == '-'.code) {
                numType.v = IS_REL_NUM;
                sign = -1;
                pnumHead = p;
            }
            else if (c == '+'.code) {
                numType.v = IS_REL_NUM;
                sign = 1;
                pnumHead = p;
            }
            else if (!isCodeWord(c)) {
                r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
            }
        }

        while (p < end) {
            nameEnd = p;
            pfetchPrev = p;
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == endCode || c == ')'.code || c == '+'.code || c == '-'.code) {
                if (numType.v != IS_NOT_NUM && digitCount == 0)
                    r = ONIGERR_INVALID_GROUP_NAME;
                break;
            }

            if (numType.v != IS_NOT_NUM) {
                if (IS_CODE_DIGIT_ASCII(c)) {
                    digitCount++;
                }
                else {
                    r = ONIGERR_INVALID_GROUP_NAME;
                    numType.v = IS_NOT_NUM;
                }
            }
            else if (!isCodeWord(c)) {
                r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
            }
        }

        var gotoEnd = false;
        var gotoErr2 = false;
        if (r == 0 && c != endCode) {
            var errFallthrough = true;
            if (c == '+'.code || c == '-'.code) {
                var flag = (c == '-'.code ? -1 : 1);
                if (p >= end) {
                    r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
                    gotoEnd = true;
                    errFallthrough = false;
                }
                else {
                    pfetchPrev = p;
                    c = mbcToCode(pat, p, end);
                    p += enclen(pat, p);
                    if (IS_CODE_DIGIT_ASCII(c)) {
                        p = pfetchPrev;
                        var pr = new IntRef(p);
                        var level = scanNumber(pr, end, pat);
                        p = pr.v;
                        if (level < 0) return ONIGERR_TOO_BIG_NUMBER;
                        rlevel.v = level * flag;
                        existLevel = true;

                        if (p < end) {
                            pfetchPrev = p;
                            c = mbcToCode(pat, p, end);
                            p += enclen(pat, p);
                            if (c == endCode) {
                                gotoEnd = true;
                                errFallthrough = false;
                            }
                        }
                    }
                }
            }
            if (errFallthrough) {
                // err:
                nameEnd = end;
                // err2:
                r = ONIGERR_INVALID_GROUP_NAME;
            }
        }

        // end:
        while (true) {
            if (r == 0) {
                if (numType.v != IS_NOT_NUM) {
                    var pr = new IntRef(pnumHead);
                    rbackNum.v = scanNumber(pr, nameEnd, pat);
                    if (rbackNum.v < 0) return ONIGERR_TOO_BIG_NUMBER;
                    else if (rbackNum.v == 0) {
                        if (numType.v == IS_REL_NUM) {
                            r = ONIGERR_INVALID_GROUP_NAME; // goto err2
                            continue;
                        }
                    }
                    rbackNum.v *= sign;
                }
                rnameEnd.v = nameEnd;
                src.v = p;
                return existLevel ? 1 : 0;
            }
            else {
                onigScanEnvSetErrorString(env, r, pat, src.v, nameEnd);
                return r;
            }
        }
    }

    /*
      ref: 0 -> define name    (don't allow number name)
           1 -> reference name (allow number name)
    */
    static function fetchName(startCode:Int, src:IntRef, end:Int, rnameEnd:IntRef, env:ParseEnv, rbackNum:IntRef,
            numType:IntRef, isRef:Bool):Int {
        var pat = env.pattern;
        var p = src.v;
        var c = 0;
        rbackNum.v = 0;

        var endCode = getNameEndCodePoint(startCode);

        var digitCount = 0;
        var nameEnd = end;
        var pnumHead = src.v;
        var r = 0;
        numType.v = IS_NOT_NUM;
        var sign = 1;
        if (p >= end) {
            return ONIGERR_EMPTY_GROUP_NAME;
        }
        else {
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == endCode)
                return ONIGERR_EMPTY_GROUP_NAME;

            if (IS_CODE_DIGIT_ASCII(c)) {
                if (isRef)
                    numType.v = IS_ABS_NUM;
                else {
                    r = ONIGERR_INVALID_GROUP_NAME;
                }
                digitCount++;
            }
            else if (c == '-'.code) {
                if (isRef) {
                    numType.v = IS_REL_NUM;
                    sign = -1;
                    pnumHead = p;
                }
                else {
                    r = ONIGERR_INVALID_GROUP_NAME;
                }
            }
            else if (c == '+'.code) {
                if (isRef) {
                    numType.v = IS_REL_NUM;
                    sign = 1;
                    pnumHead = p;
                }
                else {
                    r = ONIGERR_INVALID_GROUP_NAME;
                }
            }
            else if (!isCodeWord(c)) {
                r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
            }
        }

        if (r == 0) {
            while (p < end) {
                nameEnd = p;
                c = mbcToCode(pat, p, end);
                p += enclen(pat, p);
                if (c == endCode || c == ')'.code) {
                    if (numType.v != IS_NOT_NUM && digitCount == 0)
                        r = ONIGERR_INVALID_GROUP_NAME;
                    break;
                }

                if (numType.v != IS_NOT_NUM) {
                    if (IS_CODE_DIGIT_ASCII(c)) {
                        digitCount++;
                    }
                    else {
                        if (!isCodeWord(c))
                            r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
                        else
                            r = ONIGERR_INVALID_GROUP_NAME;
                        numType.v = IS_NOT_NUM;
                    }
                }
                else {
                    if (!isCodeWord(c)) {
                        r = ONIGERR_INVALID_CHAR_IN_GROUP_NAME;
                    }
                }
            }

            if (c != endCode) {
                r = ONIGERR_INVALID_GROUP_NAME;
                onigScanEnvSetErrorString(env, r, pat, src.v, nameEnd);
                return r;
            }

            if (numType.v != IS_NOT_NUM) {
                var pr = new IntRef(pnumHead);
                rbackNum.v = scanNumber(pr, nameEnd, pat);
                if (rbackNum.v < 0) return ONIGERR_TOO_BIG_NUMBER;
                else if (rbackNum.v == 0) {
                    if (numType.v == IS_REL_NUM) {
                        r = ONIGERR_INVALID_GROUP_NAME;
                        onigScanEnvSetErrorString(env, r, pat, src.v, nameEnd);
                        return r;
                    }
                }
                rbackNum.v *= sign;
            }

            rnameEnd.v = nameEnd;
            src.v = p;
            return 0;
        }
        else {
            while (p < end) {
                nameEnd = p;
                c = mbcToCode(pat, p, end);
                p += enclen(pat, p);
                if (c == endCode || c == ')'.code)
                    break;
            }
            if (p >= end)
                nameEnd = end;

            onigScanEnvSetErrorString(env, r, pat, src.v, nameEnd);
            return r;
        }
    }

    static function findStrPosition(s:Array<Int>, n:Int, pat:Bytes, from:Int, to:Int, next:IntRef):Int {
        var p = from;
        while (p < to) {
            var x = mbcToCode(pat, p, to);
            var q = p + enclen(pat, p);
            if (x == s[0]) {
                var i = 1;
                while (i < n && q < to) {
                    x = mbcToCode(pat, q, to);
                    if (x != s[i]) break;
                    q += enclen(pat, q);
                    i++;
                }
                if (i >= n) {
                    if (next != null)
                        next.v = q;
                    return p;
                }
            }
            p = q;
        }
        return NULL_UCHARP;
    }

    static function strExistCheckWithEsc(s:Array<Int>, n:Int, pat:Bytes, from:Int, to:Int, bad:Int, syn:OnigSyntaxType):Bool {
        var inEsc = false;
        var p = from;
        while (p < to) {
            if (inEsc) {
                inEsc = false;
                p += enclen(pat, p);
            }
            else {
                var x = mbcToCode(pat, p, to);
                var q = p + enclen(pat, p);
                if (x == s[0]) {
                    var i = 1;
                    while (i < n && q < to) {
                        x = mbcToCode(pat, q, to);
                        if (x != s[i]) break;
                        q += enclen(pat, q);
                        i++;
                    }
                    if (i >= n) return true;
                    p += enclen(pat, p);
                }
                else {
                    x = mbcToCode(pat, p, to);
                    if (x == bad) return false;
                    else if (x == syn.metaEsc) inEsc = true;
                    p = q;
                }
            }
        }
        return false;
    }

    public static function onigScanEnvSetErrorString(env:ParseEnv, ecode:Int, b:Bytes, arg:Int, argEnd:Int):Void {
        env.errorBytes = b;
        env.error = arg;
        env.errorEnd = argEnd;
    }

    static function fetchTokenCc(tok:PToken, src:IntRef, end:Int, env:ParseEnv, state:Int):Int {
        var pat = env.pattern;
        var p = src.v;
        var pfetchPrev = p;
        var syn = env.syntax;
        var c:Int;
        var c2:Int;
        var r:Int;
        var code = new IntRef();
        var pr = new IntRef();

        inline function PPEEK():Int {
            return p < end ? mbcToCode(pat, p, end) : 0;
        }

        if (tok.codePointContinue != 0) {
            pr.v = p;
            r = getNextCodePoint(pr, end, tok.base_num, pat, true, code);
            p = pr.v;
            if (r == 1) {
                tok.codePointContinue = 0;
            }
            else if (r == 2) {
                tok.type = TK_CC_RANGE;
                src.v = p;
                return tok.type;
            }
            else if (r == 0) {
                tok.type = TK_CODE_POINT;
                tok.code = code.v;
                src.v = p;
                return tok.type;
            }
            else
                return r; /* error */
        }

        if (p >= end) {
            tok.type = TK_EOT;
            return tok.type;
        }

        pfetchPrev = p;
        c = mbcToCode(pat, p, end);
        p += enclen(pat, p);
        tok.type = TK_CHAR;
        tok.base_num = 0;
        tok.code = c;
        tok.escaped = false;

        if (c == ']'.code) {
            tok.type = TK_CC_CLOSE;
        }
        else if (c == '-'.code) {
            tok.type = TK_CC_RANGE;
        }
        else if (c == syn.metaEsc) {
            if (!IS_SYNTAX_BV(syn, ONIG_SYN_BACKSLASH_ESCAPE_IN_CC)) {
                src.v = p;
                return tok.type;
            }

            if (p >= end) return ONIGERR_END_PATTERN_AT_ESCAPE;

            pfetchPrev = p;
            c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            tok.escaped = true;
            tok.code = c;
            switch (c) {
                case 'w'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_WORD;
                    tok.propNot = 0;
                case 'W'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_WORD;
                    tok.propNot = 1;
                case 'd'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_DIGIT;
                    tok.propNot = 0;
                case 'D'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_DIGIT;
                    tok.propNot = 1;
                case 's'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_SPACE;
                    tok.propNot = 0;
                case 'S'.code:
                    tok.type = TK_CHAR_TYPE;
                    tok.propCtype = ONIGENC_CTYPE_SPACE;
                    tok.propNot = 1;
                case 'h'.code:
                    if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_H_XDIGIT)) {
                        tok.type = TK_CHAR_TYPE;
                        tok.propCtype = ONIGENC_CTYPE_XDIGIT;
                        tok.propNot = 0;
                    }
                case 'H'.code:
                    if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_H_XDIGIT)) {
                        tok.type = TK_CHAR_TYPE;
                        tok.propCtype = ONIGENC_CTYPE_XDIGIT;
                        tok.propNot = 1;
                    }

                case 'p'.code, 'P'.code:
                    if (p < end) {
                        c2 = PPEEK();
                        if (c2 == '{'.code && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_P_BRACE_CHAR_PROPERTY)) {
                            pfetchPrev = p;
                            p += enclen(pat, p);
                            tok.type = TK_CHAR_PROPERTY;
                            tok.propNot = c == 'P'.code ? 1 : 0;

                            if (p < end && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT)) {
                                pfetchPrev = p;
                                c2 = mbcToCode(pat, p, end);
                                p += enclen(pat, p);
                                if (c2 == '^'.code) {
                                    tok.propNot = tok.propNot == 0 ? 1 : 0;
                                }
                                else
                                    p = pfetchPrev;
                            }
                        }
                    }

                case 'o'.code, 'x'.code:
                    if (p < end) {
                        var prev = p;
                        var isO = c == 'o'.code;
                        var braceOk = isO ? IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_O_BRACE_OCTAL) : IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_X_BRACE_HEX8);
                        if (PPEEK() == '{'.code && braceOk) {
                            pfetchPrev = p;
                            p += enclen(pat, p);
                            pr.v = p;
                            r = isO ? scanOctalNumber(pr, end, 0, 11, pat, code) : scanHexadecimalNumber(pr, end, 0, 8, pat, code);
                            if (r < 0) return r;
                            p = pr.v;
                            if (p < end) {
                                c2 = PPEEK();
                                if (isO ? IS_CODE_DIGIT_ASCII(c2) : IS_CODE_XDIGIT_ASCII(c2))
                                    return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                            }

                            tok.base_num = isO ? 8 : 16;
                            // brace_code_point_entry:
                            if (p > prev + enclen(pat, prev)) {
                                if (p >= end) return ONIGERR_INVALID_CODE_POINT_VALUE;
                                if (PPEEK() == '}'.code) {
                                    pfetchPrev = p;
                                    p += enclen(pat, p);
                                }
                                else {
                                    var currState = (state == CS_RANGE) ? CPS_EMPTY : CPS_START;
                                    r = checkCodePointSequenceCc(p, end, tok.base_num, pat, currState);
                                    if (r < 0) return r;
                                    if (r == 0) return ONIGERR_INVALID_CODE_POINT_VALUE;
                                    tok.codePointContinue = 1;
                                }
                                tok.type = TK_CODE_POINT;
                                tok.code = code.v;
                            }
                            else {
                                /* can't read nothing or invalid format */
                                p = prev;
                            }
                        }
                        else if (!isO && IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_X_HEX2)) {
                            pr.v = p;
                            r = scanHexadecimalNumber(pr, end, 0, 2, pat, code);
                            if (r < 0) return r;
                            p = pr.v;
                            if (p == prev) { /* can't read nothing. */
                                code.v = 0; /* but, it's not error */
                            }
                            tok.type = TK_CRUDE_BYTE;
                            tok.base_num = 16;
                            tok.byte = code.v;
                        }
                    }

                case 'u'.code, 'U'.code:
                    if (p < end) {
                        var prev = p;
                        var digits = -1;
                        if (c == 'u'.code) {
                            if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_U_HEX4)) digits = 4;
                        }
                        else {
                            if (IS_SYNTAX_BV(syn, ONIG_SYN_PYTHON)) digits = 8;
                        }
                        if (digits > 0) {
                            pr.v = p;
                            r = scanHexadecimalNumber(pr, end, digits, digits, pat, code);
                            if (r < 0) return r;
                            p = pr.v;
                            if (p == prev) { /* can't read nothing. */
                                code.v = 0; /* but, it's not error */
                            }
                            tok.type = TK_CODE_POINT;
                            tok.base_num = 16;
                            tok.code = code.v;
                        }
                    }

                case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code:
                    if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_OCTAL3)) {
                        p = pfetchPrev;
                        var prev = p;
                        pr.v = p;
                        r = scanOctalNumber(pr, end, 0, 3, pat, code);
                        if (r < 0) return r;
                        p = pr.v;
                        if (code.v >= 256) return ONIGERR_TOO_BIG_NUMBER;
                        if (p == prev) { /* can't read nothing. */
                            code.v = 0; /* but, it's not error */
                        }
                        tok.type = TK_CRUDE_BYTE;
                        tok.base_num = 8;
                        tok.byte = code.v;
                    }

                default:
                    p = pfetchPrev;
                    pr.v = p;
                    var cv = new IntRef();
                    r = fetchEscapedValue(pr, end, env, cv);
                    if (r < 0) return r;
                    p = pr.v;
                    if (tok.code != cv.v) {
                        tok.code = cv.v;
                        tok.type = TK_CODE_POINT;
                    }
            }
        }
        else if (c == '['.code) {
            var ccInCc = false;
            if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_POSIX_BRACKET) && PPEEK() == ':'.code) {
                var send = [':'.code, ']'.code];
                tok.backp = p; /* point at '[' is read */
                pfetchPrev = p;
                p += enclen(pat, p);
                if (strExistCheckWithEsc(send, 2, pat, p, end, ']'.code, syn)) {
                    tok.type = TK_CC_POSIX_BRACKET_OPEN;
                }
                else {
                    p = pfetchPrev;
                    ccInCc = true;
                }
            }
            else {
                ccInCc = true;
            }
            if (ccInCc) {
                if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_CCLASS_SET_OP)) {
                    tok.type = TK_CC_OPEN_CC;
                }
            }
        }
        else if (c == '&'.code) {
            if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_CCLASS_SET_OP) && p < end && PPEEK() == '&'.code) {
                pfetchPrev = p;
                p += enclen(pat, p);
                tok.type = TK_CC_AND;
            }
        }

        src.v = p;
        return tok.type;
    }

    static function fetchToken(tok:PToken, src:IntRef, end:Int, env:ParseEnv):Int {
        var pat = env.pattern;
        var syn = env.syntax;
        var p = src.v;
        var pfetchPrev = p;
        var c:Int = 0;
        var r:Int;
        var code = new IntRef();
        var pr = new IntRef();
        var prev:Int;

        inline function PPEEK():Int {
            return p < end ? mbcToCode(pat, p, end) : 0;
        }

        inline function PFETCH():Int {
            var cc = mbcToCode(pat, p, end);
            pfetchPrev = p;
            p += enclen(pat, p);
            return cc;
        }

        inline function PINC():Void {
            pfetchPrev = p;
            p += enclen(pat, p);
        }

        // greedy_check (stage 0), greedy_check2 (stage 1), possessive_check (stage 2)
        function greedyCheck(stage:Int):Void {
            if (stage == 0)
                tok.repeatPossessive = 0;
            if (stage <= 1 && p < end && PPEEK() == '?'.code && IS_SYNTAX_OP(syn, ONIG_SYN_OP_QMARK_NON_GREEDY)
                    && tok.repeatPossessive == 0) {
                PFETCH();
                tok.repeatGreedy = 0;
                tok.repeatPossessive = 0;
            }
            else {
                // possessive_check:
                tok.repeatGreedy = 1;
                if (p < end && PPEEK() == '+'.code
                        && ((IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_PLUS_POSSESSIVE_REPEAT) && tok.type != TK_INTERVAL)
                            || (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL) && tok.type == TK_INTERVAL))
                        && tok.repeatPossessive == 0) {
                    PFETCH();
                    tok.repeatPossessive = 1;
                }
            }
        }

        // fetch_interval result handling (shared by '{' and '\{')
        function intervalCheck():Int {
            pr.v = p;
            var rr = fetchInterval(pr, end, tok, env);
            p = pr.v;
            if (rr < 0) return rr; /* error */
            if (rr == 0) greedyCheck(1);
            else if (rr == 2) { /* {n} */
                if (IS_SYNTAX_BV(syn, ONIG_SYN_FIXED_INTERVAL_IS_GREEDY_ONLY))
                    greedyCheck(2);
                else
                    greedyCheck(1);
            }
            /* r == 1 : normal char */
            return 0;
        }

        // backref_start:
        function backrefStart(c:Int, allowNum:Bool):Int {
            var prev = p;
            var nameEnd = new IntRef();
            var backNum = new IntRef();
            var level = new IntRef(tok.backrefLevel);
            var numType = new IntRef();
            pr.v = p;
            var rr = fetchNameWithLevel(c, pr, end, nameEnd, env, backNum, level, numType);
            p = pr.v;
            tok.backrefLevel = level.v;
            if (rr == 1) tok.backrefExistLevel = 1;
            else tok.backrefExistLevel = 0;
            if (rr < 0) return rr;

            if (numType.v != IS_NOT_NUM) {
                if (!allowNum) return ONIGERR_INVALID_BACKREF;
                var bn = backNum.v;
                if (numType.v == IS_REL_NUM) {
                    bn = backrefRelToAbs(bn, env);
                }
                if (bn <= 0)
                    return ONIGERR_INVALID_BACKREF;

                if (IS_SYNTAX_BV(syn, ONIG_SYN_STRICT_CHECK_BACKREF)) {
                    if (bn > env.numMem || env.memEnv[bn].memNode == null)
                        return ONIGERR_INVALID_BACKREF;
                }
                tok.type = TK_BACKREF;
                tok.backrefByName = 0;
                tok.backrefNum = 1;
                tok.backrefRef1 = bn;
            }
            else {
                var backsRef:Array<Array<Int>> = [null];
                var num = nameToGroupNumbers(env, pat, prev, nameEnd.v, backsRef);
                if (num <= 0) {
                    return ONIGERR_UNDEFINED_NAME_REFERENCE;
                }
                var backs = backsRef[0];
                if (IS_SYNTAX_BV(syn, ONIG_SYN_STRICT_CHECK_BACKREF)) {
                    for (i in 0...num) {
                        if (backs[i] > env.numMem || env.memEnv[backs[i]].memNode == null)
                            return ONIGERR_INVALID_BACKREF;
                    }
                }
                tok.type = TK_BACKREF;
                tok.backrefByName = 1;
                if (num == 1) {
                    tok.backrefNum = 1;
                    tok.backrefRef1 = backs[0];
                }
                else {
                    tok.backrefNum = num;
                    tok.backrefRefs = backs;
                }
            }
            return 0;
        }

        // call_start:
        function callStart(c:Int, allowNum:Bool):Int {
            var prev = p;
            var nameEnd = new IntRef();
            var gnum = new IntRef();
            var numType = new IntRef();
            pr.v = p;
            var rr = fetchName(c, pr, end, nameEnd, env, gnum, numType, true);
            p = pr.v;
            if (rr < 0) return rr;

            if (numType.v != IS_NOT_NUM) {
                if (!allowNum) return ONIGERR_UNDEFINED_GROUP_REFERENCE;
                var g = gnum.v;
                if (numType.v == IS_REL_NUM) {
                    g = backrefRelToAbs(g, env);
                    if (g < 0) {
                        onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_NAME_REFERENCE, pat, prev, nameEnd.v);
                        return ONIGERR_UNDEFINED_GROUP_REFERENCE;
                    }
                }
                tok.callByNumber = 1;
                tok.callGnum = g;
            }
            else {
                tok.callByNumber = 0;
                tok.callGnum = 0;
            }
            tok.type = TK_CALL;
            tok.callName = prev;
            tok.callNameEnd = nameEnd.v;
            return 0;
        }

        if (tok.codePointContinue != 0) {
            pr.v = p;
            r = getNextCodePoint(pr, end, tok.base_num, pat, false, code);
            p = pr.v;
            if (r == 1) {
                tok.codePointContinue = 0;
            }
            else if (r == 0) {
                tok.type = TK_CODE_POINT;
                tok.code = code.v;
                src.v = p;
                return tok.type;
            }
            else
                return r; /* error */
        }

        while (true) { // start:
            if (p >= end) {
                tok.type = TK_EOT;
                return tok.type;
            }

            tok.type = TK_STRING;
            tok.base_num = 0;
            tok.backp = p;

            c = PFETCH();
            if (IS_MC_ESC_CODE(c, syn)) {
                if (p >= end) return ONIGERR_END_PATTERN_AT_ESCAPE;

                tok.backp = p;
                c = PFETCH();

                tok.code = c;
                tok.escaped = true;
                switch (c) {
                    case '*'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_ASTERISK_ZERO_INF)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 0;
                            tok.repeatUpper = INFINITE_REPEAT;
                            greedyCheck(0);
                        }

                    case '+'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_PLUS_ONE_INF)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 1;
                            tok.repeatUpper = INFINITE_REPEAT;
                            greedyCheck(0);
                        }

                    case '?'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_QMARK_ZERO_ONE)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 0;
                            tok.repeatUpper = 1;
                            greedyCheck(0);
                        }

                    case '{'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_BRACE_INTERVAL)) {
                            r = intervalCheck();
                            if (r < 0) return r;
                        }

                    case '|'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_VBAR_ALT))
                            tok.type = TK_ALT;

                    case '('.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_LPAREN_SUBEXP))
                            tok.type = TK_SUBEXP_OPEN;

                    case ')'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_LPAREN_SUBEXP))
                            tok.type = TK_SUBEXP_CLOSE;

                    case 'w'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_W_WORD)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_WORD;
                            tok.propNot = 0;
                        }

                    case 'W'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_W_WORD)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_WORD;
                            tok.propNot = 1;
                        }

                    case 'b'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_B_WORD_BOUND)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_WORD_BOUNDARY;
                        }

                    case 'B'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_B_WORD_BOUND)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_NO_WORD_BOUNDARY;
                        }

                    case 'y'.code:
                        // upstream tests ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT against syn->op (kept as is)
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_TEXT_SEGMENT_BOUNDARY;
                        }

                    case 'Y'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_NO_TEXT_SEGMENT_BOUNDARY;
                        }

                    case '<'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_WORD_BEGIN;
                        }

                    case '>'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END)) {
                            tok.type = TK_ANCHOR;
                            tok.anchor = ANCR_WORD_END;
                        }

                    case 's'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_S_WHITE_SPACE)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_SPACE;
                            tok.propNot = 0;
                        }

                    case 'S'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_S_WHITE_SPACE)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_SPACE;
                            tok.propNot = 1;
                        }

                    case 'd'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_D_DIGIT)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_DIGIT;
                            tok.propNot = 0;
                        }

                    case 'D'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_D_DIGIT)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_DIGIT;
                            tok.propNot = 1;
                        }

                    case 'h'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_H_XDIGIT)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_XDIGIT;
                            tok.propNot = 0;
                        }

                    case 'H'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_H_XDIGIT)) {
                            tok.type = TK_CHAR_TYPE;
                            tok.propCtype = ONIGENC_CTYPE_XDIGIT;
                            tok.propNot = 1;
                        }

                    case 'K'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_CAPITAL_K_KEEP))
                            tok.type = TK_KEEP;

                    case 'R'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE))
                            tok.type = TK_GENERAL_NEWLINE;

                    case 'N'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT))
                            tok.type = TK_NO_NEWLINE;

                    case 'O'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT))
                            tok.type = TK_TRUE_ANYCHAR;

                    case 'X'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT))
                            tok.type = TK_TEXT_SEGMENT;

                    case 'A'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_BEGIN_BUF;
                        }

                    case 'Z'.code:
                        if (IS_SYNTAX_BV(syn, ONIG_SYN_PYTHON)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_END_BUF;
                        }
                        else {
                            if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR)) {
                                tok.type = TK_ANCHOR;
                                tok.subtype = ANCR_SEMI_END_BUF;
                            }
                        }

                    case 'z'.code:
                        if (IS_SYNTAX_BV(syn, ONIG_SYN_PYTHON))
                            return ONIGERR_UNDEFINED_OPERATOR;
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_END_BUF;
                        }

                    case 'G'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_CAPITAL_G_BEGIN_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_BEGIN_POSITION;
                        }

                    case '`'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_GNU_BUF_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_BEGIN_BUF;
                        }

                    case "'".code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_GNU_BUF_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = ANCR_END_BUF;
                        }

                    case 'o'.code, 'x'.code:
                        if (p < end) {
                            prev = p;
                            var isO = c == 'o'.code;
                            var braceOk = isO ? IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_O_BRACE_OCTAL) : IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_X_BRACE_HEX8);
                            if (PPEEK() == '{'.code && braceOk) {
                                PINC();
                                pr.v = p;
                                r = isO ? scanOctalNumber(pr, end, 0, 11, pat, code) : scanHexadecimalNumber(pr, end, 0, 8, pat, code);
                                if (r < 0) return r;
                                p = pr.v;
                                if (p < end) {
                                    if (isO ? IS_CODE_DIGIT_ASCII(PPEEK()) : IS_CODE_XDIGIT_ASCII(PPEEK()))
                                        return ONIGERR_TOO_LONG_WIDE_CHAR_VALUE;
                                }

                                tok.base_num = isO ? 8 : 16;
                                // brace_code_point_entry:
                                if (p > prev + enclen(pat, prev)) {
                                    if (p >= end) return ONIGERR_INVALID_CODE_POINT_VALUE;
                                    if (PPEEK() == '}'.code) {
                                        PINC();
                                    }
                                    else {
                                        r = checkCodePointSequence(p, end, tok.base_num, pat);
                                        if (r < 0) return r;
                                        if (r == 0) return ONIGERR_INVALID_CODE_POINT_VALUE;
                                        tok.codePointContinue = 1;
                                    }
                                    tok.type = TK_CODE_POINT;
                                    tok.code = code.v;
                                }
                                else {
                                    /* can't read nothing or invalid format */
                                    p = prev;
                                }
                            }
                            else if (!isO && IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_X_HEX2)) {
                                pr.v = p;
                                r = scanHexadecimalNumber(pr, end, 0, 2, pat, code);
                                if (r < 0) return r;
                                p = pr.v;
                                if (p == prev) { /* can't read nothing. */
                                    code.v = 0; /* but, it's not error */
                                }
                                tok.type = TK_CRUDE_BYTE;
                                tok.base_num = 16;
                                tok.byte = code.v;
                            }
                        }

                    case 'u'.code, 'U'.code:
                        if (p < end) {
                            prev = p;
                            var digits = -1;
                            if (c == 'u'.code) {
                                if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_U_HEX4)) digits = 4;
                            }
                            else {
                                if (IS_SYNTAX_BV(syn, ONIG_SYN_PYTHON)) digits = 8;
                            }
                            if (digits > 0) {
                                pr.v = p;
                                r = scanHexadecimalNumber(pr, end, digits, digits, pat, code);
                                if (r < 0) return r;
                                p = pr.v;
                                if (p == prev) { /* can't read nothing. */
                                    code.v = 0; /* but, it's not error */
                                }
                                tok.type = TK_CODE_POINT;
                                tok.base_num = 16;
                                tok.code = code.v;
                            }
                        }

                    case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code:
                        var toOctal = c == '0'.code;
                        var done = false;
                        if (c != '0'.code) {
                            p = pfetchPrev;
                            prev = p;
                            pr.v = p;
                            r = scanNumber(pr, end, pat);
                            p = pr.v;
                            var skipBackref = (r < 0 || r > ONIG_MAX_BACKREF_NUM);
                            if (!skipBackref && IS_SYNTAX_OP(syn, ONIG_SYN_OP_DECIMAL_BACKREF)
                                    && (r <= env.numMem || r <= 9)) { /* This spec. from GNU regex */
                                if (IS_SYNTAX_BV(syn, ONIG_SYN_STRICT_CHECK_BACKREF)) {
                                    if (r > env.numMem || env.memEnv[r].memNode == null)
                                        return ONIGERR_INVALID_BACKREF;
                                }
                                tok.type = TK_BACKREF;
                                tok.backrefNum = 1;
                                tok.backrefRef1 = r;
                                tok.backrefByName = 0;
                                tok.backrefExistLevel = 0;
                                done = true;
                            }
                            if (!done) {
                                // skip_backref:
                                if (c == '8'.code || c == '9'.code) {
                                    /* normal char */
                                    p = prev;
                                    PINC();
                                    done = true;
                                }
                                else {
                                    p = prev;
                                    toOctal = true;
                                }
                            }
                        }
                        if (!done && toOctal) {
                            // case '0':
                            if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ESC_OCTAL3)) {
                                prev = p;
                                pr.v = p;
                                r = scanOctalNumber(pr, end, 0, (c == '0'.code ? 2 : 3), pat, code);
                                if (r < 0 || r >= 256) return ONIGERR_TOO_BIG_NUMBER;
                                p = pr.v;
                                if (p == prev) { /* can't read nothing. */
                                    code.v = 0; /* but, it's not error */
                                }
                                tok.type = TK_CRUDE_BYTE;
                                tok.base_num = 8;
                                tok.byte = code.v;
                            }
                            else if (c != '0'.code) {
                                PINC();
                            }
                        }

                    case 'k'.code:
                        if (p < end && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_K_NAMED_BACKREF)) {
                            c = PFETCH();
                            if (c == '<'.code || c == "'".code) {
                                r = backrefStart(c, true);
                                if (r < 0) return r;
                            }
                            else
                                p = pfetchPrev;
                        }

                    case 'g'.code:
                        if (p < end && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_G_SUBEXP_CALL)) {
                            c = PFETCH();
                            if (c == '<'.code || c == "'".code) {
                                r = callStart(c, true);
                                if (r < 0) return r;
                            }
                            else
                                p = pfetchPrev;
                        }

                    case 'Q'.code:
                        if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_CAPITAL_Q_QUOTE)) {
                            tok.type = TK_QUOTE_OPEN;
                        }

                    case 'p'.code, 'P'.code:
                        if (p < end && PPEEK() == '{'.code && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_P_BRACE_CHAR_PROPERTY)) {
                            PINC();
                            tok.type = TK_CHAR_PROPERTY;
                            tok.propNot = c == 'P'.code ? 1 : 0;

                            if (p < end && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT)) {
                                c = PFETCH();
                                if (c == '^'.code) {
                                    tok.propNot = tok.propNot == 0 ? 1 : 0;
                                }
                                else
                                    p = pfetchPrev;
                            }
                        }

                    default:
                        p = pfetchPrev;
                        pr.v = p;
                        var c2 = new IntRef();
                        r = fetchEscapedValue(pr, end, env, c2);
                        if (r < 0) return r;
                        p = pr.v;
                        if (tok.code != c2.v) {
                            tok.type = TK_CODE_POINT;
                            tok.code = c2.v;
                        }
                        else { /* string */
                            p = tok.backp + enclen(pat, tok.backp);
                        }
                }
            }
            else {
                tok.code = c;
                tok.escaped = false;

                var restart = false;
                var metaHandled = false;
                if (c != ONIG_INEFFECTIVE_META_CHAR && IS_SYNTAX_OP(syn, ONIG_SYN_OP_VARIABLE_META_CHARACTERS)) {
                    if (c == syn.metaAnychar) {
                        tok.type = TK_ANYCHAR;
                        metaHandled = true;
                    }
                    else if (c == syn.metaAnytime) {
                        tok.type = TK_REPEAT;
                        tok.repeatLower = 0;
                        tok.repeatUpper = INFINITE_REPEAT;
                        greedyCheck(0);
                        metaHandled = true;
                    }
                    else if (c == syn.metaZeroOrOneTime) {
                        tok.type = TK_REPEAT;
                        tok.repeatLower = 0;
                        tok.repeatUpper = 1;
                        greedyCheck(0);
                        metaHandled = true;
                    }
                    else if (c == syn.metaOneOrMoreTime) {
                        tok.type = TK_REPEAT;
                        tok.repeatLower = 1;
                        tok.repeatUpper = INFINITE_REPEAT;
                        greedyCheck(0);
                        metaHandled = true;
                    }
                    else if (c == syn.metaAnycharAnytime) {
                        tok.type = TK_ANYCHAR_ANYTIME;
                        metaHandled = true;
                    }
                }

                if (!metaHandled) switch (c) {
                    case '.'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_DOT_ANYCHAR))
                            tok.type = TK_ANYCHAR;

                    case '*'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_ASTERISK_ZERO_INF)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 0;
                            tok.repeatUpper = INFINITE_REPEAT;
                            greedyCheck(0);
                        }

                    case '+'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_PLUS_ONE_INF)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 1;
                            tok.repeatUpper = INFINITE_REPEAT;
                            greedyCheck(0);
                        }

                    case '?'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_QMARK_ZERO_ONE)) {
                            tok.type = TK_REPEAT;
                            tok.repeatLower = 0;
                            tok.repeatUpper = 1;
                            greedyCheck(0);
                        }

                    case '{'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_BRACE_INTERVAL)) {
                            r = intervalCheck();
                            if (r < 0) return r;
                        }

                    case '|'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_VBAR_ALT))
                            tok.type = TK_ALT;

                    case '('.code:
                        var toEnd2 = false;
                        if (p < end && PPEEK() == '?'.code && IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_QMARK_GROUP_EFFECT)) {
                            prev = p;
                            PINC();
                            var qmarkEnd = true; // goto lparen_qmark_end (PUNFETCH)
                            if (p < end) {
                                c = PPEEK();
                                if (c == '#'.code) {
                                    c = PFETCH();
                                    while (true) {
                                        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                                        c = PFETCH();
                                        if (c == syn.metaEsc) {
                                            if (p < end) c = PFETCH();
                                        }
                                        else {
                                            if (c == ')'.code) break;
                                        }
                                    }
                                    restart = true;
                                    qmarkEnd = false;
                                }
                                else if (IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_QMARK_PERL_SUBEXP_CALL)) {
                                    var nameEnd = new IntRef();
                                    var gnum = new IntRef();
                                    var numType = new IntRef();
                                    var isNum = false;
                                    switch (c) {
                                        case '&'.code:
                                            PINC();
                                            var name = p;
                                            pr.v = p;
                                            r = fetchName('('.code, pr, end, nameEnd, env, gnum, numType, false);
                                            if (r < 0) return r;
                                            p = pr.v;
                                            tok.type = TK_CALL;
                                            tok.callByNumber = 0;
                                            tok.callGnum = 0;
                                            tok.callName = name;
                                            tok.callNameEnd = nameEnd.v;
                                            qmarkEnd = false;

                                        case 'R'.code:
                                            tok.type = TK_CALL;
                                            tok.callByNumber = 1;
                                            tok.callGnum = 0;
                                            tok.callName = p;
                                            PINC();
                                            if (PPEEK() != ')'.code) return ONIGERR_UNDEFINED_GROUP_OPTION;
                                            tok.callNameEnd = p;
                                            qmarkEnd = false;

                                        case '-'.code, '+'.code:
                                            isNum = true;
                                        default:
                                            if (isCodeCtype(c, ONIGENC_CTYPE_DIGIT)) isNum = true;
                                    }
                                    if (isNum) {
                                        // lparen_qmark_num:
                                        var name = p;
                                        pr.v = p;
                                        r = fetchName('('.code, pr, end, nameEnd, env, gnum, numType, true);
                                        if (r < 0) return r;
                                        p = pr.v;
                                        if (numType.v == IS_NOT_NUM) {
                                            return ONIGERR_INVALID_GROUP_NAME;
                                        }
                                        else {
                                            var g = gnum.v;
                                            if (numType.v == IS_REL_NUM) {
                                                g = backrefRelToAbs(g, env);
                                                if (g < 0) {
                                                    onigScanEnvSetErrorString(env, ONIGERR_UNDEFINED_NAME_REFERENCE, pat, name, nameEnd.v);
                                                    return ONIGERR_UNDEFINED_GROUP_REFERENCE;
                                                }
                                            }
                                            tok.callByNumber = 1;
                                            tok.callGnum = g;
                                        }
                                        tok.type = TK_CALL;
                                        tok.callName = name;
                                        tok.callNameEnd = nameEnd.v;
                                        qmarkEnd = false;
                                    }
                                }
                                else if (c == 'P'.code && IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_CAPITAL_P_NAME)) {
                                    PINC(); /* skip 'P' */
                                    if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                                    c = PFETCH();
                                    if (c == '='.code) {
                                        r = backrefStart('('.code, false);
                                        if (r < 0) return r;
                                        qmarkEnd = false;
                                    }
                                    else if (c == '>'.code) {
                                        r = callStart('('.code, false);
                                        if (r < 0) return r;
                                        qmarkEnd = false;
                                    }
                                    else {
                                        p = prev;
                                        toEnd2 = true;
                                        qmarkEnd = false;
                                    }
                                }
                            }
                            if (qmarkEnd) {
                                // lparen_qmark_end:
                                p = pfetchPrev;
                                toEnd2 = true;
                            }
                        }
                        else {
                            toEnd2 = true;
                        }
                        if (toEnd2) {
                            // lparen_qmark_end2:
                            if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_LPAREN_SUBEXP))
                                tok.type = TK_SUBEXP_OPEN;
                        }

                    case ')'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_LPAREN_SUBEXP))
                            tok.type = TK_SUBEXP_CLOSE;

                    case '^'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_LINE_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = OPTON_SINGLELINE(env.options) ? ANCR_BEGIN_BUF : ANCR_BEGIN_LINE;
                        }

                    case '$'.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_LINE_ANCHOR)) {
                            tok.type = TK_ANCHOR;
                            tok.subtype = OPTON_SINGLELINE(env.options) ? ANCR_SEMI_END_BUF : ANCR_END_LINE;
                        }

                    case '['.code:
                        if (IS_SYNTAX_OP(syn, ONIG_SYN_OP_BRACKET_CC))
                            tok.type = TK_OPEN_CC;

                    case ']'.code:
                        /* /].../ is allowed. (warning only) */

                    case '#'.code:
                        if (OPTON_EXTEND(env.options)) {
                            while (p < end) {
                                c = PFETCH();
                                if (isCodeNewline(c))
                                    break;
                            }
                            restart = true;
                        }

                    case ' '.code, '\t'.code, '\n'.code, '\r'.code, 0x0c:
                        if (OPTON_EXTEND(env.options))
                            restart = true;

                    default:
                        /* string */
                }
                if (restart) continue;
            }
            break;
        }

        // out:
        src.v = p;
        return tok.type;
    }

    static inline function CR_NUM(mbr:IntArray):Int return mbr[0];
    static inline function CR_FROM(mbr:IntArray, i:Int):Int return mbr[i * 2 + 1];
    static inline function CR_TO(mbr:IntArray, i:Int):Int return mbr[i * 2 + 2];

    static function addCtypeToCcByRange(cc:Node, ctype:Int, not:Bool, sbOut:Int, mbr:IntArray):Int {
        var r:Int;
        var n = CR_NUM(mbr);
        var mb = new BBufRef(cc.mbuf);

        if (!not) {
            var i = 0;
            var sbEnd = false;
            while (i < n) {
                var j = CR_FROM(mbr, i);
                while (ule(j, CR_TO(mbr, i))) {
                    if (uge(j, sbOut)) {
                        if (ugt(j, CR_FROM(mbr, i))) {
                            r = addCodeRangeToBuf(mb, j, CR_TO(mbr, i));
                            if (r != 0) { cc.mbuf = mb.v; return r; }
                            i++;
                        }
                        sbEnd = true;
                        break;
                    }
                    BITSET_SET_BIT(cc.bs, j);
                    j++;
                }
                if (sbEnd) break;
                i++;
            }
            // sb_end:
            while (i < n) {
                r = addCodeRangeToBuf(mb, CR_FROM(mbr, i), CR_TO(mbr, i));
                if (r != 0) { cc.mbuf = mb.v; return r; }
                i++;
            }
        }
        else {
            var prev = 0;
            var toSbEnd2 = false;
            for (i in 0...n) {
                var j = prev;
                while (ult(j, CR_FROM(mbr, i))) {
                    if (uge(j, sbOut)) {
                        toSbEnd2 = true;
                        break;
                    }
                    BITSET_SET_BIT(cc.bs, j);
                    j++;
                }
                if (toSbEnd2) break;
                prev = CR_TO(mbr, i) + 1;
            }
            if (!toSbEnd2) {
                var j = prev;
                while (ult(j, sbOut)) {
                    BITSET_SET_BIT(cc.bs, j);
                    j++;
                }
            }

            // sb_end2:
            prev = sbOut;
            var toEnd = false;
            for (i in 0...n) {
                if (ult(prev, CR_FROM(mbr, i))) {
                    r = addCodeRangeToBuf(mb, prev, CR_FROM(mbr, i) - 1);
                    if (r != 0) { cc.mbuf = mb.v; return r; }
                }
                prev = CR_TO(mbr, i) + 1;
                if (prev == 0) { toEnd = true; break; }
            }
            if (!toEnd) {
                r = addCodeRangeToBuf(mb, prev, MAX_CODE_POINT);
                if (r != 0) { cc.mbuf = mb.v; return r; }
            }
        }
        cc.mbuf = mb.v;
        return 0;
    }

    static function addCtypeToCcByRangeLimit(cc:Node, ctype:Int, not:Bool, sbOut:Int, mbr:IntArray, limit:Int):Int {
        var r:Int;
        var n = CR_NUM(mbr);
        var mb = new BBufRef(cc.mbuf);
        var from:Int;
        var to:Int;

        if (!not) {
            var i = 0;
            var sbEnd = false;
            var toEnd = false;
            while (i < n) {
                var j = CR_FROM(mbr, i);
                while (ule(j, CR_TO(mbr, i))) {
                    if (ugt(j, limit)) { toEnd = true; break; }
                    if (uge(j, sbOut)) {
                        if (ugt(j, CR_FROM(mbr, i))) {
                            to = CR_TO(mbr, i);
                            if (ugt(to, limit)) to = limit;
                            r = addCodeRangeToBuf(mb, j, to);
                            if (r != 0) { cc.mbuf = mb.v; return r; }
                            i++;
                        }
                        sbEnd = true;
                        break;
                    }
                    BITSET_SET_BIT(cc.bs, j);
                    j++;
                }
                if (sbEnd || toEnd) break;
                i++;
            }
            if (!toEnd) {
                // sb_end:
                while (i < n) {
                    from = CR_FROM(mbr, i);
                    to = CR_TO(mbr, i);
                    if (ugt(from, limit)) break;
                    if (ugt(to, limit)) to = limit;
                    r = addCodeRangeToBuf(mb, from, to);
                    if (r != 0) { cc.mbuf = mb.v; return r; }
                    i++;
                }
            }
        }
        else {
            var prev = 0;
            var toSbEnd2 = false;
            var toEnd = false;
            for (i in 0...n) {
                from = CR_FROM(mbr, i);
                if (ugt(from, limit)) {
                    var j = prev;
                    while (ult(j, sbOut)) {
                        BITSET_SET_BIT(cc.bs, j);
                        j++;
                    }
                    toSbEnd2 = true;
                    break;
                }
                var j = prev;
                while (ult(j, from)) {
                    if (uge(j, sbOut)) { toSbEnd2 = true; break; }
                    BITSET_SET_BIT(cc.bs, j);
                    j++;
                }
                if (toSbEnd2) break;
                prev = CR_TO(mbr, i);
                if (ugt(prev, limit)) prev = limit;
                prev++;
                if (prev == 0) { toEnd = true; break; }
            }
            if (!toEnd) {
                if (!toSbEnd2) {
                    var j = prev;
                    while (ult(j, sbOut)) {
                        BITSET_SET_BIT(cc.bs, j);
                        j++;
                    }
                }
                // sb_end2:
                prev = sbOut;
                for (i in 0...n) {
                    from = CR_FROM(mbr, i);
                    if (ugt(from, limit)) break; // goto last
                    if (ult(prev, from)) {
                        r = addCodeRangeToBuf(mb, prev, from - 1);
                        if (r != 0) { cc.mbuf = mb.v; return r; }
                    }
                    prev = CR_TO(mbr, i);
                    if (ugt(prev, limit)) prev = limit;
                    prev++;
                    if (prev == 0) { toEnd = true; break; }
                }
                if (!toEnd) {
                    // last:
                    r = addCodeRangeToBuf(mb, prev, MAX_CODE_POINT);
                    if (r != 0) { cc.mbuf = mb.v; return r; }
                }
            }
        }
        cc.mbuf = mb.v;
        return 0;
    }

    static function addCtypeToCc(cc:Node, ctype:Int, not:Bool, env:ParseEnv):Int {
        var asciiMode = OPTON_IS_ASCII_MODE_CTYPE(ctype, env.options);
        var ranges = Unicode.onigencUnicodeCtypeCodeRange(ctype);
        if (ranges == null) return ONIGERR_TYPE_BUG;
        var sbOut = CTYPE_CODE_RANGE_SB_OUT;
        if (!asciiMode)
            return addCtypeToCcByRange(cc, ctype, not, sbOut, ranges);
        else
            return addCtypeToCcByRangeLimit(cc, ctype, not, sbOut, ranges, ASCII_LIMIT);
    }

    static final PBS_NAMES:Array<String> = ["alnum", "alpha", "blank", "cntrl", "digit", "graph", "lower", "print", "punct",
        "space", "upper", "xdigit", "ascii", "word"];
    static final PBS_CTYPES:Array<Int> = [ONIGENC_CTYPE_ALNUM, ONIGENC_CTYPE_ALPHA, ONIGENC_CTYPE_BLANK, ONIGENC_CTYPE_CNTRL,
        ONIGENC_CTYPE_DIGIT, ONIGENC_CTYPE_GRAPH, ONIGENC_CTYPE_LOWER, ONIGENC_CTYPE_PRINT, ONIGENC_CTYPE_PUNCT,
        ONIGENC_CTYPE_SPACE, ONIGENC_CTYPE_UPPER, ONIGENC_CTYPE_XDIGIT, ONIGENC_CTYPE_ASCII, ONIGENC_CTYPE_WORD];

    static function prsPosixBracket(cc:Node, src:IntRef, end:Int, env:ParseEnv):Int {
        var POSIX_BRACKET_CHECK_LIMIT_LENGTH = 20;
        var POSIX_BRACKET_NAME_MIN_LEN = 4;
        var pat = env.pattern;
        var p = src.v;
        var not:Bool;
        var r:Int;

        if (p < end && mbcToCode(pat, p, end) == '^'.code) {
            p += enclen(pat, p);
            not = true;
        }
        else
            not = false;

        if (onigencStrlen(pat, p, end) >= POSIX_BRACKET_NAME_MIN_LEN + 3) {
            for (k in 0...PBS_NAMES.length) {
                var name = PBS_NAMES[k];
                if (onigencWithAsciiStrncmp(pat, p, end, name, name.length) == 0) {
                    p = onigencStep(pat, p, end, name.length);
                    if (onigencWithAsciiStrncmp(pat, p, end, ":]", 2) != 0)
                        return ONIGERR_INVALID_POSIX_BRACKET_TYPE;
                    r = addCtypeToCc(cc, PBS_CTYPES[k], not, env);
                    if (r != 0) return r;
                    p += enclen(pat, p);
                    p += enclen(pat, p);
                    src.v = p;
                    return 0;
                }
            }
        }

        // not_posix_bracket:
        var c = 0;
        var i = 0;
        while (p < end && ((c = mbcToCode(pat, p, end)) != ':'.code) && c != ']'.code) {
            p += enclen(pat, p);
            if (++i > POSIX_BRACKET_CHECK_LIMIT_LENGTH) break;
        }
        if (c == ':'.code && p < end) {
            p += enclen(pat, p);
            if (p < end) {
                c = mbcToCode(pat, p, end);
                p += enclen(pat, p);
                if (c == ']'.code)
                    return ONIGERR_INVALID_POSIX_BRACKET_TYPE;
            }
        }
        return 1; /* 1: is not POSIX bracket, but no error. */
    }

    static function fetchCharPropertyToCtype(src:IntRef, end:Int, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var r = ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS;
        var start = p;
        var prev = p;
        while (p < end) {
            prev = p;
            var c = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            if (c == '}'.code) {
                r = Unicode.onigencUnicodePropertyNameToCtype(pat, start, prev);
                if (r >= 0) {
                    src.v = p;
                }
                else {
                    onigScanEnvSetErrorString(env, r, pat, src.v, prev);
                }
                return r;
            }
            else if (c == '('.code || c == ')'.code || c == '{'.code || c == '|'.code) {
                break;
            }
        }
        return r;
    }

    static function prsCharProperty(np:NodeRef, tok:PToken, src:IntRef, end:Int, env:ParseEnv):Int {
        var ctype = fetchCharPropertyToCtype(src, end, env);
        if (ctype < 0) return ctype;
        np.v = nodeNewCclass();
        var cc = np.v;
        var r = addCtypeToCc(cc, ctype, false, env);
        if (r != 0) return r;
        if (tok.propNot != 0) cc.flags |= FLAG_NCCLASS_NOT;
        return 0;
    }

    static function ccCpropNext(cc:Node, pcode:IntRef, val:IntRef, state:IntRef, env:ParseEnv):Int {
        if (state.v == CS_RANGE)
            return ONIGERR_CHAR_CLASS_VALUE_AT_END_OF_RANGE;
        if (state.v == CS_VALUE) {
            if (val.v == CV_SB)
                BITSET_SET_BIT(cc.bs, pcode.v);
            else if (val.v == CV_MB) {
                var mb = new BBufRef(cc.mbuf);
                var r = addCodeRange(mb, env, pcode.v, pcode.v);
                cc.mbuf = mb.v;
                if (r < 0) return r;
            }
        }
        state.v = CS_VALUE;
        val.v = CV_CPROP;
        return 0;
    }

    static function ccCharNext(cc:Node, from:IntRef, to:Int, fromRaw:IntRef, toRaw:Int, intype:Int, type:IntRef, state:IntRef, env:ParseEnv):Int {
        var r:Int;
        switch (state.v) {
            case CS_VALUE:
                if (type.v == CV_SB) {
                    if (ugt(from.v, 0xff))
                        return ONIGERR_INVALID_CODE_POINT_VALUE;
                    BITSET_SET_BIT(cc.bs, from.v);
                }
                else if (type.v == CV_MB) {
                    var mb = new BBufRef(cc.mbuf);
                    r = addCodeRange(mb, env, from.v, from.v);
                    cc.mbuf = mb.v;
                    if (r < 0) return r;
                }

            case CS_RANGE:
                var rangeEnd = false;
                if (intype == type.v) {
                    if (intype == CV_SB) {
                        if (ugt(from.v, 0xff) || ugt(to, 0xff))
                            return ONIGERR_INVALID_CODE_POINT_VALUE;
                        if (ugt(from.v, to)) {
                            if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC))
                                rangeEnd = true;
                            else
                                return ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS;
                        }
                        if (!rangeEnd)
                            bitsetSetRange(cc.bs, from.v, to);
                    }
                    else {
                        var mb = new BBufRef(cc.mbuf);
                        r = addCodeRange(mb, env, from.v, to);
                        cc.mbuf = mb.v;
                        if (r < 0) return r;
                    }
                }
                else {
                    if (ugt(from.v, to)) {
                        if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC))
                            rangeEnd = true;
                        else
                            return ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS;
                    }
                    if (!rangeEnd) {
                        bitsetSetRange(cc.bs, from.v, ult(to, 0xff) ? to : 0xff);
                        var mb = new BBufRef(cc.mbuf);
                        r = addCodeRange(mb, env, from.v, to);
                        cc.mbuf = mb.v;
                        if (r < 0) return r;
                    }
                }
                // ccs_range_end:
                state.v = CS_COMPLETE;

            case CS_COMPLETE, CS_START:
                state.v = CS_VALUE;

            default:
        }
        fromRaw.v = toRaw;
        from.v = to;
        type.v = intype;
        return 0;
    }

    static function codeExistCheck(c:Int, pat:Bytes, from:Int, end:Int, ignoreEscaped:Bool, env:ParseEnv):Bool {
        var inEsc = false;
        var p = from;
        while (p < end) {
            if (ignoreEscaped && inEsc) {
                inEsc = false;
            }
            else {
                var code = mbcToCode(pat, p, end);
                p += enclen(pat, p);
                if (code == c) return true;
                if (code == env.syntax.metaEsc) inEsc = true;
            }
        }
        return false;
    }

    static inline var J_NONE:Int = 0;
    static inline var J_ANY_CHAR_IN:Int = 1;
    static inline var J_VAL_ENTRY:Int = 2;
    static inline var J_VAL_ENTRY2:Int = 3;
    static inline var J_NEXT_CPROP:Int = 4;
    static inline var J_RANGE_END_VAL:Int = 5;

    static function prsCc(np:NodeRef, tok:PToken, src:IntRef, end:Int, env:ParseEnv):Int {
        var r:Int;
        var neg:Bool;
        var len:Int;
        var fetched:Bool;
        var andStart = false;
        var inCode = 0;
        var inRaw = 0;
        var inType = CV_UNDEF;
        var currCode = new IntRef();
        var currRaw = new IntRef();
        var currType = new IntRef(CV_UNDEF);
        var state = new IntRef(CS_START);
        var pat = env.pattern;
        var pr = new IntRef();

        np.v = null;
        env.parseDepth++;
        if (env.parseDepth > ParseDepthLimit)
            return ONIGERR_PARSE_DEPTH_LIMIT_OVER;

        var prevCc:Node = null;
        r = fetchTokenCc(tok, src, end, env, state.v);
        if (r == TK_CHAR && tok.code == '^'.code && !tok.escaped) {
            neg = true;
            r = fetchTokenCc(tok, src, end, env, state.v);
        }
        else {
            neg = false;
        }

        if (r < 0) return r;
        if (r == TK_CC_CLOSE) {
            if (!codeExistCheck(']'.code, pat, src.v, env.patternEnd, true, env))
                return ONIGERR_EMPTY_CHAR_CLASS;
            r = tok.type = TK_CHAR; /* allow []...] */
        }

        var node = nodeNewCclass();
        np.v = node;
        var cc = node;

        var p = src.v;
        while (r != TK_CC_CLOSE) {
            fetched = false;
            var jump = J_NONE;
            while (true) {
                if (jump == J_NONE) {
                    switch (r) {
                        case TK_CHAR:
                            jump = J_ANY_CHAR_IN;
                            continue;

                        case TK_CRUDE_BYTE:
                            /* tok->base_num != 0 : octal or hexadec. */
                            if (tok.base_num != 0) {
                                var buf = Bytes.alloc(ONIGENC_CODE_TO_MBC_MAXLEN);
                                var psave = p;
                                var baseNum = tok.base_num;
                                buf.set(0, tok.byte);
                                var i = 1;
                                while (i < ONIGENC_MBC_MAXLEN) {
                                    pr.v = p;
                                    r = fetchTokenCc(tok, pr, end, env, CS_COMPLETE);
                                    p = pr.v;
                                    if (r < 0) return r;
                                    if (r != TK_CRUDE_BYTE || tok.base_num != baseNum) {
                                        fetched = true;
                                        break;
                                    }
                                    buf.set(i, tok.byte);
                                    i++;
                                }
                                if (i < ONIGENC_MBC_MINLEN) {
                                    return ONIGERR_TOO_SHORT_MULTI_BYTE_STRING;
                                }
                                /* clear buf tail */
                                for (j in i...ONIGENC_CODE_TO_MBC_MAXLEN) buf.set(j, 0);

                                len = enclen(buf, 0);
                                if (i < len) {
                                    return ONIGERR_TOO_SHORT_MULTI_BYTE_STRING;
                                }
                                else if (i > len) { /* fetch back */
                                    p = psave;
                                    i = 1;
                                    while (i < len) {
                                        pr.v = p;
                                        r = fetchTokenCc(tok, pr, end, env, CS_COMPLETE);
                                        p = pr.v;
                                        if (r < 0) return r;
                                        i++;
                                    }
                                    fetched = false;
                                }

                                if (i == 1) {
                                    inCode = buf.get(0);
                                    inType = CV_SB;
                                }
                                else {
                                    inCode = mbcToCode(buf, 0, ONIGENC_CODE_TO_MBC_MAXLEN);
                                    inType = CV_MB;
                                }
                            }
                            else {
                                inCode = tok.byte;
                                inType = CV_SB;
                            }
                            inRaw = 1;
                            jump = J_VAL_ENTRY2;
                            continue;

                        case TK_CODE_POINT:
                            inCode = tok.code;
                            inRaw = 1;
                            jump = J_VAL_ENTRY;
                            continue;

                        case TK_CC_POSIX_BRACKET_OPEN:
                            pr.v = p;
                            r = prsPosixBracket(cc, pr, end, env);
                            p = pr.v;
                            if (r < 0) return r;
                            if (r == 1) { /* is not POSIX bracket */
                                p = tok.backp;
                                inCode = tok.code;
                                inRaw = 0;
                                jump = J_VAL_ENTRY;
                                continue;
                            }
                            jump = J_NEXT_CPROP;
                            continue;

                        case TK_CHAR_TYPE:
                            r = addCtypeToCc(cc, tok.propCtype, tok.propNot != 0, env);
                            if (r != 0) return r;
                            jump = J_NEXT_CPROP;
                            continue;

                        case TK_CHAR_PROPERTY:
                            pr.v = p;
                            var ctype = fetchCharPropertyToCtype(pr, end, env);
                            p = pr.v;
                            if (ctype < 0) {
                                return ctype;
                            }
                            r = addCtypeToCc(cc, ctype, tok.propNot != 0, env);
                            if (r != 0) return r;
                            jump = J_NEXT_CPROP;
                            continue;

                        case TK_CC_RANGE:
                            if (state.v == CS_VALUE) {
                                pr.v = p;
                                r = fetchTokenCc(tok, pr, end, env, CS_RANGE);
                                p = pr.v;
                                if (r < 0) return r;

                                fetched = true;
                                if (r == TK_CC_CLOSE) { /* allow [x-] */
                                    jump = J_RANGE_END_VAL;
                                    continue;
                                }
                                else if (r == TK_CC_AND) {
                                    jump = J_RANGE_END_VAL;
                                    continue;
                                }

                                if (currType.v == CV_CPROP) {
                                    return ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS;
                                }
                                state.v = CS_RANGE;
                            }
                            else if (state.v == CS_START) {
                                /* [-xa] is allowed */
                                inCode = tok.code;
                                inRaw = 0;

                                pr.v = p;
                                r = fetchTokenCc(tok, pr, end, env, CS_VALUE);
                                p = pr.v;
                                if (r < 0) return r;

                                fetched = true;
                                jump = J_VAL_ENTRY;
                                continue;
                            }
                            else if (state.v == CS_RANGE) {
                                jump = J_ANY_CHAR_IN; /* [!--] is allowed */
                                continue;
                            }
                            else { /* CS_COMPLETE */
                                pr.v = p;
                                r = fetchTokenCc(tok, pr, end, env, CS_VALUE);
                                p = pr.v;
                                if (r < 0) return r;

                                fetched = true;
                                if (r == TK_CC_CLOSE) {
                                    jump = J_RANGE_END_VAL; /* allow [a-b-] */
                                    continue;
                                }
                                else if (r == TK_CC_AND) {
                                    jump = J_RANGE_END_VAL;
                                    continue;
                                }

                                if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_DOUBLE_RANGE_OP_IN_CC)) {
                                    jump = J_RANGE_END_VAL; /* [0-9-a] is allowed as [0-9\-a] */
                                    continue;
                                }
                                return ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS;
                            }

                        case TK_CC_OPEN_CC: /* [ */
                            if (state.v == CS_VALUE) {
                                r = ccCharNext(cc, currCode, 0, currRaw, 0, currType.v, currType, state, env);
                                if (r != 0) return r;
                            }
                            state.v = CS_COMPLETE;

                            var anode = new NodeRef();
                            pr.v = p;
                            r = prsCc(anode, tok, pr, end, env);
                            p = pr.v;
                            if (r != 0) {
                                return r;
                            }
                            r = orCclass(cc, anode.v);
                            if (r != 0) return r;

                        case TK_CC_AND: /* && */
                            if (state.v == CS_VALUE) {
                                r = ccCharNext(cc, currCode, 0, currRaw, 0, currType.v, currType, state, env);
                                if (r != 0) return r;
                            }
                            /* initialize local variables */
                            andStart = true;
                            state.v = CS_START;

                            if (prevCc != null) {
                                r = andCclass(prevCc, cc);
                                if (r != 0) return r;
                            }
                            else {
                                prevCc = cc;
                                cc = new Node();
                                cc.nodeType = NODE_CCLASS;
                            }
                            initializeCclass(cc);

                        case TK_EOT:
                            return ONIGERR_PREMATURE_END_OF_CHAR_CLASS;

                        default:
                            return ONIGERR_PARSER_BUG;
                    }
                    break;
                }
                else if (jump == J_ANY_CHAR_IN) {
                    len = codeToMbclen(tok.code);
                    if (len < 0) {
                        return len;
                    }
                    inType = (len == 1) ? CV_SB : CV_MB;
                    inCode = tok.code;
                    inRaw = 0;
                    jump = J_VAL_ENTRY2;
                    continue;
                }
                else if (jump == J_RANGE_END_VAL) {
                    inCode = '-'.code;
                    inRaw = 0;
                    jump = J_VAL_ENTRY;
                    continue;
                }
                else if (jump == J_VAL_ENTRY) {
                    len = codeToMbclen(inCode);
                    if (len < 0) {
                        if (state.v != CS_RANGE || !IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_INVALID_CODE_END_OF_RANGE_IN_CC)
                                || ult(inCode, 0x100) || ONIGENC_MBC_MAXLEN == 1) {
                            return len;
                        }
                    }
                    inType = (len == 1 ? CV_SB : CV_MB);
                    jump = J_VAL_ENTRY2;
                    continue;
                }
                else if (jump == J_VAL_ENTRY2) {
                    r = ccCharNext(cc, currCode, inCode, currRaw, inRaw, inType, currType, state, env);
                    if (r != 0) return r;
                    break;
                }
                else if (jump == J_NEXT_CPROP) {
                    r = ccCpropNext(cc, currCode, currType, state, env);
                    if (r != 0) return r;
                    break;
                }
            }

            if (fetched)
                r = tok.type;
            else {
                pr.v = p;
                r = fetchTokenCc(tok, pr, end, env, state.v);
                p = pr.v;
                if (r < 0) return r;
            }
        }

        if (state.v == CS_VALUE) {
            r = ccCharNext(cc, currCode, 0, currRaw, 0, currType.v, currType, state, env);
            if (r != 0) return r;
        }

        if (prevCc != null) {
            r = andCclass(prevCc, cc);
            if (r != 0) return r;
            cc = prevCc;
        }

        if (neg)
            cc.flags |= FLAG_NCCLASS_NOT;
        else
            cc.flags &= ~FLAG_NCCLASS_NOT;
        if (cc.isNcclassNot() && IS_SYNTAX_BV(env.syntax, ONIG_SYN_NOT_NEWLINE_IN_NEGATIVE_CC)) {
            var isEmpty = cc.mbuf == null;
            if (isEmpty)
                isEmpty = bitsetIsEmpty(cc.bs);
            if (!isEmpty) {
                if (isCodeNewline(NEWLINE_CODE)) {
                    BITSET_SET_BIT(cc.bs, NEWLINE_CODE);
                }
            }
        }
        src.v = p;
        env.parseDepth--;
        return 0;
    }

    static inline function OPTION_NEGATE(v:Int, f:Int, negative:Bool):Int {
        return negative ? (v & ~f) : (v | f);
    }

    static function prsBag(np:NodeRef, tok:PToken, term:Int, src:IntRef, end:Int, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var pfetchPrev = p;
        var r:Int;
        var num:Int;
        var c:Int;
        var pr = new IntRef();
        var t = new NodeRef();

        inline function PPEEK():Int {
            return p < end ? mbcToCode(pat, p, end) : 0;
        }

        inline function PFETCH():Int {
            var cc = mbcToCode(pat, p, end);
            pfetchPrev = p;
            p += enclen(pat, p);
            return cc;
        }

        np.v = null;
        if (p >= end) return ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS;

        var option = env.options;
        c = PPEEK();
        var gotoGroup = false;
        var gotoEnd = false;
        if (c == '?'.code && IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_GROUP_EFFECT)) {
            pfetchPrev = p;
            p += enclen(pat, p);
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

            c = PFETCH();
            var namedGroup = false;
            var optionsStart = false;
            switch (c) {
                case ':'.code: /* (?:...) grouping only */
                    gotoGroup = true;

                case '='.code:
                    np.v = nodeNewAnchor(ANCR_PREC_READ);
                case '!'.code: /*         preceding read */
                    np.v = nodeNewAnchor(ANCR_PREC_READ_NOT);
                case '>'.code: /* (?>...) stop backtrack */
                    np.v = nodeNewBag(BAG_STOP_BACKTRACK);

                case "'".code:
                    if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP)) {
                        namedGroup = true;
                    }
                    else
                        return ONIGERR_UNDEFINED_GROUP_OPTION;

                case '<'.code: /* look behind (?<=...), (?<!...) */
                    if (p >= end) return ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS;
                    c = PFETCH();
                    if (c == '='.code)
                        np.v = nodeNewAnchor(ANCR_LOOK_BEHIND);
                    else if (c == '!'.code)
                        np.v = nodeNewAnchor(ANCR_LOOK_BEHIND_NOT);
                    else {
                        if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP)) {
                            p = pfetchPrev;
                            c = '<'.code;
                            namedGroup = true;
                        }
                        else {
                            return ONIGERR_UNDEFINED_GROUP_OPTION;
                        }
                    }

                case '~'.code:
                    if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_TILDE_ABSENT_GROUP)) {
                        var headBar:Bool;
                        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

                        var rangeClear = false;
                        if (PPEEK() == '|'.code) { /* (?~|generator|absent) */
                            pfetchPrev = p;
                            p += enclen(pat, p);
                            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

                            headBar = true;
                            if (PPEEK() == ')'.code) { /* (?~|)  : range clear */
                                pfetchPrev = p;
                                p += enclen(pat, p);
                                r = makeRangeClear(np, env);
                                if (r != 0) return r;
                                rangeClear = true;
                            }
                        }
                        else
                            headBar = false;

                        if (!rangeClear) {
                            pr.v = p;
                            r = fetchToken(tok, pr, end, env);
                            p = pr.v;
                            if (r < 0) return r;
                            var absentRef = new NodeRef();
                            pr.v = p;
                            r = prsAlts(absentRef, tok, term, pr, end, env, true);
                            p = pr.v;
                            if (r < 0) {
                                return r;
                            }
                            var absent = absentRef.v;

                            var expr:Node = null;
                            var isRangeCutter = false;
                            if (headBar) {
                                var top = absent;
                                if (top.nodeType != NODE_ALT || top.cdr == null) {
                                    expr = null;
                                    isRangeCutter = true;
                                }
                                else {
                                    absent = top.car;
                                    expr = top.cdr;
                                    top.car = null;
                                    top.cdr = null;
                                    if (expr.cdr == null) {
                                        top = expr;
                                        expr = top.car;
                                        top.car = null;
                                    }
                                }
                            }

                            r = makeAbsentTree(np, absent, expr, isRangeCutter, env);
                            if (r != 0) {
                                return r;
                            }
                        }
                        gotoEnd = true;
                    }
                    else {
                        return ONIGERR_UNDEFINED_GROUP_OPTION;
                    }

                case '{'.code:
                    if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS))
                        return ONIGERR_UNDEFINED_GROUP_OPTION;
                    pr.v = p;
                    r = Callout.prsCalloutOfContents(np, ')'.code, pr, end, env);
                    p = pr.v;
                    if (r != 0) return r;
                    gotoEnd = true;

                case '('.code:
                    /* (?()...) */
                    if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE)) {
                        var condition:Node = null;
                        var conditionIsChecker:Bool;

                        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                        c = PFETCH();
                        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

                        var anyCondition = false;
                        var endCondition = false;
                        conditionIsChecker = false;
                        if (IS_CODE_DIGIT_ASCII(c) || c == '-'.code || c == '+'.code || c == '<'.code || c == "'".code) {
                            var isEnclosed = (c == '<'.code || c == "'".code);
                            if (!isEnclosed)
                                p = pfetchPrev;
                            var prev = p;
                            var existLevel = false;
                            var nameEnd = new IntRef();
                            var backNum = new IntRef();
                            var level = new IntRef();
                            var numType = new IntRef();
                            pr.v = p;
                            r = fetchNameWithLevel(isEnclosed ? c : '('.code, pr, end, nameEnd, env, backNum, level, numType);
                            if (r == 1) existLevel = true;
                            if (r < 0) {
                                if (!isEnclosed) {
                                    anyCondition = true;
                                }
                                else
                                    return r;
                            }
                            else {
                                p = pr.v;
                                conditionIsChecker = true;
                                if (numType.v != IS_NOT_NUM) {
                                    var bn = backNum.v;
                                    if (numType.v == IS_REL_NUM) {
                                        bn = backrefRelToAbs(bn, env);
                                    }
                                    if (bn <= 0)
                                        return ONIGERR_INVALID_BACKREF;

                                    if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_STRICT_CHECK_BACKREF)) {
                                        if (bn > env.numMem || env.memEnv[bn].memNode == null)
                                            return ONIGERR_INVALID_BACKREF;
                                    }
                                    condition = nodeNewBackrefChecker(1, [bn], false, existLevel, level.v, env);
                                }
                                else {
                                    var backsRef:Array<Array<Int>> = [null];
                                    var n = nameToGroupNumbers(env, pat, prev, nameEnd.v, backsRef);
                                    if (n <= 0) {
                                        return ONIGERR_UNDEFINED_NAME_REFERENCE;
                                    }
                                    var backs = backsRef[0];
                                    if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_STRICT_CHECK_BACKREF)) {
                                        for (i in 0...n) {
                                            if (backs[i] > env.numMem || env.memEnv[backs[i]].memNode == null)
                                                return ONIGERR_INVALID_BACKREF;
                                        }
                                    }
                                    condition = nodeNewBackrefChecker(n, backs, true, existLevel, level.v, env);
                                }

                                if (isEnclosed) {
                                    if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP; // err_if_else
                                    c = PFETCH();
                                    if (c != ')'.code) return ONIGERR_END_PATTERN_IN_GROUP; // err_if_else
                                }
                            }
                        }
                        else if (c == '?'.code) {
                            if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS)) {
                                if (p < end && PPEEK() == '{'.code) {
                                    /* condition part is callouts of contents: (?(?{...})THEN|ELSE) */
                                    conditionIsChecker = false;
                                    c = PFETCH();
                                    var cr = new NodeRef();
                                    pr.v = p;
                                    r = Callout.prsCalloutOfContents(cr, ')'.code, pr, end, env);
                                    p = pr.v;
                                    if (r != 0) return r;
                                    condition = cr.v;
                                    endCondition = true;
                                }
                            }
                            if (!endCondition) anyCondition = true;
                        }
                        else if (c == '*'.code && IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME)) {
                            conditionIsChecker = false;
                            var cr = new NodeRef();
                            pr.v = p;
                            r = Callout.prsCalloutOfName(cr, ')'.code, pr, end, env);
                            p = pr.v;
                            if (r != 0) return r;
                            condition = cr.v;
                            endCondition = true;
                        }
                        else {
                            anyCondition = true;
                        }

                        if (anyCondition) {
                            p = pfetchPrev;
                            conditionIsChecker = false;
                            pr.v = p;
                            r = fetchToken(tok, pr, end, env);
                            p = pr.v;
                            if (r < 0) return r;
                            var cr = new NodeRef();
                            pr.v = p;
                            r = prsAlts(cr, tok, term, pr, end, env, false);
                            p = pr.v;
                            if (r < 0) {
                                return r;
                            }
                            condition = cr.v;
                        }

                        // end_condition:
                        if (condition == null) return ONIGERR_MEMORY;

                        if (p >= end) {
                            // err_if_else:
                            return ONIGERR_END_PATTERN_IN_GROUP;
                        }

                        if (PPEEK() == ')'.code) { /* case: empty body: make backref checker */
                            if (!conditionIsChecker) {
                                return ONIGERR_INVALID_IF_ELSE_SYNTAX;
                            }
                            c = PFETCH();
                            np.v = condition;
                        }
                        else { /* if-else */
                            var thenIsEmpty:Bool;
                            var Then:Node = null;
                            var Else:Node = null;

                            if (PPEEK() == '|'.code) {
                                c = PFETCH();
                                thenIsEmpty = true;
                            }
                            else
                                thenIsEmpty = false;

                            pr.v = p;
                            r = fetchToken(tok, pr, end, env);
                            p = pr.v;
                            if (r < 0) {
                                return r;
                            }
                            var tr = new NodeRef();
                            pr.v = p;
                            r = prsAlts(tr, tok, term, pr, end, env, true);
                            p = pr.v;
                            if (r < 0) {
                                return r;
                            }
                            var target = tr.v;

                            if (thenIsEmpty) {
                                Else = target;
                            }
                            else {
                                if (target.nodeType == NODE_ALT) {
                                    Then = target.car;
                                    if (target.cdr.cdr == null) {
                                        Else = target.cdr.car;
                                        consNodeFreeAlone(target.cdr);
                                    }
                                    else {
                                        Else = target.cdr;
                                    }
                                    consNodeFreeAlone(target);
                                }
                                else {
                                    Then = target;
                                    Else = null;
                                }
                            }
                            np.v = nodeNewBagIfElse(condition, Then, Else);
                        }
                        gotoEnd = true;
                    }
                    else {
                        return ONIGERR_UNDEFINED_GROUP_OPTION;
                    }

                case '@'.code:
                    // capture history: no predefined syntax enables ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY
                    return ONIGERR_UNDEFINED_GROUP_OPTION;

                case 'C'.code, 'I'.code, 'L'.code:
                    if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_WHOLE_OPTIONS))
                        return ONIGERR_UNDEFINED_GROUP_OPTION;
                    optionsStart = true;

                case 'P'.code, 'W'.code, 'D'.code, 'S'.code, 'y'.code:
                    var handled = false;
                    if (c == 'P'.code && IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_QMARK_CAPITAL_P_NAME)) {
                        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                        c = PFETCH();
                        if (c == '<'.code) {
                            namedGroup = true;
                            handled = true;
                        }
                        else
                            return ONIGERR_UNDEFINED_GROUP_OPTION;
                    }
                    if (!handled) {
                        if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                            return ONIGERR_UNDEFINED_GROUP_OPTION;
                        optionsStart = true;
                    }

                case 'a'.code, '-'.code, 'i'.code, 'm'.code, 's'.code, 'x'.code:
                    optionsStart = true;

                default:
                    return ONIGERR_UNDEFINED_GROUP_OPTION;
            }

            if (namedGroup) {
                // named_group1:
                var listCapture = false;
                var name = p;
                var nameEnd = new IntRef();
                var numRef = new IntRef();
                var numType = new IntRef();
                pr.v = p;
                r = fetchName(c, pr, end, nameEnd, env, numRef, numType, false);
                if (r < 0) return r;
                p = pr.v;

                num = scanEnvAddMemEntry(env);
                if (num < 0) return num;
                if (listCapture && num >= MEM_STATUS_BITS_NUM)
                    return ONIGERR_GROUP_NUMBER_OVER_FOR_CAPTURE_HISTORY;

                r = nameAdd(env.reg, pat, name, nameEnd.v, num, env);
                if (r != 0) return r;
                np.v = nodeNewMemory(true);
                np.v.regnum = num;
                env.numNamed++;
            }

            if (optionsStart) {
                var neg = false;
                var wholeOptions = false;
                while (true) {
                    switch (c) {
                        case ':'.code, ')'.code:
                        case '-'.code:
                            neg = true;
                        case 'x'.code:
                            option = OPTION_NEGATE(option, ONIG_OPTION_EXTEND, neg);
                        case 'i'.code:
                            option = OPTION_NEGATE(option, ONIG_OPTION_IGNORECASE, neg);
                        case 's'.code:
                            if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_PERL)) {
                                option = OPTION_NEGATE(option, ONIG_OPTION_MULTILINE, neg);
                            }
                            else
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                        case 'm'.code:
                            if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_PERL)) {
                                option = OPTION_NEGATE(option, ONIG_OPTION_SINGLELINE, !neg);
                            }
                            else if (IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA | ONIG_SYN_OP2_OPTION_RUBY)) {
                                option = OPTION_NEGATE(option, ONIG_OPTION_MULTILINE, neg);
                            }
                            else
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                        case 'W'.code:
                            if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_WORD_IS_ASCII, neg);
                        case 'D'.code:
                            if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_DIGIT_IS_ASCII, neg);
                        case 'S'.code:
                            if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_SPACE_IS_ASCII, neg);
                        case 'P'.code:
                            if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_POSIX_IS_ASCII, neg);

                        case 'y'.code: /* y{g}, y{w} */
                            if (!IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_OPTION_ONIGURUMA))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            if (neg) return ONIGERR_UNDEFINED_GROUP_OPTION;
                            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                            if (PPEEK() != '{'.code) return ONIGERR_UNDEFINED_GROUP_OPTION;
                            c = PFETCH();
                            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                            c = PFETCH();
                            switch (c) {
                                case 'g'.code:
                                    option = OPTION_NEGATE(option, ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER, false);
                                    option = OPTION_NEGATE(option, ONIG_OPTION_TEXT_SEGMENT_WORD, true);
                                case 'w'.code:
                                    option = OPTION_NEGATE(option, ONIG_OPTION_TEXT_SEGMENT_WORD, false);
                                    option = OPTION_NEGATE(option, ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER, true);
                                default:
                                    return ONIGERR_UNDEFINED_GROUP_OPTION;
                            }
                            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                            c = PFETCH();
                            if (c != '}'.code)
                                return ONIGERR_UNDEFINED_GROUP_OPTION;

                        case 'a'.code:
                            if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_PYTHON))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_POSIX_IS_ASCII, neg);

                        case 'C'.code:
                            if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_WHOLE_OPTIONS))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            if (neg) return ONIGERR_INVALID_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_DONT_CAPTURE_GROUP, neg);
                            wholeOptions = true;

                        case 'I'.code:
                            if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_WHOLE_OPTIONS))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            if (neg) return ONIGERR_INVALID_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_IGNORECASE_IS_ASCII, neg);
                            wholeOptions = true;

                        case 'L'.code:
                            if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_WHOLE_OPTIONS))
                                return ONIGERR_UNDEFINED_GROUP_OPTION;
                            if (neg) return ONIGERR_INVALID_GROUP_OPTION;
                            option = OPTION_NEGATE(option, ONIG_OPTION_FIND_LONGEST, neg);
                            wholeOptions = true;

                        default:
                            return ONIGERR_UNDEFINED_GROUP_OPTION;
                    }

                    if (c == ')'.code || c == ':'.code) {
                        if (c == ')'.code) {
                            np.v = nodeNewOption(option);
                            r = 2; /* option only */
                        }
                        else {
                            var prevOpt = env.options;
                            env.options = option;
                            pr.v = p;
                            r = fetchToken(tok, pr, end, env);
                            p = pr.v;
                            if (r < 0) return r;
                            var tr = new NodeRef();
                            pr.v = p;
                            r = prsAlts(tr, tok, term, pr, end, env, false);
                            p = pr.v;
                            env.options = prevOpt;
                            if (r < 0) {
                                return r;
                            }
                            np.v = nodeNewOption(option);
                            np.v.body = tr.v;
                            r = 0;
                            if (!wholeOptions) {
                                src.v = p;
                                return 0;
                            }
                        }
                        // set_whole_options:
                        if (wholeOptions) {
                            if ((env.flags & PE_FLAG_HAS_WHOLE_OPTIONS) != 0)
                                return ONIGERR_INVALID_GROUP_OPTION;
                            env.flags |= PE_FLAG_HAS_WHOLE_OPTIONS;
                            np.v.addStatus(NODE_ST_WHOLE_OPTIONS);

                            if (OPTON_DONT_CAPTURE_GROUP(option)) {
                                env.reg.options |= ONIG_OPTION_DONT_CAPTURE_GROUP;
                                if ((option & (ONIG_OPTION_DONT_CAPTURE_GROUP | ONIG_OPTION_CAPTURE_GROUP))
                                        == (ONIG_OPTION_DONT_CAPTURE_GROUP | ONIG_OPTION_CAPTURE_GROUP))
                                    return ONIGERR_INVALID_COMBINATION_OF_OPTIONS;
                            }
                            if ((option & ONIG_OPTION_IGNORECASE_IS_ASCII) != 0) {
                                env.reg.caseFoldFlag &= ~(INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR | ONIGENC_CASE_FOLD_TURKISH_AZERI);
                                env.reg.caseFoldFlag |= ONIGENC_CASE_FOLD_ASCII_ONLY;
                                env.reg.options |= ONIG_OPTION_IGNORECASE_IS_ASCII;
                            }
                            if (OPTON_FIND_LONGEST(option)) {
                                env.reg.options |= ONIG_OPTION_FIND_LONGEST;
                            }
                        }
                        src.v = p;
                        return r;
                    }

                    if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
                    c = PFETCH();
                }
            }
        }
        else if (c == '*'.code && IS_SYNTAX_OP2(env.syntax, ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME)) {
            pfetchPrev = p;
            p += enclen(pat, p);
            pr.v = p;
            r = Callout.prsCalloutOfName(np, ')'.code, pr, end, env);
            p = pr.v;
            if (r != 0) return r;
            gotoEnd = true;
        }
        else {
            if (OPTON_DONT_CAPTURE_GROUP(env.options)) {
                gotoGroup = true;
            }
            else {
                np.v = nodeNewMemory(false);
                num = scanEnvAddMemEntry(env);
                if (num < 0) return num;
                np.v.regnum = num;
            }
        }

        if (gotoGroup) {
            // group:
            pr.v = p;
            r = fetchToken(tok, pr, end, env);
            p = pr.v;
            if (r < 0) return r;
            pr.v = p;
            r = prsAlts(np, tok, term, pr, end, env, false);
            p = pr.v;
            if (r < 0) return r;
            src.v = p;
            return 1; /* group */
        }

        if (!gotoEnd) {
            if (np.v == null) return ONIGERR_MEMORY;
            pr.v = p;
            r = fetchToken(tok, pr, end, env);
            p = pr.v;
            if (r < 0) return r;
            var tr = new NodeRef();
            pr.v = p;
            r = prsAlts(tr, tok, term, pr, end, env, false);
            p = pr.v;
            if (r < 0) {
                return r;
            }
            np.v.body = tr.v;

            if (np.v.nodeType == NODE_BAG) {
                if (np.v.type == BAG_MEMORY) {
                    /* Don't move this to previous of prs_alts() */
                    r = scanEnvSetMemNode(env, np.v.regnum, np.v);
                    if (r != 0) return r;
                }
            }
        }

        // end:
        src.v = p;
        return 0;
    }

    static function assignQuantifierBody(qnode:Node, target:Node, group:Int, env:ParseEnv):Int {
        var qn = qnode;
        if (qn.lower == 1 && qn.upper == 1)
            return 1;

        switch (target.nodeType) {
            case NODE_STRING:
                if (group == 0) {
                    if (strNodeCanBeSplit(target)) {
                        var n = strNodeSplitLastChar(target);
                        if (n != null) {
                            qnode.body = n;
                            return 2;
                        }
                    }
                }

            case NODE_QUANT:
                { /* check redundant double repeat. */
                    var qnt = target;
                    var nestqNum = quantifierTypeNum(qn);
                    var targetqNum = quantifierTypeNum(qnt);

                    if (targetqNum >= 0 && nestqNum < 0) {
                        if (targetqNum == 1 || targetqNum == 2) { /* * or + */
                            /* (?:a*){n,m}, (?:a+){n,m} => (?:a*){n,n}, (?:a+){n,n} */
                            if (qn.upper != INFINITE_REPEAT && qn.upper > 1 && qn.greedy != 0) {
                                qn.upper = (qn.lower == 0 ? 1 : qn.lower);
                            }
                        }
                    }
                    else {
                        qnode.body = target;
                        return onigReduceNestedQuantifier(qnode);
                    }
                }

            default:
        }
        qnode.body = target;
        return 0;
    }

    static inline function ADD_CODE_INTO_CC(cc:Node, code:Int):Void {
        if (codeToMbclen(code) != 1) {
            var mb = new BBufRef(cc.mbuf);
            addCodeRangeToBuf(mb, code, code);
            cc.mbuf = mb.v;
        }
        else {
            BITSET_SET_BIT(cc.bs, code);
        }
    }

    public static function onigNewCclassWithCodeList(rnode:NodeRef, n:Int, codes:Array<Int>):Int {
        rnode.v = null;
        var node = nodeNewCclass();
        var cc = node;
        for (i in 0...n) {
            ADD_CODE_INTO_CC(cc, codes[i]);
        }
        rnode.v = node;
        return 0;
    }

    /** onig_is_code_in_cc_len (regcomp.c) */
    public static function onigIsCodeInCcLen(elen:Int, code:Int, cc:Node):Bool {
        var found:Bool;
        if (elen > 1 || uge(code, SINGLE_BYTE_SIZE)) {
            if (cc.mbuf == null) {
                found = false;
            }
            else {
                found = Unicode.onigIsInCodeRangeArr(cc.mbuf.p, code);
            }
        }
        else {
            found = BITSET_AT(cc.bs, code);
        }
        if (cc.isNcclassNot())
            return !found;
        else
            return found;
    }

    /** onig_is_code_in_cc (regcomp.c) */
    public static function onigIsCodeInCc(code:Int, cc:Node):Bool {
        var len = codeToMbclen(code);
        if (len < 0) return false;
        return onigIsCodeInCcLen(len, code, cc);
    }

    static function iApplyCaseFold(from:Int, to:Array<Int>, toLen:Int, arg:Dynamic):Int {
        var iarg:IApplyCaseFoldArg = arg;
        var env = iarg.env;
        var cc = iarg.cc;

        if (toLen == 1) {
            var isIn = onigIsCodeInCc(from, cc);
            if ((isIn && !cc.isNcclassNot()) || (!isIn && cc.isNcclassNot())) {
                ADD_CODE_INTO_CC(cc, to[0]);
            }
        }
        else {
            var buf = Bytes.alloc(ONIGENC_CODE_TO_MBC_MAXLEN);
            if (onigIsCodeInCc(from, cc) && !cc.isNcclassNot()) {
                var n = 0;
                var ns:Array<Node> = [null, null, null];
                for (i in 0...toLen) {
                    var index = Unicode.onigencUnicodeFold1Key(to[i]);
                    if (index >= 0) {
                        var csnode = nodeNewCclass();
                        var csCc = csnode;
                        var folds1 = Unicode.OnigUnicodeFolds1;
                        var m = folds1[index + 1];
                        for (j in 0...m) {
                            var code = folds1[index + 2 + j];
                            ADD_CODE_INTO_CC(csCc, code);
                        }
                        ADD_CODE_INTO_CC(csCc, to[i]);
                        ns[n++] = csnode;
                    }
                    else {
                        var len = codeToMbc(to[i], buf, 0);
                        if (n == 0 || ns[n - 1].nodeType != NODE_STRING) {
                            var csnode = nodeNewStr(buf, 0, len);
                            if (index == 0)
                                csnode.addStatus(NODE_ST_IGNORECASE);
                            else
                                csnode.flag |= NODE_STRING_CASE_EXPANDED;
                            ns[n++] = csnode;
                        }
                        else {
                            var r = onigNodeStrCat(ns[n - 1], buf, 0, len);
                            if (r < 0) return r;
                        }
                    }
                }

                var listNode:Node;
                if (n == 1)
                    listNode = ns[0];
                else
                    listNode = makeList(n, ns);

                var alt = onigNodeNewAlt(listNode, null);
                if (iarg.tail == null)
                    iarg.altRoot = alt;
                else
                    iarg.tail.cdr = alt;
                iarg.tail = alt;
            }
        }
        return 0;
    }

    static function prsExp(np:NodeRef, tok:PToken, term:Int, src:IntRef, end:Int, env:ParseEnv, groupHead:Bool):Int {
        var r:Int;
        var len:Int;
        var group:Int;
        var qn:Node;
        var parseDepth:Int;
        var pat = env.pattern;

        // tp: a slot holding a node, either np.v (tpNode == null) or tpNode.car
        var tpNode:Node = null;
        inline function getTp():Node return tpNode == null ? np.v : tpNode.car;
        inline function setTp(n:Node):Void {
            if (tpNode == null) np.v = n else tpNode.car = n;
        }

        while (true) { // retry:
            group = 0;
            np.v = null;
            var jumpRepeat = false; // goto string_end / repeat (r already fetched)

            if (tok.type == term) {
                np.v = nodeNewEmpty();
                return tok.type;
            }

            parseDepth = env.parseDepth;

            var tkByte = false;
            var tkCrudeByte = false;
            switch (tok.type) {
                case TK_ALT, TK_EOT:
                    np.v = nodeNewEmpty();
                    return tok.type;

                case TK_SUBEXP_OPEN:
                    r = prsBag(np, tok, TK_SUBEXP_CLOSE, src, end, env);
                    if (r < 0) return r;
                    if (r == 1) { /* group */
                        if (!groupHead)
                            group = 1;
                        else {
                            var target = np.v;
                            np.v = nodeNewGroup(target);
                            group = 2;
                        }
                    }
                    else if (r == 2) { /* option only */
                        if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_ISOLATED_OPTION_CONTINUE_BRANCH)) {
                            env.options = np.v.options;
                            r = fetchToken(tok, src, end, env);
                            if (r < 0) return r;
                            continue; // goto retry
                        }
                        else {
                            var prev = env.options;
                            env.options = np.v.options;
                            r = fetchToken(tok, src, end, env);
                            if (r < 0) return r;
                            var tr = new NodeRef();
                            r = prsAlts(tr, tok, term, src, end, env, false);
                            env.options = prev;
                            if (r < 0) {
                                return r;
                            }
                            np.v.body = tr.v;
                        }
                        return tok.type;
                    }

                case TK_SUBEXP_CLOSE:
                    if (!IS_SYNTAX_BV(env.syntax, ONIG_SYN_ALLOW_UNMATCHED_CLOSE_SUBEXP))
                        return ONIGERR_UNMATCHED_CLOSE_PARENTHESIS;
                    if (tok.escaped) tkCrudeByte = true;
                    else tkByte = true;

                case TK_STRING:
                    tkByte = true;

                case TK_CRUDE_BYTE:
                    tkCrudeByte = true;

                case TK_CODE_POINT:
                    var buf = Bytes.alloc(ONIGENC_CODE_TO_MBC_MAXLEN);
                    len = codeToMbclen(tok.code);
                    if (len < 0) return len;
                    len = codeToMbc(tok.code, buf, 0);
                    np.v = nodeNewStrWithOptions(buf, 0, len, env.options);

                case TK_QUOTE_OPEN:
                    var endOp = [env.syntax.metaEsc, 'E'.code];
                    var qstart = src.v;
                    var nextp = new IntRef();
                    var qend = findStrPosition(endOp, 2, pat, qstart, end, nextp);
                    if (qend == NULL_UCHARP) {
                        nextp.v = qend = end;
                    }
                    np.v = nodeNewStrWithOptions(pat, qstart, qend, env.options);
                    src.v = nextp.v;

                case TK_CHAR_TYPE:
                    switch (tok.propCtype) {
                        case ONIGENC_CTYPE_WORD:
                            np.v = nodeNewCtype(tok.propCtype, tok.propNot != 0, env.options);
                        case ONIGENC_CTYPE_SPACE, ONIGENC_CTYPE_DIGIT, ONIGENC_CTYPE_XDIGIT:
                            np.v = nodeNewCclass();
                            var cc = np.v;
                            r = addCtypeToCc(cc, tok.propCtype, false, env);
                            if (r != 0) {
                                np.v = null;
                                return r;
                            }
                            if (tok.propNot != 0) cc.flags |= FLAG_NCCLASS_NOT;
                        default:
                            return ONIGERR_PARSER_BUG;
                    }

                case TK_CHAR_PROPERTY:
                    r = prsCharProperty(np, tok, src, end, env);
                    if (r != 0) return r;

                case TK_OPEN_CC:
                    r = prsCc(np, tok, src, end, env);
                    if (r != 0) return r;
                    var cc = np.v;
                    if (OPTON_IGNORECASE(env.options)) {
                        var iarg = new IApplyCaseFoldArg();
                        iarg.env = env;
                        iarg.cc = cc;
                        iarg.altRoot = null;
                        iarg.tail = null;
                        r = Unicode.onigencUnicodeApplyAllCaseFold(env.caseFoldFlag, iApplyCaseFold, iarg);
                        if (r != 0) {
                            return r;
                        }
                        if (iarg.altRoot != null) {
                            var work = onigNodeNewAlt(np.v, iarg.altRoot);
                            np.v = work;
                        }
                    }

                case TK_ANYCHAR:
                    np.v = nodeNewAnychar(env.options);

                case TK_ANYCHAR_ANYTIME:
                    np.v = nodeNewAnychar(env.options);
                    qn = nodeNewQuantifier(0, INFINITE_REPEAT, false);
                    qn.body = np.v;
                    np.v = qn;

                case TK_BACKREF:
                    len = tok.backrefNum;
                    np.v = nodeNewBackref(len, (len > 1 ? tok.backrefRefs : [tok.backrefRef1]), tok.backrefByName != 0,
                        tok.backrefExistLevel != 0, tok.backrefLevel, env);

                case TK_CALL:
                    var gnum = tok.callGnum;
                    np.v = nodeNewCall(pat, tok.callName, tok.callNameEnd, gnum, tok.callByNumber != 0);
                    env.numCall++;
                    if (tok.callByNumber != 0 && gnum == 0) {
                        env.flags |= PE_FLAG_HAS_CALL_ZERO;
                    }

                case TK_ANCHOR:
                    np.v = nodeNewAnchorWithOptions(tok.anchor, env.options);

                case TK_REPEAT, TK_INTERVAL:
                    if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_CONTEXT_INDEP_REPEAT_OPS)) {
                        if (IS_SYNTAX_BV(env.syntax, ONIG_SYN_CONTEXT_INVALID_REPEAT_OPS))
                            return ONIGERR_TARGET_OF_REPEAT_OPERATOR_NOT_SPECIFIED;
                        else {
                            np.v = nodeNewEmpty();
                        }
                    }
                    else {
                        tkByte = true;
                    }

                case TK_KEEP:
                    r = nodeNewKeep(np, env);
                    if (r < 0) return r;

                case TK_GENERAL_NEWLINE:
                    r = nodeNewGeneralNewline(np, env);
                    if (r < 0) return r;

                case TK_NO_NEWLINE:
                    r = nodeNewNoNewline(np, env);
                    if (r < 0) return r;

                case TK_TRUE_ANYCHAR:
                    r = nodeNewTrueAnychar(np);
                    if (r < 0) return r;

                case TK_TEXT_SEGMENT:
                    r = makeTextSegment(np, env);
                    if (r < 0) return r;

                default:
                    return ONIGERR_PARSER_BUG;
            }

            r = 0;
            if (tkByte) {
                // tk_byte:
                np.v = nodeNewStrWithOptions(pat, tok.backp, src.v, env.options);
                while (true) {
                    r = fetchToken(tok, src, end, env);
                    if (r < 0) return r;
                    if (r != TK_STRING) break;
                    r = onigNodeStrCat(np.v, pat, tok.backp, src.v);
                    if (r < 0) return r;
                    r = TK_STRING;
                }
                jumpRepeat = true;
            }
            else if (tkCrudeByte) {
                // tk_crude_byte:
                np.v = nodeNewStrCrudeChar(tok.byte, env.options);
                len = 1;
                while (true) {
                    if (len >= ONIGENC_MBC_MINLEN) {
                        if (len == enclen(np.v.sbuf, np.v.s)) {
                            r = fetchToken(tok, src, end, env);
                            break; // goto tk_crude_byte_end
                        }
                    }
                    r = fetchToken(tok, src, end, env);
                    if (r < 0) return r;
                    if (r != TK_CRUDE_BYTE)
                        return ONIGERR_TOO_SHORT_MULTI_BYTE_STRING;
                    r = nodeStrCatChar(np.v, tok.byte);
                    if (r < 0) return r;
                    len++;
                }
                // tk_crude_byte_end:
                if (!isValidMbcString(np.v.sbuf, np.v.s, np.v.end))
                    return ONIGERR_INVALID_WIDE_CHAR_VALUE;
                np.v.flag &= ~NODE_STRING_CRUDE;
                jumpRepeat = true;
            }

            tpNode = null;
            if (!jumpRepeat) {
                // re_entry:
                r = fetchToken(tok, src, end, env);
                if (r < 0) return r;
            }

            // repeat:
            while (r == TK_REPEAT || r == TK_INTERVAL) {
                if (isInvalidQuantifierTarget(getTp()))
                    return ONIGERR_TARGET_OF_REPEAT_OPERATOR_INVALID;

                parseDepth++;
                if (parseDepth > ParseDepthLimit)
                    return ONIGERR_PARSE_DEPTH_LIMIT_OVER;

                qn = nodeNewQuantifier(tok.repeatLower, tok.repeatUpper, r == TK_INTERVAL);
                qn.greedy = tok.repeatGreedy;
                var target:Node;
                if (group == 2) {
                    target = nodeDropGroup(getTp());
                    setTp(null);
                }
                else {
                    target = getTp();
                }
                r = assignQuantifierBody(qn, target, group, env);
                if (r < 0) {
                    setTp(null);
                    return r;
                }

                if (tok.repeatPossessive != 0) {
                    var en = nodeNewBag(BAG_STOP_BACKTRACK);
                    en.body = qn;
                    qn = en;
                }

                if (r == 0) {
                    setTp(qn);
                }
                else if (r == 1) { /* x{1,1} ==> x */
                    setTp(target);
                }
                else if (r == 2) { /* split case: /abc+/ */
                    setTp(nodeNewList(getTp(), null));
                    var tmp = nodeNewList(qn, null);
                    getTp().cdr = tmp;
                    tpNode = tmp;
                }
                group = 0;
                // goto re_entry:
                r = fetchToken(tok, src, end, env);
                if (r < 0) return r;
            }
            return r;
        }
    }

    static function prsBranch(top:NodeRef, tok:PToken, term:Int, src:IntRef, end:Int, env:ParseEnv, groupHead:Bool):Int {
        top.v = null;
        env.parseDepth++;
        if (env.parseDepth > ParseDepthLimit)
            return ONIGERR_PARSE_DEPTH_LIMIT_OVER;

        var nr = new NodeRef();
        var r = prsExp(nr, tok, term, src, end, env, groupHead);
        if (r < 0) {
            return r;
        }
        var node = nr.v;

        if (r == TK_EOT || r == term || r == TK_ALT) {
            top.v = node;
        }
        else {
            top.v = nodeNewList(node, null);
            var head = top.v; // headp = &NODE_CDR(head)
            while (r != TK_EOT && r != term && r != TK_ALT) {
                r = prsExp(nr, tok, term, src, end, env, false);
                if (r < 0) {
                    return r;
                }
                node = nr.v;
                if (node.nodeType == NODE_LIST) {
                    head.cdr = node;
                    while (node.cdr != null) node = node.cdr;
                    head = node;
                }
                else {
                    head.cdr = nodeNewList(node, null);
                    head = head.cdr;
                }
            }
        }
        env.parseDepth--;
        return r;
    }

    /* term_tok: TK_EOT or TK_SUBEXP_CLOSE */
    static function prsAlts(top:NodeRef, tok:PToken, term:Int, src:IntRef, end:Int, env:ParseEnv, groupHead:Bool):Int {
        top.v = null;
        env.parseDepth++;
        if (env.parseDepth > ParseDepthLimit)
            return ONIGERR_PARSE_DEPTH_LIMIT_OVER;
        var saveOptions = env.options;

        var nr = new NodeRef();
        var r = prsBranch(nr, tok, term, src, end, env, groupHead);
        if (r < 0) {
            return r;
        }

        if (r == term) {
            top.v = nr.v;
        }
        else if (r == TK_ALT) {
            top.v = onigNodeNewAlt(nr.v, null);
            var head = top.v;
            while (r == TK_ALT) {
                r = fetchToken(tok, src, end, env);
                if (r < 0) return r;
                r = prsBranch(nr, tok, term, src, end, env, false);
                if (r < 0) {
                    return r;
                }
                head.cdr = onigNodeNewAlt(nr.v, null);
                head = head.cdr;
            }
            if (tok.type != term) {
                if (term == TK_SUBEXP_CLOSE)
                    return ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS;
                else
                    return ONIGERR_PARSER_BUG;
            }
        }
        else {
            if (term == TK_SUBEXP_CLOSE)
                return ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS;
            else
                return ONIGERR_PARSER_BUG;
        }

        env.options = saveOptions;
        env.parseDepth--;
        return r;
    }

    static function prsRegexp(top:NodeRef, src:IntRef, end:Int, env:ParseEnv):Int {
        var tok = new PToken();
        ptokenInit(tok);
        var r = fetchToken(tok, src, end, env);
        if (r < 0) return r;
        r = prsAlts(top, tok, TK_EOT, src, end, env, false);
        if (r < 0) return r;
        return 0;
    }

    static function makeCallZeroBody(node:Node, env:ParseEnv, rnode:NodeRef):Int {
        var x = nodeNewMemory(false);
        x.body = node;
        x.regnum = 0;
        var r = scanEnvSetMemNode(env, 0, x);
        if (r != 0) {
            return r;
        }
        rnode.v = x;
        return 0;
    }

    public static function onigParseTree(root:NodeRef, pattern:Bytes, start:Int, end:Int, reg:Regex, env:ParseEnv):Int {
        reg.numMem = 0;
        reg.numRepeat = 0;
        reg.numEmptyCheck = 0;
        reg.repeatRangeAlloc = 0;
        reg.repeatRange = null;

        reg.nameTable = null; // names_clear

        scanEnvClear(env);
        env.options = reg.options;
        env.caseFoldFlag = reg.caseFoldFlag;
        env.syntax = reg.syntax;
        env.pattern = pattern;
        env.patternStart = start;
        env.patternEnd = end;
        env.reg = reg;

        root.v = null;

        if (!isValidMbcString(pattern, start, end))
            return ONIGERR_INVALID_WIDE_CHAR_VALUE;

        var p = new IntRef(start);
        var r = prsRegexp(root, p, end, env);
        if (r != 0) return r;

        if ((env.flags & PE_FLAG_HAS_CALL_ZERO) != 0) {
            var zeroNode = new NodeRef();
            r = makeCallZeroBody(root.v, env, zeroNode);
            if (r != 0) return r;
            root.v = zeroNode.v;
        }

        reg.numMem = env.numMem;

        var ext = reg.extp;
        if (ext != null && ext.calloutNum > 0) {
            r = Callout.setupExtCalloutListValues(reg);
        }
        return r;
    }

}

/** IApplyCaseFoldArg */
class IApplyCaseFoldArg {
    public var env:ParseEnv;
    public var cc:Node;
    public var altRoot:Node;
    /** last alt node (ptail is &tail.cdr, or &altRoot when null) */
    public var tail:Node;
    public function new() {}
}
