// Ported from Oniguruma 6.9.8: src/unicode.c (and onig_is_in_code_range of src/regcomp.c)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. gperf lookups are replaced by maps built from
// the same tables (see UnicodeData.hx). See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;
import oniguruma.onig.Regenc.*;
import oniguruma.onig.Regenc.OnigCaseFoldCodeItem;
import oniguruma.onig.Regenc.OnigApplyAllCaseFoldFunc;
import oniguruma.onig.UnicodeData.*;

/** struct ByUnfoldKey */
class ByUnfoldKey {
    public var code:Int;
    public var index:Int;
    public var foldLen:Int;
    public function new(code:Int, index:Int, foldLen:Int) {
        this.code = code;
        this.index = index;
        this.foldLen = foldLen;
    }
}

class Unicode {

    // EGCB types
    public static inline var EGCB_Other:Int = 0;
    public static inline var EGCB_CR:Int = 1;
    public static inline var EGCB_LF:Int = 2;
    public static inline var EGCB_Control:Int = 3;
    public static inline var EGCB_Extend:Int = 4;
    public static inline var EGCB_Prepend:Int = 5;
    public static inline var EGCB_Regional_Indicator:Int = 6;
    public static inline var EGCB_SpacingMark:Int = 7;
    public static inline var EGCB_ZWJ:Int = 8;
    public static inline var EGCB_L:Int = 13;
    public static inline var EGCB_LV:Int = 14;
    public static inline var EGCB_LVT:Int = 15;
    public static inline var EGCB_T:Int = 16;
    public static inline var EGCB_V:Int = 17;

    static inline var EGCB_NOT_BREAK:Int = 0;
    static inline var EGCB_BREAK:Int = 1;
    static inline var EGCB_BREAK_UNDEF_GB11:Int = 2;
    static inline var EGCB_BREAK_UNDEF_RI_RI:Int = 3;

    // WB types
    static inline var WB_Any:Int = 0;
    static inline var WB_ALetter:Int = 1;
    static inline var WB_CR:Int = 2;
    static inline var WB_Double_Quote:Int = 3;
    static inline var WB_Extend:Int = 4;
    static inline var WB_ExtendNumLet:Int = 5;
    static inline var WB_Format:Int = 6;
    static inline var WB_Hebrew_Letter:Int = 7;
    static inline var WB_Katakana:Int = 8;
    static inline var WB_LF:Int = 9;
    static inline var WB_MidLetter:Int = 10;
    static inline var WB_MidNum:Int = 11;
    static inline var WB_MidNumLet:Int = 12;
    static inline var WB_Newline:Int = 13;
    static inline var WB_Numeric:Int = 14;
    static inline var WB_Regional_Indicator:Int = 15;
    static inline var WB_Single_Quote:Int = 16;
    static inline var WB_WSegSpace:Int = 17;
    static inline var WB_ZWJ:Int = 18;

    // ---- data decoding ----

    static function decodeInts(s:String):Array<Int> {
        var out = new Array<Int>();
        var v = 0;
        var shift = 0;
        for (i in 0...s.length) {
            var c = StringTools.fastCodeAt(s, i);
            var d = if (c >= 'A'.code && c <= 'Z'.code) c - 'A'.code
                else if (c >= 'a'.code && c <= 'z'.code) c - 'a'.code + 26
                else if (c >= '0'.code && c <= '9'.code) c - '0'.code + 52
                else if (c == '+'.code) 62
                else 63;
            v |= (d & 0x1f) << shift;
            if ((d & 0x20) != 0) {
                shift += 5;
            }
            else {
                out.push(v);
                v = 0;
                shift = 0;
            }
        }
        return out;
    }

    static var rangeInts:Array<Int> = null;
    static var codeRanges:Vector<IntArray> = null;

    /** CodeRanges[ctype]: [n, from0, to0, from1, to1, ...] */
    public static function getCodeRange(ctype:Int):IntArray {
        if (codeRanges == null) {
            codeRanges = new Vector<IntArray>(CODE_RANGES_NUM);
            rangeInts = decodeInts(RANGES);
        }
        var r = codeRanges[ctype];
        if (r == null) {
            var off = CODE_RANGE_OFFSETS[ctype];
            var n = rangeInts[off];
            r = new IntArray(n * 2 + 1);
            r[0] = n;
            var prev = 0;
            var j = off + 1;
            for (i in 0...n) {
                var f = prev + rangeInts[j++];
                var t = f + rangeInts[j++];
                r[i * 2 + 1] = f;
                r[i * 2 + 2] = t;
                prev = t;
            }
            // share decoded arrays between aliased ctypes
            for (k in 0...CODE_RANGES_NUM) {
                if (CODE_RANGE_OFFSETS[k] == off)
                    codeRanges[k] = r;
            }
        }
        return r;
    }

