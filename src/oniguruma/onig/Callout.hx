// Ported from Oniguruma 6.9.8: src/regparse.c (callout names, tags and parsing),
// src/regexec.c (callout data and builtin callout functions), src/ascii.c (builtin names)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. Only the builtin callouts are available (FAIL,
// MISMATCH, MAX, ERROR, COUNT, TOTAL_COUNT, CMP); callout functions are ids.
// See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regenc.*;
import oniguruma.onig.Regparse;
import oniguruma.onig.Regex.CalloutListEntry;
import oniguruma.onig.Regex.RegexExt;

/** OnigValue */
class OnigValue {
    public var l:Int = 0;
    public var c:Int = 0;
    public var sBytes:Bytes = null;
    public var sStart:Int = 0;
    public var sEnd:Int = 0;
    public var tag:Int = 0;
    public function new() {}
    public function copyFrom(v:OnigValue):Void {
        l = v.l; c = v.c; sBytes = v.sBytes; sStart = v.sStart; sEnd = v.sEnd; tag = v.tag;
    }
}

/** CalloutNameListEntry */
class CalloutNameListEntry {
    public var type:Int = 0;
    public var in_:Int = 0;
    public var startFunc:Int = 0;
    public var endFunc:Int = 0;
    public var argNum:Int = 0;
    public var optArgNum:Int = 0;
    public var argTypes:Array<Int> = [0, 0, 0, 0];
    public var optDefaults:Array<OnigValue> = [new OnigValue(), new OnigValue(), new OnigValue(), new OnigValue()];
    public var name:String = null;
    public function new() {}
}

/** CalloutData of regexec.c */
class CalloutData {
    public var lastMatchAtCallCounter:Int = 0;
    public var slotTypes:Array<Int> = [0, 0, 0, 0, 0];
    public var slotVals:Array<OnigValue> = [for (i in 0...5) new OnigValue()];
    public function new() {}
    public function clear():Void {
        lastMatchAtCallCounter = 0;
        for (i in 0...5) {
            slotTypes[i] = 0;
            slotVals[i] = new OnigValue();
        }
    }
}

/** OnigCalloutArgs */
class OnigCalloutArgs {
    public var in_:Int = 0;
    public var nameId:Int = 0;
    public var num:Int = 0;
    public var regex:Regex = null;
    public var string:Bytes = null;
    public var stringEnd:Int = 0;
    public var start:Int = 0;
    public var rightRange:Int = 0;
    public var current:Int = 0;
    public var retryInMatchCounter:Int = 0;
    public var msa:Regexec.MatchArg = null;
    public function new() {}
}

typedef OnigCalloutFunc = Int;

class Callout {

    // builtin function ids
    public static inline var FUNC_NONE:Int = 0;
    public static inline var FUNC_FAIL:Int = 1;
    public static inline var FUNC_MISMATCH:Int = 2;
    public static inline var FUNC_MAX:Int = 3;
    public static inline var FUNC_ERROR:Int = 4;
    public static inline var FUNC_COUNT:Int = 5;
    public static inline var FUNC_TOTAL_COUNT:Int = 6;
    public static inline var FUNC_CMP:Int = 7;

    static inline var CALLOUT_TAG_LIST_FLAG_TAG_EXIST:Int = 1 << 0;

    static var nameIds:Map<String, Int> = null;
    static var nameList:Array<CalloutNameListEntry> = null;

    /** init of ascii.c (the builtin callouts registered by onig_initialize) */
    static function initBuiltins():Void {
        if (nameIds != null) return;
        nameIds = new Map();
        nameList = [new CalloutNameListEntry()];
        inline function v(f:(OnigValue) -> Void):OnigValue {
            var x = new OnigValue();
            f(x);
            return x;
        }
        setCalloutOfName("FAIL", ONIG_CALLOUT_IN_PROGRESS, FUNC_FAIL, 0, [], 0, []);
        setCalloutOfName("MISMATCH", ONIG_CALLOUT_IN_PROGRESS, FUNC_MISMATCH, 0, [], 0, []);
        setCalloutOfName("MAX", ONIG_CALLOUT_IN_BOTH, FUNC_MAX, 2, [ONIG_TYPE_TAG | ONIG_TYPE_LONG, ONIG_TYPE_CHAR], 1,
            [v(x -> x.c = 'X'.code)]);
        setCalloutOfName("ERROR", ONIG_CALLOUT_IN_PROGRESS, FUNC_ERROR, 1, [ONIG_TYPE_LONG], 1, [v(x -> x.l = ONIG_ABORT)]);
        setCalloutOfName("COUNT", ONIG_CALLOUT_IN_BOTH, FUNC_COUNT, 1, [ONIG_TYPE_CHAR], 1, [v(x -> x.c = '>'.code)]);
        setCalloutOfName("TOTAL_COUNT", ONIG_CALLOUT_IN_BOTH, FUNC_TOTAL_COUNT, 1, [ONIG_TYPE_CHAR], 1, [v(x -> x.c = '>'.code)]);
        setCalloutOfName("CMP", ONIG_CALLOUT_IN_PROGRESS, FUNC_CMP, 3, [ONIG_TYPE_TAG | ONIG_TYPE_LONG, ONIG_TYPE_STRING,
            ONIG_TYPE_TAG | ONIG_TYPE_LONG], 0, []);
    }

