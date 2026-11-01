// Ported from Oniguruma 6.9.8: src/regparse.h (Node and its union members)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. The C union of node kinds is flattened into one
// class; swapping or copying a node copies every field. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;

/** BBuf used as a code range buffer: p[0] is the number of ranges, then from/to pairs. `used` counts ints. */
class BBuf {
    public var p:Array<Int>;
    public var used:Int;
    public function new() {
        p = [];
        used = 0;
    }
    public function clone():BBuf {
        var b = new BBuf();
        b.p = p.copy();
        b.used = used;
        return b;
    }
}

class Node {

    // node types
    public static inline var NODE_STRING:Int = 0;
    public static inline var NODE_CCLASS:Int = 1;
    public static inline var NODE_CTYPE:Int = 2;
    public static inline var NODE_BACKREF:Int = 3;
    public static inline var NODE_QUANT:Int = 4;
    public static inline var NODE_BAG:Int = 5;
    public static inline var NODE_ANCHOR:Int = 6;
    public static inline var NODE_LIST:Int = 7;
    public static inline var NODE_ALT:Int = 8;
    public static inline var NODE_CALL:Int = 9;
    public static inline var NODE_GIMMICK:Int = 10;

    // BagType
    public static inline var BAG_MEMORY:Int = 0;
    public static inline var BAG_OPTION:Int = 1;
    public static inline var BAG_STOP_BACKTRACK:Int = 2;
    public static inline var BAG_IF_ELSE:Int = 3;

    // GimmickType
    public static inline var GIMMICK_FAIL:Int = 0;
    public static inline var GIMMICK_SAVE:Int = 1;
    public static inline var GIMMICK_UPDATE_VAR:Int = 2;
    public static inline var GIMMICK_CALLOUT:Int = 3;

    // BodyEmptyType
    public static inline var BODY_IS_NOT_EMPTY:Int = 0;
    public static inline var BODY_MAY_BE_EMPTY:Int = 1;
    public static inline var BODY_MAY_BE_EMPTY_MEM:Int = 2;
    public static inline var BODY_MAY_BE_EMPTY_REC:Int = 3;

    public static inline var NODE_STRING_CRUDE:Int = 1 << 0;
    public static inline var NODE_STRING_CASE_EXPANDED:Int = 1 << 1;

    public static inline var CTYPE_ANYCHAR:Int = -1;

    // node status bits
    public static inline var NODE_ST_FIXED_MIN:Int = 1 << 0;
    public static inline var NODE_ST_FIXED_MAX:Int = 1 << 1;
    public static inline var NODE_ST_FIXED_CLEN:Int = 1 << 2;
    public static inline var NODE_ST_MARK1:Int = 1 << 3;
    public static inline var NODE_ST_MARK2:Int = 1 << 4;
    public static inline var NODE_ST_STRICT_REAL_REPEAT:Int = 1 << 5;
    public static inline var NODE_ST_RECURSION:Int = 1 << 6;
    public static inline var NODE_ST_CALLED:Int = 1 << 7;
    public static inline var NODE_ST_FIXED_ADDR:Int = 1 << 8;
    public static inline var NODE_ST_NAMED_GROUP:Int = 1 << 9;
    public static inline var NODE_ST_IN_REAL_REPEAT:Int = 1 << 10;
    public static inline var NODE_ST_IN_ZERO_REPEAT:Int = 1 << 11;
    public static inline var NODE_ST_IN_MULTI_ENTRY:Int = 1 << 12;
    public static inline var NODE_ST_NEST_LEVEL:Int = 1 << 13;
    public static inline var NODE_ST_BY_NUMBER:Int = 1 << 14;
    public static inline var NODE_ST_BY_NAME:Int = 1 << 15;
    public static inline var NODE_ST_BACKREF:Int = 1 << 16;
    public static inline var NODE_ST_CHECKER:Int = 1 << 17;
    public static inline var NODE_ST_PROHIBIT_RECURSION:Int = 1 << 18;
    public static inline var NODE_ST_SUPER:Int = 1 << 19;
    public static inline var NODE_ST_EMPTY_STATUS_CHECK:Int = 1 << 20;
    public static inline var NODE_ST_IGNORECASE:Int = 1 << 21;
    public static inline var NODE_ST_MULTILINE:Int = 1 << 22;
    public static inline var NODE_ST_TEXT_SEGMENT_WORD:Int = 1 << 23;
    public static inline var NODE_ST_ABSENT_WITH_SIDE_EFFECTS:Int = 1 << 24;
    public static inline var NODE_ST_FIXED_CLEN_MIN_SURE:Int = 1 << 25;
    public static inline var NODE_ST_REFERENCED:Int = 1 << 26;
    public static inline var NODE_ST_INPEEK:Int = 1 << 27;
    public static inline var NODE_ST_WHOLE_OPTIONS:Int = 1 << 28;

    public static inline var FLAG_NCCLASS_NOT:Int = 1 << 0;
    public static inline var FLAG_NCCLASS_SHARE:Int = 1 << 1;

    // base
    public var nodeType:Int = 0;
    public var status:Int = 0;
    public var parent:Node = null;
    /** body (QUANT, BAG, ANCHOR, CALL), also `car` of LIST and ALT (same memory slot in C). */
    public var body:Node = null;

    // StrNode
    public var sbuf:Bytes = null;
    public var s:Int = 0;
    public var end:Int = 0;
    public var flag:Int = 0;

    // CClassNode
    public var flags:Int = 0;
    public var bs:Vector<Int> = null;
    public var mbuf:BBuf = null;