    static var propertyNameMap:Map<String, Int> = null;

    static var folds1:Array<Int> = null;
    static var folds2:Array<Int> = null;
    static var folds3:Array<Int> = null;
    static var unfoldKeys:Map<Int, ByUnfoldKey> = null;
    static var fold1Keys:Map<Int, Int> = null;
    static var fold2Keys:Map<String, Int> = null;
    static var fold3Keys:Map<String, Int> = null;

    public static var OnigUnicodeFolds1(get, never):Array<Int>;
    public static var OnigUnicodeFolds2(get, never):Array<Int>;
    public static var OnigUnicodeFolds3(get, never):Array<Int>;

    static function get_OnigUnicodeFolds1():Array<Int> {
        if (folds1 == null) initFolds();
        return folds1;
    }

    static function get_OnigUnicodeFolds2():Array<Int> {
        if (folds1 == null) initFolds();
        return folds2;
    }

    static function get_OnigUnicodeFolds3():Array<Int> {
        if (folds1 == null) initFolds();
        return folds3;
    }

    static function initFolds():Void {
        folds1 = decodeInts(FOLDS1);
        folds2 = decodeInts(FOLDS2);
        folds3 = decodeInts(FOLDS3);
        unfoldKeys = new Map();
        var u = decodeInts(UNFOLD_KEYS);
        var i = 0;
        while (i < u.length) {
            unfoldKeys.set(u[i], new ByUnfoldKey(u[i], u[i + 1], u[i + 2]));
            i += 3;
        }
        fold1Keys = new Map();
        for (index in decodeInts(FOLD1_KEYS)) {
            fold1Keys.set(folds1[index], index);
        }
        fold2Keys = new Map();
        for (index in decodeInts(FOLD2_KEYS)) {
            fold2Keys.set(folds2[index] + ',' + folds2[index + 1], index);
        }
        fold3Keys = new Map();
        for (index in decodeInts(FOLD3_KEYS)) {
            fold3Keys.set(folds3[index] + ',' + folds3[index + 1] + ',' + folds3[index + 2], index);
        }
    }

    /** onigenc_unicode_unfold_key */
    public static function onigencUnicodeUnfoldKey(code:Int):ByUnfoldKey {
        if (folds1 == null) initFolds();
        return unfoldKeys.get(code);
    }

    /** onigenc_unicode_fold1_key */
    public static function onigencUnicodeFold1Key(code:Int):Int {
        if (folds1 == null) initFolds();
        var r = fold1Keys.get(code);
        return r == null ? -1 : r;
    }

    /** onigenc_unicode_fold2_key */
    public static function onigencUnicodeFold2Key(codes:Array<Int>):Int {
        if (folds1 == null) initFolds();
        var r = fold2Keys.get(codes[0] + ',' + codes[1]);
        return r == null ? -1 : r;
    }

    /** onigenc_unicode_fold3_key */
    public static function onigencUnicodeFold3Key(codes:Array<Int>):Int {
        if (folds1 == null) initFolds();
        var r = fold3Keys.get(codes[0] + ',' + codes[1] + ',' + codes[2]);
        return r == null ? -1 : r;
    }

    static inline function FOLDS1_UNFOLDS_NUM(i:Int):Int {
        return folds1[i + 1];
    }

    static inline function FOLDS2_UNFOLDS_NUM(i:Int):Int {
        return folds2[i + 2];
    }

    static inline function FOLDS3_UNFOLDS_NUM(i:Int):Int {
        return folds3[i + 3];
    }

    static inline function FOLDS1_NEXT_INDEX(i:Int):Int {
        return i + 2 + FOLDS1_UNFOLDS_NUM(i);
    }

    static inline function FOLDS2_NEXT_INDEX(i:Int):Int {
        return i + 3 + FOLDS2_UNFOLDS_NUM(i);
    }

    static inline function FOLDS3_NEXT_INDEX(i:Int):Int {
        return i + 4 + FOLDS3_UNFOLDS_NUM(i);
    }

    /** onig_is_in_code_range (regcomp.c) on a code range being built (BBuf) */
    public static function onigIsInCodeRangeArr(data:Array<Int>, code:Int):Bool {
        var n = data[0];
        var low = 0;
        var high = n;
        while (low < high) {
            var x = (low + high) >> 1;
            if (ugt(code, data[x * 2 + 2]))
                low = x + 1;
            else
                high = x;
        }
        return low < n && uge(code, data[low * 2 + 1]);
    }