    /** onig_set_callout_of_name (single type, ASCII names) */
    static function setCalloutOfName(name:String, in_:Int, startFunc:Int, argNum:Int, argTypes:Array<Int>, optArgNum:Int,
            optDefaults:Array<OnigValue>):Int {
        var id = nameList.length;
        nameIds.set(name, id);
        var fe = new CalloutNameListEntry();
        nameList.push(fe);
        fe.type = ONIG_CALLOUT_TYPE_SINGLE;
        fe.in_ = in_;
        fe.startFunc = startFunc;
        fe.endFunc = 0;
        fe.argNum = argNum;
        fe.optArgNum = optArgNum;
        fe.name = name;
        for (i in 0...argNum) fe.argTypes[i] = argTypes[i];
        var j = 0;
        for (i in (argNum - optArgNum)...argNum) {
            fe.optDefaults[i].copyFrom(optDefaults[j]);
            j++;
        }
        return id;
    }

    static inline function IS_ALLOWED_CODE_IN_CALLOUT_NAME(c:Int):Bool {
        return (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    static function isAllowedCalloutName(s:Bytes, name:Int, nameEnd:Int):Bool {
        if (name >= nameEnd) return false;
        var p = name;
        while (p < nameEnd) {
            var c = mbcToCode(s, p, nameEnd);
            if (!IS_ALLOWED_CODE_IN_CALLOUT_NAME(c))
                return false;
            if (p == name) {
                if (c >= '0'.code && c <= '9'.code) return false;
            }
            p += enclen(s, p);
        }
        return true;
    }

    static inline function isAllowedCalloutTagName(s:Bytes, name:Int, nameEnd:Int):Bool {
        return isAllowedCalloutName(s, name, nameEnd);
    }

    /** get_callout_name_id_by_name: returns the id or an error code. */
    static function getCalloutNameIdByName(isNotSingle:Bool, s:Bytes, name:Int, nameEnd:Int):Int {
        initBuiltins();
        if (!isAllowedCalloutName(s, name, nameEnd)) {
            return ONIGERR_INVALID_CALLOUT_NAME;
        }
        if (isNotSingle) return ONIGERR_UNDEFINED_CALLOUT_NAME;
        var id = nameIds.get(s.getString(name, nameEnd - name));
        if (id == null) {
            return ONIGERR_UNDEFINED_CALLOUT_NAME;
        }
        return id;
    }

    // ---- regex callout list ----

    public static function onigRegCalloutListAt(reg:Regex, num:Int):CalloutListEntry {
        var ext = reg.extp;
        if (ext == null) return null;
        if (num <= 0 || num > ext.calloutNum)
            return null;
        return ext.calloutList[num - 1];
    }

    static function regCalloutListEntry(env:ParseEnv):Int {
        var ext = Regcomp.onigGetRegexExt(env.reg);
        if (ext.calloutList == null) {
            ext.calloutList = [];
            ext.calloutNum = 0;
        }
        var num = ext.calloutNum + 1;
        var e = new CalloutListEntry();
        e.flag = 0;
        e.of = 0;
        e.in_ = ONIG_CALLOUT_OF_CONTENTS;
        e.type = 0;
        e.tagStart = 0;
        e.tagEnd = 0;
        e.startFunc = 0;
        e.endFunc = 0;
        e.argNum = 0;
        e.argPassedNum = 0;
        ext.calloutList.push(e);
        ext.calloutNum = num;
        return num;
    }

    static function calloutTagEntry(env:ParseEnv, reg:Regex, s:Bytes, name:Int, nameEnd:Int, entryVal:Int):Int {
        var ext = Regcomp.onigGetRegexExt(reg);
        if (ext.tagTable == null) ext.tagTable = new Map();
        var r = ONIG_NORMAL;
        if (nameEnd - name <= 0)
            r = ONIGERR_INVALID_CALLOUT_TAG_NAME;
        else {
            var key = s.getString(name, nameEnd - name);
            if (ext.tagTable.exists(key)) {
                Regparse.onigScanEnvSetErrorString(env, ONIGERR_MULTIPLEX_DEFINED_NAME, s, name, nameEnd);
                r = ONIGERR_MULTIPLEX_DEFINED_NAME;
            }
            else
                ext.tagTable.set(key, entryVal);
        }
        var e = onigRegCalloutListAt(reg, entryVal);
        if (e == null) return ONIGERR_MEMORY;
        e.tagStart = name;
        e.tagEnd = nameEnd;
        return r;
    }

    public static function onigGetCalloutNumByTag(reg:Regex, s:Bytes, tag:Int, tagEnd:Int):Int {
        var ext = reg.extp;
        if (ext == null || ext.tagTable == null)
            return ONIGERR_INVALID_CALLOUT_TAG_NAME;
        var v = ext.tagTable.get(s.getString(tag, tagEnd - tag));
        if (v == null) return ONIGERR_INVALID_CALLOUT_TAG_NAME;
        return v;
    }

    public static function setupExtCalloutListValues(reg:Regex):Int {
        var ext = reg.extp;
        if (ext.tagTable != null) {
            for (v in ext.tagTable) {
                var num = v - 1;
                ext.calloutList[num].flag |= CALLOUT_TAG_LIST_FLAG_TAG_EXIST;
            }
        }
        for (i in 0...ext.calloutNum) {
            var e = ext.calloutList[i];
            if (e.of == ONIG_CALLOUT_OF_NAME) {
                for (j in 0...e.argNum) {
                    if (e.argTypes[j] == ONIG_TYPE_TAG) {
                        var val = e.argVals[j];
                        var num = onigGetCalloutNumByTag(reg, val.sBytes, val.sStart, val.sEnd);
                        if (num < 0) return num;
                        val.tag = num;
                    }
                }
            }
        }
        return ONIG_NORMAL;
    }

    // ---- parsing ----

    /** (?{...}[tag][+-]) (?{{...}}[tag][+-]) */
    public static function prsCalloutOfContents(np:NodeRef, cterm:Int, src:IntRef, end:Int, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var c:Int;
        var r:Int;

        inline function PFETCH_S():Int {
            var cc = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            return cc;
        }

        if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;

        var braceNest = 0;
        while (p < end && mbcToCode(pat, p, end) == '{'.code) {
            braceNest++;
            p += enclen(pat, p);
            if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;
        }

        var in_ = ONIG_CALLOUT_IN_PROGRESS;
        var codeStart = p;
        var codeEnd = p;
        while (true) {
            if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;
            codeEnd = p;
            c = PFETCH_S();
            if (c == '}'.code) {
                var i = braceNest;
                while (i > 0) {
                    if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;
                    c = PFETCH_S();
                    if (c == '}'.code) i--;
                    else break;
                }
                if (i == 0) break;
            }
        }

        if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

        var tagStart = 0;
        var tagEnd = 0;
        c = PFETCH_S();
        if (c == '['.code) {
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            tagEnd = tagStart = p;
            while (p < end) {
                tagEnd = p;
                c = PFETCH_S();
                if (c == ']'.code) break;
            }
            if (!isAllowedCalloutTagName(pat, tagStart, tagEnd))
                return ONIGERR_INVALID_CALLOUT_TAG_NAME;
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            c = PFETCH_S();
        }
        else {
            tagStart = tagEnd = 0;
        }

        if (c == 'X'.code) {
            in_ |= ONIG_CALLOUT_IN_RETRACTION;
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            c = PFETCH_S();
        }
        else if (c == '<'.code) {
            in_ = ONIG_CALLOUT_IN_RETRACTION;
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            c = PFETCH_S();
        }
        else if (c == '>'.code) { /* no needs (default) */
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            c = PFETCH_S();
        }

        if (c != cterm)
            return ONIGERR_INVALID_CALLOUT_PATTERN;

        var num = regCalloutListEntry(env);

        var ext = Regcomp.onigGetRegexExt(env.reg);
        if (ext.pattern == null) {
            r = Regcomp.onigExtSetPattern(env.reg, env.pattern, env.patternStart, env.patternEnd);
            if (r != ONIG_NORMAL) return r;
        }

        if (tagStart != tagEnd) {
            r = calloutTagEntry(env, env.reg, pat, tagStart, tagEnd, num);
            if (r != ONIG_NORMAL) return r;
        }

        var e = onigRegCalloutListAt(env.reg, num);
        if (e == null) return ONIGERR_MEMORY;

        np.v = new Node();
        np.v.nodeType = Node.NODE_GIMMICK;
        np.v.id = ONIG_NON_NAME_ID;
        np.v.num = num;
        np.v.type = Node.GIMMICK_CALLOUT;
        np.v.detailType = ONIG_CALLOUT_OF_CONTENTS;

        e.of = ONIG_CALLOUT_OF_CONTENTS;
        e.in_ = in_;
        e.nameId = ONIG_NON_NAME_ID;
        e.contentBytes = pat.sub(codeStart, codeEnd - codeStart);
        e.contentStart = 0;
        e.contentEnd = codeEnd - codeStart;

        src.v = p;
        return 0;
    }

    static function prsLong(s:Bytes, p:Int, end:Int, signOn:Bool, max:Float, rl:Array<Float>):Int {
        if (p >= end) return ONIGERR_INVALID_CALLOUT_ARG;
        var flag = 1;
        var v:Float = 0;
        while (p < end) {
            var c = mbcToCode(s, p, end);
            p += enclen(s, p);
            if (c >= '0'.code && c <= '9'.code) {
                var d = c - '0'.code;
                if (v > Math.ffloor((max - d) / 10))
                    return ONIGERR_INVALID_CALLOUT_ARG;
                v = v * 10 + d;
            }
            else if (signOn && (c == '-'.code || c == '+'.code)) {
                if (c == '-'.code) flag = -1;
            }
            else
                return ONIGERR_INVALID_CALLOUT_ARG;
            signOn = false;
        }
        rl[0] = flag * v;
        return ONIG_NORMAL;
    }

    static inline var MAX_CALLOUT_ARG_BYTE_LENGTH:Int = 128;

    static function prsCalloutArgs(skipMode:Bool, cterm:Int, src:IntRef, end:Int, maxArgNum:Int, types:Array<Int>,
            vals:Array<OnigValue>, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var c = 0;
        var n = 0;
        var buf = Bytes.alloc(MAX_CALLOUT_ARG_BYTE_LENGTH);

        if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;

        while (n < ONIG_CALLOUT_MAX_ARGS_NUM) {
            var cn = 0;
            var esc = false;
            var eesc = 0;
            var hasEesc = false;
            var bufend = 0;
            var s = p;
            var e = p;
            while (true) {
                if (p >= end) {
                    return ONIGERR_INVALID_CALLOUT_PATTERN;
                }
                e = p;
                c = mbcToCode(pat, p, end);
                p += enclen(pat, p);
                var addChar = false;
                if (esc) {
                    esc = false;
                    if (c == '\\'.code || c == cterm || c == ','.code) {
                        /* */
                    }
                    else {
                        e = eesc;
                        cn++;
                    }
                    addChar = true;
                }
                else {
                    if (c == '\\'.code) {
                        esc = true;
                        eesc = e;
                        hasEesc = true;
                    }
                    else if (c == cterm || c == ','.code)
                        break;
                    else {
                        addChar = true;
                    }
                }
                if (addChar) {
                    // add_char:
                    if (!skipMode) {
                        var clen = p - e;
                        if (bufend + clen > MAX_CALLOUT_ARG_BYTE_LENGTH) {
                            return ONIGERR_INVALID_CALLOUT_ARG; /* too long argument */
                        }
                        buf.blit(bufend, pat, e, clen);
                        bufend += clen;
                    }
                    cn++;
                }
            }

            if (cn != 0) {
                if (maxArgNum >= 0 && n >= maxArgNum) {
                    return ONIGERR_INVALID_CALLOUT_ARG;
                }
                if (!skipMode) {
                    if ((types[n] & ONIG_TYPE_LONG) != 0) {
                        var fixed = false;
                        if (cn > 0) {
                            var rl:Array<Float> = [0];
                            var r = prsLong(buf, 0, bufend, true, 2147483647.0, rl);
                            if (r == ONIG_NORMAL) {
                                vals[n].l = Std.int(rl[0]);
                                fixed = true;
                                types[n] = ONIG_TYPE_LONG;
                            }
                        }
                        if (!fixed) {
                            types[n] = (types[n] & ~ONIG_TYPE_LONG);
                            if (types[n] == ONIG_TYPE_VOID) {
                                return ONIGERR_INVALID_CALLOUT_ARG;
                            }
                        }
                    }

                    switch (types[n]) {
                        case ONIG_TYPE_LONG:
                        case ONIG_TYPE_CHAR:
                            if (cn != 1) {
                                return ONIGERR_INVALID_CALLOUT_ARG;
                            }
                            vals[n].c = mbcToCode(buf, 0, bufend);
                        case ONIG_TYPE_STRING:
                            var rs = Bytes.alloc(bufend + 1 + (e - s));
                            rs.blit(0, buf, 0, bufend);
                            vals[n].sBytes = rs;
                            vals[n].sStart = 0;
                            vals[n].sEnd = e - s;
                        case ONIG_TYPE_TAG:
                            if (hasEesc || !isAllowedCalloutTagName(pat, s, e)) {
                                return ONIGERR_INVALID_CALLOUT_TAG_NAME;
                            }
                            vals[n].sBytes = pat;
                            vals[n].sStart = s;
                            vals[n].sEnd = e;
                        default:
                            return ONIGERR_PARSER_BUG;
                    }
                }
                n++;
            }
            if (c == cterm) break;
        }

        if (c != cterm) {
            return ONIGERR_INVALID_CALLOUT_PATTERN;
        }
        src.v = p;
        return n;
    }

    /** (*name[TAG]) (*name[TAG]{a,b,..}) */
    public static function prsCalloutOfName(np:NodeRef, cterm:Int, src:IntRef, end:Int, env:ParseEnv):Int {
        var pat = env.pattern;
        var p = src.v;
        var c = 0;
        var r:Int;
        var argNum:Int;
        var maxArgNum:Int;
        var nameId:Int;
        var types = [0, 0, 0, 0];
        var vals = [new OnigValue(), new OnigValue(), new OnigValue(), new OnigValue()];

        inline function PFETCH_S():Int {
            var cc = mbcToCode(pat, p, end);
            p += enclen(pat, p);
            return cc;
        }

        initBuiltins();

        if (p >= end) return ONIGERR_INVALID_CALLOUT_PATTERN;

        var nameStart = p;
        var nameEnd = p;
        while (true) {
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            nameEnd = p;
            c = PFETCH_S();
            if (c == cterm || c == '['.code || c == '{'.code) break;
        }

        if (!isAllowedCalloutName(pat, nameStart, nameEnd))
            return ONIGERR_INVALID_CALLOUT_NAME;

        var tagStart = 0;
        var tagEnd = 0;
        if (c == '['.code) {
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            tagEnd = tagStart = p;
            while (p < end) {
                tagEnd = p;
                c = PFETCH_S();
                if (c == ']'.code) break;
            }
            if (!isAllowedCalloutTagName(pat, tagStart, tagEnd))
                return ONIGERR_INVALID_CALLOUT_TAG_NAME;
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;
            c = PFETCH_S();
        }
        else {
            tagStart = tagEnd = 0;
        }

        if (c == '{'.code) {
            if (p >= end) return ONIGERR_END_PATTERN_IN_GROUP;

            /* read for single check only */
            var save = p;
            var pr = new IntRef(p);
            argNum = prsCalloutArgs(true, '}'.code, pr, end, -1, null, null, env);
            if (argNum < 0) return argNum;
            p = pr.v;

            var isNotSingle = (p < end ? mbcToCode(pat, p, end) : 0) == cterm ? false : true;
            p = save;
            r = getCalloutNameIdByName(isNotSingle, pat, nameStart, nameEnd);
            if (r < 0) return r;
            nameId = r;

            maxArgNum = nameList[nameId].argNum;
            for (i in 0...maxArgNum) {
                types[i] = nameList[nameId].argTypes[i];
            }

            pr.v = p;
            argNum = prsCalloutArgs(false, '}'.code, pr, end, maxArgNum, types, vals, env);
            if (argNum < 0) return argNum;
            p = pr.v;

            if (p >= end) {
                return ONIGERR_END_PATTERN_IN_GROUP;
            }
            c = PFETCH_S();
        }
        else {
            argNum = 0;
            r = getCalloutNameIdByName(false, pat, nameStart, nameEnd);
            if (r < 0) return r;
            nameId = r;

            maxArgNum = nameList[nameId].argNum;
            for (i in 0...maxArgNum) {
                types[i] = nameList[nameId].argTypes[i];
            }
        }

        var fe = nameList[nameId];
        var in_ = fe.in_;
        var optArgNum = fe.optArgNum;
        if (argNum > maxArgNum || argNum < (maxArgNum - optArgNum)) {
            return ONIGERR_INVALID_CALLOUT_ARG;
        }

        if (c != cterm) {
            return ONIGERR_INVALID_CALLOUT_PATTERN;
        }

        var num = regCalloutListEntry(env);

        var ext = Regcomp.onigGetRegexExt(env.reg);
        if (ext.pattern == null) {
            r = Regcomp.onigExtSetPattern(env.reg, env.pattern, env.patternStart, env.patternEnd);
            if (r != ONIG_NORMAL) return r;
        }

        if (tagStart != tagEnd) {
            r = calloutTagEntry(env, env.reg, pat, tagStart, tagEnd, num);
            if (r != ONIG_NORMAL) return r;
        }

        var e = onigRegCalloutListAt(env.reg, num);
        if (e == null) return ONIGERR_MEMORY;

        var node = new Node();
        node.nodeType = Node.NODE_GIMMICK;
        node.id = nameId;
        node.num = num;
        node.type = Node.GIMMICK_CALLOUT;
        node.detailType = ONIG_CALLOUT_OF_NAME;

        e.of = ONIG_CALLOUT_OF_NAME;
        e.in_ = in_;
        e.nameId = nameId;
        e.type = fe.type;
        e.startFunc = fe.startFunc;
        e.endFunc = fe.endFunc;
        e.argNum = maxArgNum;
        e.argPassedNum = argNum;
        for (i in 0...maxArgNum) {
            e.argTypes[i] = types[i];
            if (i < argNum)
                e.argVals[i].copyFrom(vals[i]);
            else
                e.argVals[i].copyFrom(fe.optDefaults[i]);
        }

        np.v = node;
        src.v = p;
        return 0;
    }

    // ---- callout data (regexec.c) ----

    static function dataAt(args:OnigCalloutArgs, num:Int):CalloutData {
        return args.msa.calloutData[num - 1];
    }

    static function checkCalloutDataAndClearOldValues(args:OnigCalloutArgs):Int {
        var msa = args.msa;
        var d = dataAt(args, args.num);
        if (d.lastMatchAtCallCounter != msa.matchAtCallCounter) {
            d.clear();
            d.lastMatchAtCallCounter = msa.matchAtCallCounter;
            return d.lastMatchAtCallCounter;
        }
        return 0;
    }

    /** onig_get_callout_data_dont_clear_old: returns the type in rtype[0] and the value in val. */
    static function getCalloutDataDontClearOld(args:OnigCalloutArgs, calloutNum:Int, slot:Int, rtype:Array<Int>, val:OnigValue):Int {
        if (calloutNum <= 0) return ONIGERR_INVALID_ARGUMENT;
        var d = dataAt(args, calloutNum);
        var t = d.slotTypes[slot];
        rtype[0] = t;
        val.copyFrom(d.slotVals[slot]);
        return (t == ONIG_TYPE_VOID ? ONIG_VALUE_IS_NOT_SET : ONIG_NORMAL);
    }

    static function getCalloutData(args:OnigCalloutArgs, calloutNum:Int, slot:Int, rtype:Array<Int>, val:OnigValue):Int {
        if (calloutNum <= 0) return ONIGERR_INVALID_ARGUMENT;
        var msa = args.msa;
        var d = dataAt(args, calloutNum);
        if (d.lastMatchAtCallCounter != msa.matchAtCallCounter) {
            d.clear();
            d.lastMatchAtCallCounter = msa.matchAtCallCounter;
        }
        var t = d.slotTypes[slot];
        rtype[0] = t;
        val.copyFrom(d.slotVals[slot]);
        return (t == ONIG_TYPE_VOID ? ONIG_VALUE_IS_NOT_SET : ONIG_NORMAL);
    }

    static function setCalloutData(args:OnigCalloutArgs, calloutNum:Int, slot:Int, type:Int, val:OnigValue):Int {
        if (calloutNum <= 0) return ONIGERR_INVALID_ARGUMENT;
        var d = dataAt(args, calloutNum);
        d.slotTypes[slot] = type;
        d.slotVals[slot] = new OnigValue();
        d.slotVals[slot].copyFrom(val);
        d.lastMatchAtCallCounter = args.msa.matchAtCallCounter;
        return ONIG_NORMAL;
    }

    static function getArg(args:OnigCalloutArgs, index:Int, rtype:Array<Int>, val:OnigValue):Int {
        var e = onigRegCalloutListAt(args.regex, args.num);
        if (e == null) return ONIGERR_INVALID_ARGUMENT;
        if (e.of == ONIG_CALLOUT_OF_NAME) {
            rtype[0] = e.argTypes[index];
            val.copyFrom(e.argVals[index]);
            return ONIG_NORMAL;
        }
        return ONIGERR_INVALID_ARGUMENT;
    }

    // ---- builtin callout functions ----

    public static function call(func:Int, args:OnigCalloutArgs):Int {
        return switch (func) {
            case FUNC_FAIL: ONIG_CALLOUT_FAIL;
            case FUNC_MISMATCH: ONIG_MISMATCH;
            case FUNC_ERROR: builtinError(args);
            case FUNC_COUNT: builtinCount(args);
            case FUNC_TOTAL_COUNT: builtinTotalCount(args);
            case FUNC_MAX: builtinMax(args);
            case FUNC_CMP: builtinCmp(args);
            default: ONIG_CALLOUT_SUCCESS;
        }
    }

    static function builtinError(args:OnigCalloutArgs):Int {
        var val = new OnigValue();
        var t = [0];
        var r = getArg(args, 0, t, val);
        if (r != ONIG_NORMAL) return r;
        var n = val.l;
        if (n >= 0) {
            n = ONIGERR_INVALID_CALLOUT_BODY;
        }
        else if (Regerror.onigIsErrorCodeNeedsParam(n)) {
            n = ONIGERR_INVALID_CALLOUT_BODY;
        }
        return n;
    }

    static function builtinCount(args:OnigCalloutArgs):Int {
        checkCalloutDataAndClearOldValues(args);
        return builtinTotalCount(args);
    }

    static function builtinTotalCount(args:OnigCalloutArgs):Int {
        var type = [0];
        var val = new OnigValue();
        var aval = new OnigValue();
        var r = getArg(args, 0, type, aval);
        if (r != ONIG_NORMAL) return r;
        var countType = aval.c;
        if (countType != '>'.code && countType != 'X'.code && countType != '<'.code)
            return ONIGERR_INVALID_CALLOUT_ARG;

        r = getCalloutDataDontClearOld(args, args.num, 0, type, val);
        if (r < ONIG_NORMAL)
            return r;
        else if (r > ONIG_NORMAL) {
            /* type == void: initial state */
            val.l = 0;
        }

        var slot:Int;
        if (args.in_ == ONIG_CALLOUT_IN_RETRACTION) {
            slot = 2;
            if (countType == '<'.code)
                val.l++;
            else if (countType == 'X'.code)
                val.l--;
        }
        else {
            slot = 1;
            if (countType != '<'.code)
                val.l++;
        }

        r = setCalloutData(args, args.num, 0, ONIG_TYPE_LONG, val);
        if (r != ONIG_NORMAL) return r;

        /* slot 1: in progress counter, slot 2: in retraction counter */
        r = getCalloutDataDontClearOld(args, args.num, slot, type, val);
        if (r < ONIG_NORMAL)
            return r;
        else if (r > ONIG_NORMAL) {
            val.l = 0;
        }
        val.l++;
        r = setCalloutData(args, args.num, slot, ONIG_TYPE_LONG, val);
        if (r != ONIG_NORMAL) return r;
        return ONIG_CALLOUT_SUCCESS;
    }

    static function builtinMax(args:OnigCalloutArgs):Int {
        var type = [0];
        var val = new OnigValue();
        var aval = new OnigValue();
        var maxVal:Int;

        checkCalloutDataAndClearOldValues(args);

        var slot = 0;
        var r = getCalloutData(args, args.num, slot, type, val);
        if (r < ONIG_NORMAL)
            return r;
        else if (r > ONIG_NORMAL) {
            /* type == void: initial state */
            type[0] = ONIG_TYPE_LONG;
            val.l = 0;
        }

        r = getArg(args, 0, type, aval);
        if (r != ONIG_NORMAL) return r;
        if (type[0] == ONIG_TYPE_TAG) {
            r = getCalloutData(args, aval.tag, 0, type, aval);
            if (r < ONIG_NORMAL) return r;
            else if (r > ONIG_NORMAL)
                maxVal = 0;
            else
                maxVal = aval.l;
        }
        else { /* LONG */
            maxVal = aval.l;
        }

        r = getArg(args, 1, type, aval);
        if (r != ONIG_NORMAL) return r;
        var countType = aval.c;
        if (countType != '>'.code && countType != 'X'.code && countType != '<'.code)
            return ONIGERR_INVALID_CALLOUT_ARG;

        if (args.in_ == ONIG_CALLOUT_IN_RETRACTION) {
            if (countType == '<'.code) {
                if (val.l >= maxVal) return ONIG_CALLOUT_FAIL;
                val.l++;
            }
            else if (countType == 'X'.code)
                val.l--;
        }
        else {
            if (countType != '<'.code) {
                if (val.l >= maxVal) return ONIG_CALLOUT_FAIL;
                val.l++;
            }
        }

        r = setCalloutData(args, args.num, slot, ONIG_TYPE_LONG, val);
        if (r != ONIG_NORMAL) return r;
        return ONIG_CALLOUT_SUCCESS;
    }

    static inline var OP_EQ:Int = 0;
    static inline var OP_NE:Int = 1;
    static inline var OP_LT:Int = 2;
    static inline var OP_GT:Int = 3;
    static inline var OP_LE:Int = 4;
    static inline var OP_GE:Int = 5;

    static function builtinCmp(args:OnigCalloutArgs):Int {
        var type = [0];
        var val = new OnigValue();
        var lv:Int;
        var rv:Int;
        var op:Int;

        var r = getArg(args, 0, type, val);
        if (r != ONIG_NORMAL) return r;
        if (type[0] == ONIG_TYPE_TAG) {
            r = getCalloutData(args, val.tag, 0, type, val);
            if (r < ONIG_NORMAL) return r;
            else if (r > ONIG_NORMAL)
                lv = 0;
            else
                lv = val.l;
        }
        else { /* ONIG_TYPE_LONG */
            lv = val.l;
        }

        r = getArg(args, 2, type, val);
        if (r != ONIG_NORMAL) return r;
        if (type[0] == ONIG_TYPE_TAG) {
            r = getCalloutData(args, val.tag, 0, type, val);
            if (r < ONIG_NORMAL) return r;
            else if (r > ONIG_NORMAL)
                rv = 0;
            else
                rv = val.l;
        }
        else { /* ONIG_TYPE_LONG */
            rv = val.l;
        }

        var slot = 0;
        r = getCalloutData(args, args.num, slot, type, val);
        if (r < ONIG_NORMAL)
            return r;
        else if (r > ONIG_NORMAL) {
            /* type == void: initial state */
            var c1:Int;
            var c2:Int;
            r = getArg(args, 1, type, val);
            if (r != ONIG_NORMAL) return r;
            var sb = val.sBytes;
            var p = val.sStart;
            var send = val.sEnd;
            c1 = mbcToCode(sb, p, send);
            p += enclen(sb, p);
            if (p < send) {
                c2 = mbcToCode(sb, p, send);
                p += enclen(sb, p);
                if (p != send) return ONIGERR_INVALID_CALLOUT_ARG;
            }
            else
                c2 = 0;

            switch (c1) {
                case '='.code:
                    if (c2 != '='.code) return ONIGERR_INVALID_CALLOUT_ARG;
                    op = OP_EQ;
                case '!'.code:
                    if (c2 != '='.code) return ONIGERR_INVALID_CALLOUT_ARG;
                    op = OP_NE;
                case '<'.code:
                    if (c2 == '='.code) op = OP_LE;
                    else if (c2 == 0) op = OP_LT;
                    else return ONIGERR_INVALID_CALLOUT_ARG;
                case '>'.code:
                    if (c2 == '='.code) op = OP_GE;
                    else if (c2 == 0) op = OP_GT;
                    else return ONIGERR_INVALID_CALLOUT_ARG;
                default:
                    return ONIGERR_INVALID_CALLOUT_ARG;
            }
            var v = new OnigValue();
            v.l = op;
            r = setCalloutData(args, args.num, slot, ONIG_TYPE_LONG, v);
            if (r != ONIG_NORMAL) return r;
        }
        else {
            op = val.l;
        }

        var res = switch (op) {
            case OP_EQ: lv == rv;
            case OP_NE: lv != rv;
            case OP_LT: lv < rv;
            case OP_GT: lv > rv;
            case OP_LE: lv <= rv;
            default: lv >= rv;
        }
        return !res ? ONIG_CALLOUT_FAIL : ONIG_CALLOUT_SUCCESS;
    }

}