    // QuantNode
    public var lower:Int = 0;
    public var upper:Int = 0;
    public var greedy:Int = 0;
    public var emptiness:Int = 0;
    public var headExact:Node = null;
    public var nextHeadExact:Node = null;
    public var includeReferred:Int = 0;
    public var emptyStatusMem:Int = 0;

    // BagNode (type is shared with AnchorNode and GimmickNode `type`)
    public var type:Int = 0;
    public var regnum:Int = 0;
    public var calledAddr:Int = 0;
    public var entryCount:Int = 0;
    public var calledState:Int = 0;
    public var options:Int = 0;
    public var Then:Node = null;
    public var Else:Node = null;
    public var minLen:Int = 0;
    public var maxLen:Int = 0;
    public var minCharLen:Int = 0;
    public var maxCharLen:Int = 0;
    public var optCount:Int = 0;

    // CallNode
    public var byNumber:Int = 0;
    public var calledGnum:Int = 0;
    public var name:Bytes = null;
    public var nameStart:Int = 0;
    public var nameEnd:Int = 0;
    public var callEntryCount:Int = 0;

    // BackRefNode
    public var backNum:Int = 0;
    public var backs:Array<Int> = null;
    public var nestLevel:Int = 0;

    // AnchorNode
    public var charMinLen:Int = 0;
    public var charMaxLen:Int = 0;
    public var asciiMode:Int = 0;
    public var leadNode:Node = null;

    // ConsAltNode
    public var cdr:Node = null;

    // CtypeNode
    public var ctype:Int = 0;
    public var not:Int = 0;

    // GimmickNode
    public var detailType:Int = 0;
    public var num:Int = 0;
    public var id:Int = 0;

    public var car(get, set):Node;

    inline function get_car():Node {
        return body;
    }

    inline function set_car(n:Node):Node {
        return body = n;
    }

    public function new() {}

    /** xmemset(node, 0, sizeof(Node)) */
    public function clear():Void {
        nodeType = 0; status = 0; parent = null; body = null;
        sbuf = null; s = 0; end = 0; flag = 0;
        flags = 0; bs = null; mbuf = null;
        lower = 0; upper = 0; greedy = 0; emptiness = 0; headExact = null; nextHeadExact = null;
        includeReferred = 0; emptyStatusMem = 0;
        type = 0; regnum = 0; calledAddr = 0; entryCount = 0; calledState = 0; options = 0;
        Then = null; Else = null; minLen = 0; maxLen = 0; minCharLen = 0; maxCharLen = 0; optCount = 0;
        byNumber = 0; calledGnum = 0; name = null; nameStart = 0; nameEnd = 0; callEntryCount = 0;
        backNum = 0; backs = null; nestLevel = 0;
        charMinLen = 0; charMaxLen = 0; asciiMode = 0; leadNode = null;
        cdr = null; ctype = 0; not = 0; detailType = 0; num = 0; id = 0;
    }

    /** xmemcpy(this, from, sizeof(Node)): a shallow copy of every field (the bitset is cloned, it is inline in C). */
    public function copyFrom(from:Node):Void {
        nodeType = from.nodeType; status = from.status; parent = from.parent; body = from.body;
        sbuf = from.sbuf; s = from.s; end = from.end; flag = from.flag;
        flags = from.flags; bs = from.bs == null ? null : from.bs.copy(); mbuf = from.mbuf;
        lower = from.lower; upper = from.upper; greedy = from.greedy; emptiness = from.emptiness;
        headExact = from.headExact; nextHeadExact = from.nextHeadExact;
        includeReferred = from.includeReferred; emptyStatusMem = from.emptyStatusMem;
        type = from.type; regnum = from.regnum; calledAddr = from.calledAddr; entryCount = from.entryCount;
        calledState = from.calledState; options = from.options;
        Then = from.Then; Else = from.Else; minLen = from.minLen; maxLen = from.maxLen;
        minCharLen = from.minCharLen; maxCharLen = from.maxCharLen; optCount = from.optCount;
        byNumber = from.byNumber; calledGnum = from.calledGnum; name = from.name; nameStart = from.nameStart;
        nameEnd = from.nameEnd; callEntryCount = from.callEntryCount;
        backNum = from.backNum; backs = from.backs; nestLevel = from.nestLevel;
        charMinLen = from.charMinLen; charMaxLen = from.charMaxLen; asciiMode = from.asciiMode; leadNode = from.leadNode;
        cdr = from.cdr; ctype = from.ctype; not = from.not; detailType = from.detailType; num = from.num; id = from.id;
    }

    /** Swaps every field with another node (swap_node of regcomp.c). */
    public function swapWith(b:Node):Void {
        var c = new Node();
        c.copyFromRaw(this);
        this.copyFromRaw(b);
        b.copyFromRaw(c);
    }

    function copyFromRaw(from:Node):Void {
        var keepBs = from.bs;
        copyFrom(from);
        bs = keepBs;
    }

    // ---- accessors (macros of regparse.h) ----

    public inline function strLen():Int {
        return end - s;
    }

    public inline function isStrCrude():Bool {
        return (flag & NODE_STRING_CRUDE) != 0;
    }

    public inline function isStrCaseExpanded():Bool {
        return (flag & NODE_STRING_CASE_EXPANDED) != 0;
    }

    public inline function isAnychar():Bool {
        return nodeType == NODE_CTYPE && ctype == CTYPE_ANYCHAR;
    }

    public inline function hasStatus(f:Int):Bool {
        return (status & f) != 0;
    }

    public inline function addStatus(f:Int):Void {
        status |= f;
    }

    public inline function removeStatus(f:Int):Void {
        status &= ~f;
    }

    public inline function isNcclassNot():Bool {
        return (flags & FLAG_NCCLASS_NOT) != 0;
    }

}