    /** onig_is_in_code_range (regcomp.c) */
    public static function onigIsInCodeRange(data:IntArray, code:Int):Bool {
        var n = data[0];
        var low = 0;
        var high = n;
        while (low < high) {
            var x = (low + high) >> 1;
            if (ugt(code, data[x * 2 + 2]))
                low = x + 1;
            else
                high = x;
        }
        return low < n && uge(code, data[low * 2 + 1]);
    }

    // ---- unicode.c ----

    static var foldBuf:Bytes = Bytes.alloc(8);

    public static function onigencUnicodeMbcCaseFold(flag:Int, s:Bytes, p:Int, end:Int, fold:Bytes, foldOff:Int):Int {
        if (folds1 == null) initFolds();
        var code = mbcToCode(s, p, end);
        var len = enclen(s, p);

        if (CASE_FOLD_IS_NOT_ASCII_ONLY(flag) || ONIGENC_IS_ASCII_CODE(code)) {
            var buk = unfoldKeys.get(code);
            if (buk != null) {
                if (buk.foldLen == 1) {
                    if (CASE_FOLD_IS_NOT_ASCII_ONLY(flag) || ONIGENC_IS_ASCII_CODE(folds1[buk.index]))
                        return codeToMbc(folds1[buk.index], fold, foldOff);
                }
                else {
                    var addr = buk.foldLen == 2 ? folds2 : buk.foldLen == 3 ? folds3 : null;
                    if (addr == null) return ONIGERR_INVALID_CODE_POINT_VALUE;
                    var rlen = 0;
                    for (i in 0...buk.foldLen) {
                        var c = addr[buk.index + i];
                        var l = codeToMbc(c, fold, foldOff);
                        foldOff += l;
                        rlen += l;
                    }
                    return rlen;
                }
            }
        }

        for (i in 0...len) {
            fold.set(foldOff++, s.get(p++));
        }
        return len;
    }

    static function applyCaseFold1(flag:Int, from:Int, to:Int, f:OnigApplyAllCaseFoldFunc, arg:Dynamic):Int {
        var buf1 = [0];
        var buf2 = [0];
        var i = from;
        while (i < to) {
            var fold = folds1[i];
            if (CASE_FOLD_IS_ASCII_ONLY(flag) && !ONIGENC_IS_ASCII_CODE(fold)) break;
            var n = FOLDS1_UNFOLDS_NUM(i);
            for (j in 0...n) {
                var unfold = folds1[i + 2 + j];
                if (CASE_FOLD_IS_ASCII_ONLY(flag) && !ONIGENC_IS_ASCII_CODE(unfold))
                    continue;
                buf1[0] = unfold;
                var r = f(fold, buf1, 1, arg);
                if (r != 0) return r;
                buf2[0] = fold;
                r = f(unfold, buf2, 1, arg);
                if (r != 0) return r;
                for (k in 0...j) {
                    var unfold2 = folds1[i + 2 + k];
                    if (CASE_FOLD_IS_ASCII_ONLY(flag) && !ONIGENC_IS_ASCII_CODE(unfold2)) continue;
                    buf1[0] = unfold2;
                    r = f(unfold, buf1, 1, arg);
                    if (r != 0) return r;
                    buf2[0] = unfold;
                    r = f(unfold2, buf2, 1, arg);
                    if (r != 0) return r;
                }
            }
            i = FOLDS1_NEXT_INDEX(i);
        }
        return 0;
    }

    static function applyCaseFoldN(folds:Array<Int>, flen:Int, from:Int, to:Int, f:OnigApplyAllCaseFoldFunc, arg:Dynamic):Int {
        var buf1 = [0];
        var i = from;
        while (i < to) {
            var fold = folds.slice(i, i + flen);
            var n = folds[i + flen];
            for (j in 0...n) {
                var unfold = folds[i + flen + 1 + j];
                var r = f(unfold, fold, flen, arg);
                if (r != 0) return r;
                for (k in 0...j) {
                    var unfold2 = folds[i + flen + 1 + k];
                    buf1[0] = unfold2;
                    r = f(unfold, buf1, 1, arg);
                    if (r != 0) return r;
                    buf1[0] = unfold;
                    r = f(unfold2, buf1, 1, arg);
                    if (r != 0) return r;
                }
            }
            i = i + flen + 1 + n;
        }
        return 0;
    }

    public static function onigencUnicodeApplyAllCaseFold(flag:Int, f:OnigApplyAllCaseFoldFunc, arg:Dynamic):Int {
        if (folds1 == null) initFolds();
        var r = applyCaseFold1(flag, 0, FOLDS1_NORMAL_END_INDEX, f, arg);
        if (r != 0) return r;
        r = applyCaseFold1(flag, FOLDS1_NORMAL_END_INDEX, FOLDS1_END_INDEX, f, arg);
        if (r != 0) return r;
        if ((flag & INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR) == 0)
            return 0;
        r = applyCaseFoldN(folds2, 2, 0, FOLDS2_NORMAL_END_INDEX, f, arg);
        if (r != 0) return r;
        r = applyCaseFoldN(folds2, 2, FOLDS2_NORMAL_END_INDEX, FOLDS2_END_INDEX, f, arg);
        if (r != 0) return r;
        r = applyCaseFoldN(folds3, 3, 0, FOLDS3_NORMAL_END_INDEX, f, arg);
        if (r != 0) return r;
        return 0;
    }

    static inline function setItem(items:Array<OnigCaseFoldCodeItem>, n:Int, byteLen:Int, codeLen:Int, c0:Int, c1:Int, c2:Int):Void {
        var it = items[n];
        it.byteLen = byteLen;
        it.codeLen = codeLen;
        it.code[0] = c0;
        it.code[1] = c1;
        it.code[2] = c2;
    }

    public static function onigencUnicodeGetCaseFoldCodesByStr(flag:Int, s:Bytes, p:Int, end:Int, items:Array<OnigCaseFoldCodeItem>):Int {
        if (folds1 == null) initFolds();
        var n = 0;
        var lens = [0, 0, 0];
        var codes = [0, 0, 0];
        var origCodes = [0, 0, 0];
        var cs:Array<Array<Int>> = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
        var ncs = [0, 0, 0];

        var code = mbcToCode(s, p, end);
        if (CASE_FOLD_IS_ASCII_ONLY(flag)) {
            if (!ONIGENC_IS_ASCII_CODE(code)) return n;
        }
        var len = enclen(s, p);

        origCodes[0] = code;
        lens[0] = len;
        p += len;

        var buk1 = unfoldKeys.get(origCodes[0]);
        if (buk1 != null && buk1.foldLen == 1) {
            codes[0] = folds1[buk1.index];
        }
        else
            codes[0] = origCodes[0];

        if ((flag & INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR) != 0 && p < end) {
            code = mbcToCode(s, p, end);
            origCodes[1] = code;
            len = enclen(s, p);
            lens[1] = lens[0] + len;
            var buk = unfoldKeys.get(origCodes[1]);
            if (buk != null && buk.foldLen == 1) {
                codes[1] = folds1[buk.index];
            }
            else
                codes[1] = origCodes[1];

            p += len;
            if (p < end) {
                code = mbcToCode(s, p, end);
                origCodes[2] = code;
                len = enclen(s, p);
                lens[2] = lens[1] + len;
                buk = unfoldKeys.get(origCodes[2]);
                if (buk != null && buk.foldLen == 1) {
                    codes[2] = folds1[buk.index];
                }
                else
                    codes[2] = origCodes[2];

                var index = onigencUnicodeFold3Key(codes);
                if (index >= 0) {
                    var m = FOLDS3_UNFOLDS_NUM(index);
                    for (i in 0...m) {
                        setItem(items, n, lens[2], 1, folds3[index + 4 + i], 0, 0);
                        n++;
                    }
                    for (fn in 0...3) {
                        cs[fn][0] = folds3[index + fn];
                        ncs[fn] = 1;
                        var sindex = onigencUnicodeFold1Key(cs[fn][0]);
                        if (sindex >= 0) {
                            var m2 = FOLDS1_UNFOLDS_NUM(sindex);
                            for (i in 0...m2) {
                                cs[fn][i + 1] = folds1[sindex + 2 + i];
                            }
                            ncs[fn] += m2;
                        }
                    }
                    for (i in 0...ncs[0]) {
                        for (j in 0...ncs[1]) {
                            for (k in 0...ncs[2]) {
                                if (cs[0][i] == origCodes[0] && cs[1][j] == origCodes[1] && cs[2][k] == origCodes[2])
                                    continue;
                                setItem(items, n, lens[2], 3, cs[0][i], cs[1][j], cs[2][k]);
                                n++;
                            }
                        }
                    }
                    return n;
                }
            }

            var index = onigencUnicodeFold2Key(codes);
            if (index >= 0) {
                var m = FOLDS2_UNFOLDS_NUM(index);
                for (i in 0...m) {
                    setItem(items, n, lens[1], 1, folds2[index + 3 + i], 0, 0);
                    n++;
                }
                for (fn in 0...2) {
                    cs[fn][0] = folds2[index + fn];
                    ncs[fn] = 1;
                    var sindex = onigencUnicodeFold1Key(cs[fn][0]);
                    if (sindex >= 0) {
                        var m2 = FOLDS1_UNFOLDS_NUM(sindex);
                        for (i in 0...m2) {
                            cs[fn][i + 1] = folds1[sindex + 2 + i];
                        }
                        ncs[fn] += m2;
                    }
                }
                for (i in 0...ncs[0]) {
                    for (j in 0...ncs[1]) {
                        if (cs[0][i] == origCodes[0] && cs[1][j] == origCodes[1])
                            continue;
                        setItem(items, n, lens[1], 2, cs[0][i], cs[1][j], 0);
                        n++;
                    }
                }
                return n;
            }
        }

        // fold1:
        if (buk1 != null) {
            if (buk1.foldLen == 1) {
                if (CASE_FOLD_IS_NOT_ASCII_ONLY(flag) || ONIGENC_IS_ASCII_CODE(folds1[buk1.index])) {
                    setItem(items, 0, lens[0], 1, folds1[buk1.index], 0, 0);
                    n++;
                }
                var un = FOLDS1_UNFOLDS_NUM(buk1.index);
                for (i in 0...un) {
                    var unfold = folds1[buk1.index + 2 + i];
                    if (unfold != origCodes[0]) {
                        if (CASE_FOLD_IS_NOT_ASCII_ONLY(flag) || ONIGENC_IS_ASCII_CODE(unfold)) {
                            setItem(items, n, lens[0], 1, unfold, 0, 0);
                            n++;
                        }
                    }
                }
            }
            else if ((flag & INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR) != 0) {
                if (buk1.foldLen == 2) {
                    var m = FOLDS2_UNFOLDS_NUM(buk1.index);
                    for (i in 0...m) {
                        var unfold = folds2[buk1.index + 3 + i];
                        if (unfold == origCodes[0]) continue;
                        setItem(items, n, lens[0], 1, unfold, 0, 0);
                        n++;
                    }
                    for (fn in 0...2) {
                        cs[fn][0] = folds2[buk1.index + fn];
                        ncs[fn] = 1;
                        var index = onigencUnicodeFold1Key(cs[fn][0]);
                        if (index >= 0) {
                            var m2 = FOLDS1_UNFOLDS_NUM(index);
                            for (i in 0...m2) {
                                cs[fn][i + 1] = folds1[index + 2 + i];
                            }
                            ncs[fn] += m2;
                        }
                    }
                    for (i in 0...ncs[0]) {
                        for (j in 0...ncs[1]) {
                            setItem(items, n, lens[0], 2, cs[0][i], cs[1][j], 0);
                            n++;
                        }
                    }
                }
                else { /* fold_len == 3 */
                    var m = FOLDS3_UNFOLDS_NUM(buk1.index);
                    for (i in 0...m) {
                        var unfold = folds3[buk1.index + 4 + i];
                        if (unfold == origCodes[0]) continue;
                        setItem(items, n, lens[0], 1, unfold, 0, 0);
                        n++;
                    }
                    for (fn in 0...3) {
                        cs[fn][0] = folds3[buk1.index + fn];
                        ncs[fn] = 1;
                        var index = onigencUnicodeFold1Key(cs[fn][0]);
                        if (index >= 0) {
                            var m2 = FOLDS1_UNFOLDS_NUM(index);
                            for (i in 0...m2) {
                                cs[fn][i + 1] = folds1[index + 2 + i];
                            }
                            ncs[fn] += m2;
                        }
                    }
                    for (i in 0...ncs[0]) {
                        for (j in 0...ncs[1]) {
                            for (k in 0...ncs[2]) {
                                setItem(items, n, lens[0], 3, cs[0][i], cs[1][j], cs[2][k]);
                                n++;
                            }
                        }
                    }
                }
            }
        }
        else {
            var index = onigencUnicodeFold1Key(origCodes[0]);
            if (index >= 0) {
                var m = FOLDS1_UNFOLDS_NUM(index);
                for (i in 0...m) {
                    code = folds1[index + 2 + i];
                    if (CASE_FOLD_IS_NOT_ASCII_ONLY(flag) || ONIGENC_IS_ASCII_CODE(code)) {
                        setItem(items, n, lens[0], 1, code, 0, 0);
                        n++;
                    }
                }
            }
        }
        return n;
    }

    // ---- word break ----

    static var wbRanges:Array<Int> = null;
    static var egcbRanges:Array<Int> = null;

    static function decodeSegments(s:String):Array<Int> {
        var raw = decodeInts(s);
        var n = raw[0];
        var out = new Array<Int>();
        out.resize(n * 3);
        var prev = 0;
        var j = 1;
        for (i in 0...n) {
            var a = prev + raw[j++];
            var b = a + raw[j++];
            out[i * 3] = a;
            out[i * 3 + 1] = b;
            out[i * 3 + 2] = raw[j++];
            prev = b;
        }
        return out;
    }

    static function segmentType(ranges:Array<Int>, code:Int):Int {
        var num = Std.int(ranges.length / 3);
        var low = 0;
        var high = num;
        while (low < high) {
            var x = (low + high) >> 1;
            if (code > ranges[x * 3 + 1])
                low = x + 1;
            else
                high = x;
        }
        return (low < num && code >= ranges[low * 3]) ? ranges[low * 3 + 2] : 0;
    }

    static function wbGetType(code:Int):Int {
        if (wbRanges == null) wbRanges = decodeSegments(WB_RANGES);
        return segmentType(wbRanges, code);
    }

    static inline function IS_WB_IGNORE_TAIL(t:Int):Bool {
        return t == WB_Extend || t == WB_Format || t == WB_ZWJ;
    }

    static inline function IS_WB_AHLetter(t:Int):Bool {
        return t == WB_ALetter || t == WB_Hebrew_Letter;
    }

    static inline function IS_WB_MidNumLetQ(t:Int):Bool {
        return t == WB_MidNumLet || t == WB_Single_Quote;
    }

    /** wb_get_next_main_code: returns the type of the next main code, or -1. */
    static function wbGetNextMainType(s:Bytes, p:Int, end:Int):Int {
        while (true) {
            p += enclen(s, p);
            if (p >= end) break;
            var code = mbcToCode(s, p, end);
            var type = wbGetType(code);
            if (!IS_WB_IGNORE_TAIL(type)) {
                return type;
            }
        }
        return -1;
    }

    public static function onigencWbIsBreakPosition(s:Bytes, p:Int, prev:Int, start:Int, end:Int):Bool {
        var pp:Int;
        /* WB1: sot / Any */
        if (p == start) return true;
        /* WB2: Any / eot */
        if (p == end) return true;

        if (prev == NULL_UCHARP) {
            prev = onigencGetPrevCharHead(s, start, p);
            if (prev == NULL_UCHARP) return true;
        }

        var cfrom = mbcToCode(s, prev, end);
        var cto = mbcToCode(s, p, end);

        var from = wbGetType(cfrom);
        var to = wbGetType(cto);

        /* short cut */
        if (from == 0 && to == 0) return true;

        /* WB3: CR + LF */
        if (from == WB_CR && to == WB_LF) return false;

        /* WB3a: (Newline|CR|LF) /  */
        if (from == WB_Newline || from == WB_CR || from == WB_LF) return true;
        /* WB3b: / (Newline|CR|LF) */
        if (to == WB_Newline || to == WB_CR || to == WB_LF) return true;

        /* WB3c: ZWJ + {Extended_Pictographic} */
        if (from == WB_ZWJ) {
            if (onigencUnicodeIsCodeCtype(cto, PROP_INDEX_EXTENDEDPICTOGRAPHIC))
                return false;
        }

        /* WB3d: WSegSpace + WSegSpace */
        if (from == WB_WSegSpace && to == WB_WSegSpace) return false;

        /* WB4:  X (Extend|Format|ZWJ)* -> X */
        if (IS_WB_IGNORE_TAIL(to)) return false;
        if (IS_WB_IGNORE_TAIL(from)) {
            while ((pp = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                prev = pp;
                cfrom = mbcToCode(s, prev, end);
                from = wbGetType(cfrom);
                if (!IS_WB_IGNORE_TAIL(from))
                    break;
            }
        }

        if (IS_WB_AHLetter(from)) {
            /* WB5: AHLetter + AHLetter */
            if (IS_WB_AHLetter(to)) return false;

            /* WB6: AHLetter + (MidLetter | MidNumLetQ) AHLetter */
            if (to == WB_MidLetter || IS_WB_MidNumLetQ(to)) {
                var to2 = wbGetNextMainType(s, p, end);
                if (to2 >= 0) {
                    if (IS_WB_AHLetter(to2)) return false;
                }
            }
        }

        /* WB7: AHLetter (MidLetter | MidNumLetQ) + AHLetter */
        if (from == WB_MidLetter || IS_WB_MidNumLetQ(from)) {
            if (IS_WB_AHLetter(to)) {
                var from2 = WB_Any;
                while ((pp = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                    prev = pp;
                    from2 = wbGetType(mbcToCode(s, prev, end));
                    if (!IS_WB_IGNORE_TAIL(from2))
                        break;
                }
                if (IS_WB_AHLetter(from2)) return false;
            }
        }

        if (from == WB_Hebrew_Letter) {
            /* WB7a: Hebrew_Letter + Single_Quote */
            if (to == WB_Single_Quote) return false;

            /* WB7b: Hebrew_Letter + Double_Quote Hebrew_Letter */
            if (to == WB_Double_Quote) {
                var to2 = wbGetNextMainType(s, p, end);
                if (to2 >= 0) {
                    if (to2 == WB_Hebrew_Letter) return false;
                }
            }
        }

        /* WB7c: Hebrew_Letter Double_Quote + Hebrew_Letter */
        if (from == WB_Double_Quote) {
            if (to == WB_Hebrew_Letter) {
                var from2 = WB_Any;
                while ((pp = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                    prev = pp;
                    from2 = wbGetType(mbcToCode(s, prev, end));
                    if (!IS_WB_IGNORE_TAIL(from2))
                        break;
                }
                if (from2 == WB_Hebrew_Letter) return false;
            }
        }

        if (to == WB_Numeric) {
            /* WB8: Numeric + Numeric */
            if (from == WB_Numeric) return false;

            /* WB9: AHLetter + Numeric */
            if (IS_WB_AHLetter(from)) return false;

            /* WB11: Numeric (MidNum | MidNumLetQ) + Numeric */
            if (from == WB_MidNum || IS_WB_MidNumLetQ(from)) {
                var from2 = WB_Any;
                while ((pp = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                    prev = pp;
                    from2 = wbGetType(mbcToCode(s, prev, end));
                    if (!IS_WB_IGNORE_TAIL(from2))
                        break;
                }
                if (from2 == WB_Numeric) return false;
            }
        }

        if (from == WB_Numeric) {
            /* WB10: Numeric + AHLetter */
            if (IS_WB_AHLetter(to)) return false;

            /* WB12: Numeric + (MidNum | MidNumLetQ) Numeric */
            if (to == WB_MidNum || IS_WB_MidNumLetQ(to)) {
                var to2 = wbGetNextMainType(s, p, end);
                if (to2 >= 0) {
                    if (to2 == WB_Numeric) return false;
                }
            }
        }

        /* WB13: Katakana + Katakana */
        if (from == WB_Katakana && to == WB_Katakana) return false;

        /* WB13a: (AHLetter | Numeric | Katakana | ExtendNumLet) + ExtendNumLet */
        if (IS_WB_AHLetter(from) || from == WB_Numeric || from == WB_Katakana || from == WB_ExtendNumLet) {
            if (to == WB_ExtendNumLet) return false;
        }

        /* WB13b: ExtendNumLet + (AHLetter | Numeric | Katakana) */
        if (from == WB_ExtendNumLet) {
            if (IS_WB_AHLetter(to) || to == WB_Numeric || to == WB_Katakana)
                return false;
        }

        /* WB15:   sot (RI RI)* RI + RI */
        /* WB16: [^RI] (RI RI)* RI + RI */
        if (from == WB_Regional_Indicator && to == WB_Regional_Indicator) {
            var n = 0;
            while ((prev = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                var from2 = wbGetType(mbcToCode(s, prev, end));
                if (from2 != WB_Regional_Indicator)
                    break;
                n++;
            }
            if ((n % 2) == 0) return false;
        }

        /* WB999: Any / Any */
        return true;
    }

    // ---- extended grapheme cluster ----

    static function egcbGetType(code:Int):Int {
        if (egcbRanges == null) egcbRanges = decodeSegments(EGCB_RANGES);
        return segmentType(egcbRanges, code);
    }

    static inline function IS_CONTROL_CR_LF(code:Int):Bool {
        return code <= EGCB_Control && code >= EGCB_CR;
    }

    static inline function IS_HANGUL(code:Int):Bool {
        return code >= EGCB_L;
    }

    static function unicodeEgcbIsBreak2code(fromCode:Int, toCode:Int):Int {
        var from = egcbGetType(fromCode);
        var to = egcbGetType(toCode);

        /* short cut */
        if (from == 0 && to == 0) return EGCB_BREAK;

        /* GB3 */
        if (from == EGCB_CR && to == EGCB_LF) return EGCB_NOT_BREAK;
        /* GB4 */
        if (IS_CONTROL_CR_LF(from)) return EGCB_BREAK;
        /* GB5 */
        if (IS_CONTROL_CR_LF(to)) return EGCB_BREAK;

        if (IS_HANGUL(from) && IS_HANGUL(to)) {
            /* GB6 */
            if (from == EGCB_L && to != EGCB_T) return EGCB_NOT_BREAK;
            /* GB7 */
            if ((from == EGCB_LV || from == EGCB_V) && (to == EGCB_V || to == EGCB_T)) return EGCB_NOT_BREAK;
            /* GB8 */
            if ((to == EGCB_T) && (from == EGCB_LVT || from == EGCB_T))
                return EGCB_NOT_BREAK;
            return EGCB_BREAK;
        }

        /* GB9 */
        if (to == EGCB_Extend || to == EGCB_ZWJ) return EGCB_NOT_BREAK;
        /* GB9a */
        if (to == EGCB_SpacingMark) return EGCB_NOT_BREAK;
        /* GB9b */
        if (from == EGCB_Prepend) return EGCB_NOT_BREAK;

        /* GB11 */
        if (from == EGCB_ZWJ) {
            if (onigencUnicodeIsCodeCtype(toCode, PROP_INDEX_EXTENDEDPICTOGRAPHIC))
                return EGCB_BREAK_UNDEF_GB11;
            return EGCB_BREAK;
        }

        /* GB12, GB13 */
        if (from == EGCB_Regional_Indicator && to == EGCB_Regional_Indicator) {
            return EGCB_BREAK_UNDEF_RI_RI;
        }

        return EGCB_BREAK;
    }

    public static function onigencEgcbIsBreakPosition(s:Bytes, p:Int, prev:Int, start:Int, end:Int):Bool {
        /* GB1 and GB2 */
        if (p == start) return true;
        if (p == end) return true;

        if (prev == NULL_UCHARP) {
            prev = onigencGetPrevCharHead(s, start, p);
            if (prev == NULL_UCHARP) return true;
        }

        var from = mbcToCode(s, prev, end);
        var to = mbcToCode(s, p, end);

        var btype = unicodeEgcbIsBreak2code(from, to);
        switch (btype) {
            case EGCB_NOT_BREAK:
                return false;
            case EGCB_BREAK:
                return true;
            case EGCB_BREAK_UNDEF_GB11:
                while ((prev = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                    from = mbcToCode(s, prev, end);
                    if (onigencUnicodeIsCodeCtype(from, PROP_INDEX_EXTENDEDPICTOGRAPHIC))
                        return false;
                    var type = egcbGetType(from);
                    if (type != EGCB_Extend)
                        break;
                }
            case EGCB_BREAK_UNDEF_RI_RI:
                var n = 0;
                while ((prev = onigencGetPrevCharHead(s, start, prev)) != NULL_UCHARP) {
                    from = mbcToCode(s, prev, end);
                    var type = egcbGetType(from);
                    if (type != EGCB_Regional_Indicator)
                        break;
                    n++;
                }
                if ((n % 2) == 0) return false;
            default:
        }
        return true;
    }

    // ---- properties ----

    public static function onigencUnicodeIsCodeCtype(code:Int, ctype:Int):Bool {
        if (ctype <= ONIGENC_MAX_STD_CTYPE && code < 256) {
            return (EncUNICODE_ISO_8859_1_CtypeTable[code] & CTYPE_TO_BIT(ctype)) != 0;
        }
        if (ctype >= CODE_RANGES_NUM) {
            return false; // ONIGERR_TYPE_BUG (no user defined property)
        }
        return onigIsInCodeRange(getCodeRange(ctype), code);
    }

    /** onigenc_unicode_ctype_code_range: returns the ranges, or null (ONIGERR_TYPE_BUG). */
    public static function onigencUnicodeCtypeCodeRange(ctype:Int):IntArray {
        if (ctype >= CODE_RANGES_NUM) {
            return null;
        }
        return getCodeRange(ctype);
    }

    public static function onigencUnicodePropertyNameToCtype(s:Bytes, name:Int, end:Int):Int {
        var buf = new StringBuf();
        var len = 0;
        var p = name;
        while (p < end) {
            var code = mbcToCode(s, p, end);
            if (code >= 0x80)
                return ONIGERR_INVALID_CHAR_PROPERTY_NAME;
            if (code != ' '.code && code != '-'.code && code != '_'.code) {
                // gperf --ignore-case: ASCII letters compare case insensitively
                buf.addChar((code >= 'A'.code && code <= 'Z'.code) ? code + 32 : code);
                len++;
                if (len >= PROPERTY_NAME_MAX_SIZE)
                    return ONIGERR_INVALID_CHAR_PROPERTY_NAME;
            }
            p += enclen(s, p);
        }

        if (propertyNameMap == null) {
            propertyNameMap = new Map();
            var names = PROPERTY_NAMES.split(' ');
            var ctypes = decodeInts(PROPERTY_CTYPES);
            for (i in 0...names.length) {
                propertyNameMap.set(names[i], ctypes[i]);
            }
        }
        var ctype = propertyNameMap.get(buf.toString());
        if (ctype != null) {
            return ctype;
        }
        return ONIGERR_INVALID_CHAR_PROPERTY_NAME;
    }

}
