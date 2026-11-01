// Ported from Oniguruma 6.9.8: src/regenc.c, src/regenc.h, src/utf8.c
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. Only the UTF-8 encoding (ONIG_ENCODING_UTF8) is ported,
// its function table is turned into static functions. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;
import oniguruma.onig.Onig.*;

/** OnigCaseFoldCodeItem */
class OnigCaseFoldCodeItem {
    public var byteLen:Int = 0;
    public var codeLen:Int = 0;
    public var code:Vector<Int>;
    public function new() {
        code = new Vector<Int>(ONIGENC_MAX_COMP_CASE_FOLD_CODE_LEN);
    }
    public static function newArray():Array<OnigCaseFoldCodeItem> {
        return [for (i in 0...ONIGENC_GET_CASE_FOLD_CODES_MAX_NUM) new OnigCaseFoldCodeItem()];
    }
}

/** OnigApplyAllCaseFoldFunc: (from, to codes, to_len, arg) */
typedef OnigApplyAllCaseFoldFunc = (from:Int, to:Array<Int>, toLen:Int, arg:Dynamic) -> Int;

/**
 * Encoding layer for UTF-8 (the only encoding vscode-oniguruma uses).
 * Pointers are offsets in a `Bytes`, `NULL` is -1.
 */
class Regenc {

    public static inline var ONIGENC_MBC_MAXLEN:Int = 4;
    public static inline var ONIGENC_MBC_MINLEN:Int = 1;
    public static inline var NULL_UCHARP:Int = -1;
    public static inline var MAX_CODE_POINT:Int = -1; // ~((OnigCodePoint)0) = 0xffffffff, compared as unsigned
    public static inline var ASCII_LIMIT:Int = 127;
    public static inline var NEWLINE_CODE:Int = 0x0a;
    public static inline var ONIGENC_CODE_TO_MBC_MAXLEN:Int = 7;

    // character types bit flags
    public static inline var BIT_CTYPE_NEWLINE:Int = 1 << ONIGENC_CTYPE_NEWLINE;
    public static inline var BIT_CTYPE_ALPHA:Int = 1 << ONIGENC_CTYPE_ALPHA;
    public static inline var BIT_CTYPE_BLANK:Int = 1 << ONIGENC_CTYPE_BLANK;
    public static inline var BIT_CTYPE_CNTRL:Int = 1 << ONIGENC_CTYPE_CNTRL;
    public static inline var BIT_CTYPE_DIGIT:Int = 1 << ONIGENC_CTYPE_DIGIT;
    public static inline var BIT_CTYPE_GRAPH:Int = 1 << ONIGENC_CTYPE_GRAPH;
    public static inline var BIT_CTYPE_LOWER:Int = 1 << ONIGENC_CTYPE_LOWER;
    public static inline var BIT_CTYPE_PRINT:Int = 1 << ONIGENC_CTYPE_PRINT;
    public static inline var BIT_CTYPE_PUNCT:Int = 1 << ONIGENC_CTYPE_PUNCT;
    public static inline var BIT_CTYPE_SPACE:Int = 1 << ONIGENC_CTYPE_SPACE;
    public static inline var BIT_CTYPE_UPPER:Int = 1 << ONIGENC_CTYPE_UPPER;
    public static inline var BIT_CTYPE_XDIGIT:Int = 1 << ONIGENC_CTYPE_XDIGIT;
    public static inline var BIT_CTYPE_WORD:Int = 1 << ONIGENC_CTYPE_WORD;
    public static inline var BIT_CTYPE_ALNUM:Int = 1 << ONIGENC_CTYPE_ALNUM;
    public static inline var BIT_CTYPE_ASCII:Int = 1 << ONIGENC_CTYPE_ASCII;

    public static final EncLen_UTF8:Vector<Int> = {
        var v = new Vector<Int>(256);
        for (i in 0...256) {
            v[i] = i < 0xc0 ? 1 : i < 0xe0 ? 2 : i < 0xf0 ? 3 : i < 0xf5 ? 4 : 1;
        }
        v;
    };

    public static final OnigEncAsciiCtypeTable:Vector<Int> = Vector.fromArrayCopy([16392,16392,16392,16392,16392,16392,16392,16392,16392,16908,16905,16904,16904,16904,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,17028,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,30896,30896,30896,30896,30896,30896,30896,30896,30896,30896,16800,16800,16800,16800,16800,16800,16800,31906,31906,31906,31906,31906,31906,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,16800,16800,16800,16800,20896,16800,30946,30946,30946,30946,30946,30946,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,16800,16800,16800,16800,16392,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);

    public static final EncUNICODE_ISO_8859_1_CtypeTable:Vector<Int> = Vector.fromArrayCopy([16392,16392,16392,16392,16392,16392,16392,16392,16392,17036,17033,17032,17032,17032,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,16392,17028,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,16800,30896,30896,30896,30896,30896,30896,30896,30896,30896,30896,16800,16800,16800,16800,16800,16800,16800,31906,31906,31906,31906,31906,31906,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,29858,16800,16800,16800,16800,20896,16800,30946,30946,30946,30946,30946,30946,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,28898,16800,16800,16800,16800,16392,8,8,8,8,8,648,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,644,416,160,160,160,160,160,160,160,160,12514,416,160,168,160,160,160,160,4256,4256,160,12514,160,416,160,4256,12514,416,4256,4256,4256,416,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,13474,160,13474,13474,13474,13474,13474,13474,13474,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,12514,160,12514,12514,12514,12514,12514,12514,12514,12514]);

    /** unsigned comparisons of code points (OnigCodePoint is unsigned in C) */
    public static inline function ugt(a:Int, b:Int):Bool {
        return (a ^ 0x80000000) > (b ^ 0x80000000);
    }

    public static inline function uge(a:Int, b:Int):Bool {
        return (a ^ 0x80000000) >= (b ^ 0x80000000);
    }

    public static inline function ult(a:Int, b:Int):Bool {
        return (a ^ 0x80000000) < (b ^ 0x80000000);
    }

    public static inline function ule(a:Int, b:Int):Bool {
        return (a ^ 0x80000000) <= (b ^ 0x80000000);
    }

    public static inline function CTYPE_TO_BIT(ctype:Int):Int {
        return 1 << ctype;
    }

    public static inline function CTYPE_IS_WORD_GRAPH_PRINT(ctype:Int):Bool {
        return ctype == ONIGENC_CTYPE_WORD || ctype == ONIGENC_CTYPE_GRAPH || ctype == ONIGENC_CTYPE_PRINT;
    }

    public static inline function CASE_FOLD_IS_ASCII_ONLY(flag:Int):Bool {
        return (flag & ONIGENC_CASE_FOLD_ASCII_ONLY) != 0;
    }

    public static inline function CASE_FOLD_IS_NOT_ASCII_ONLY(flag:Int):Bool {
        return (flag & ONIGENC_CASE_FOLD_ASCII_ONLY) == 0;
    }

    public static inline function ONIGENC_IS_ASCII_CODE(code:Int):Bool {
        return code < 0x80;
    }

    public static inline function ONIGENC_IS_CODE_ASCII(code:Int):Bool {
        return code < 128;
    }

    public static inline function ONIGENC_ASCII_CODE_TO_LOWER_CASE(c:Int):Int {
        return (c >= 0x41 && c <= 0x5a) ? c + 0x20 : c;
    }

    public static inline function ONIGENC_IS_ASCII_CODE_CTYPE(code:Int, ctype:Int):Bool {
        return (OnigEncAsciiCtypeTable[code] & CTYPE_TO_BIT(ctype)) != 0;
    }

    public static inline function ONIGENC_IS_ASCII_CODE_WORD(code:Int):Bool {
        return (OnigEncAsciiCtypeTable[code] & CTYPE_TO_BIT(ONIGENC_CTYPE_WORD)) != 0;
    }

    public static inline function ONIGENC_IS_ASCII_CODE_CASE_AMBIG(code:Int):Bool {
        return ONIGENC_IS_ASCII_CODE_CTYPE(code, ONIGENC_CTYPE_UPPER) || ONIGENC_IS_ASCII_CODE_CTYPE(code, ONIGENC_CTYPE_LOWER);
    }

    // ---- utf8.c ----

    static inline function utf8_islead(c:Int):Bool {
        return (c & 0xc0) != 0x80;
    }

    static inline function utf8_istail(c:Int):Bool {
        return (c & 0xc0) == 0x80;
    }

    /** ONIGENC_MBC_ENC_LEN / enclen */
    public static inline function enclen(s:Bytes, p:Int):Int {
        return EncLen_UTF8[s.get(p)];
    }

    /** ONIGENC_IS_MBC_HEAD */
    public static inline function isMbcHead(s:Bytes, p:Int):Bool {
        return EncLen_UTF8[s.get(p)] != 1;
    }

    public static function isValidMbcString(s:Bytes, p:Int, end:Int):Bool {
        while (p < end) {
            if (!utf8_islead(s.get(p)))
                return false;
            var len = enclen(s, p++);
            if (len > 1) {
                for (i in 1...len) {
                    if (p == end)
                        return false;
                    if (!utf8_istail(s.get(p++)))
                        return false;
                }
            }
        }
        return true;
    }

    /** ONIGENC_MBC_TO_CODE */
    public static function mbcToCode(s:Bytes, p:Int, end:Int):Int {
        var len = enclen(s, p);
        if (len > end - p) len = end - p;
        var c = s.get(p++);
        if (len > 1) {
            len--;
            var n = c & ((1 << (6 - len)) - 1);
            while (len-- > 0) {
                c = s.get(p++);
                n = (n << 6) | (c & ((1 << 6) - 1));
            }
            return n;
        }
        else {
            return c;
        }
    }

    /** ONIGENC_CODE_TO_MBCLEN */
    public static function codeToMbclen(code:Int):Int {
        if ((code & 0xffffff80) == 0) return 1;
        else if ((code & 0xfffff800) == 0) return 2;
        else if ((code & 0xffff0000) == 0) return 3;
        else if ((code & 0xffe00000) == 0) return 4;
        else return ONIGERR_INVALID_CODE_POINT_VALUE;
    }

    /** ONIGENC_CODE_TO_MBC: writes into buf at off, returns the byte length or an error. */
    public static function codeToMbc(code:Int, buf:Bytes, off:Int):Int {
        if ((code & 0xffffff80) == 0) {
            buf.set(off, code);
            return 1;
        }
        else {
            var p = off;
            if ((code & 0xfffff800) == 0) {
                buf.set(p++, ((code >> 6) & 0x1f) | 0xc0);
            }
            else if ((code & 0xffff0000) == 0) {
                buf.set(p++, ((code >> 12) & 0x0f) | 0xe0);
                buf.set(p++, ((code >> 6) & 0x3f) | 0x80);
            }
            else if ((code & 0xffe00000) == 0) {
                buf.set(p++, ((code >> 18) & 0x07) | 0xf0);
                buf.set(p++, ((code >> 12) & 0x3f) | 0x80);
                buf.set(p++, ((code >> 6) & 0x3f) | 0x80);
            }
            else {
                return ONIGERR_TOO_BIG_WIDE_CHAR_VALUE;
            }
            buf.set(p++, (code & 0x3f) | 0x80);
            return p - off;
        }
    }

    /**
     * ONIGENC_MBC_CASE_FOLD: folds the character at p into fold (at foldOff),
     * returns the byte length written. The caller advances p by enclen(s, p).
     */
    public static function mbcCaseFold(flag:Int, s:Bytes, p:Int, end:Int, fold:Bytes, foldOff:Int):Int {
        var c = s.get(p);
        if (c < 128) {
            fold.set(foldOff, ONIGENC_ASCII_CODE_TO_LOWER_CASE(c));
            return 1;
        }
        else {
            return Unicode.onigencUnicodeMbcCaseFold(flag, s, p, end, fold, foldOff);
        }
    }

    /** get_ctype_code_range of utf8.c: returns the ranges (sb_out is always 0x80). */
    public static inline var CTYPE_CODE_RANGE_SB_OUT:Int = 0x80;

    /** ONIGENC_LEFT_ADJUST_CHAR_HEAD */
    public static function leftAdjustCharHead(s:Bytes, start:Int, p:Int):Int {
        if (p <= start) return p;
        while (!utf8_islead(s.get(p)) && p > start) p--;
        return p;
    }

    /** ONIGENC_IS_MBC_NEWLINE (onigenc_is_mbc_newline_0x0a) */
    public static inline function isMbcNewline(s:Bytes, p:Int, end:Int):Bool {
        return p < end && s.get(p) == NEWLINE_CODE;
    }

    /** ONIGENC_IS_CODE_NEWLINE */
    public static inline function isCodeNewline(code:Int):Bool {
        return isCodeCtype(code, ONIGENC_CTYPE_NEWLINE);
    }

    /** ONIGENC_IS_CODE_CTYPE */
    public static inline function isCodeCtype(code:Int, ctype:Int):Bool {
        return Unicode.onigencUnicodeIsCodeCtype(code, ctype);
    }

    /** ONIGENC_IS_CODE_WORD */
    public static inline function isCodeWord(code:Int):Bool {
        return Unicode.onigencUnicodeIsCodeCtype(code, ONIGENC_CTYPE_WORD);
    }

    /** ONIGENC_IS_MBC_WORD */
    public static inline function isMbcWord(s:Bytes, p:Int, end:Int):Bool {
        return isCodeWord(mbcToCode(s, p, end));
    }

    /** ONIGENC_IS_MBC_WORD_ASCII (onigenc_is_mbc_word_ascii) */
    public static function isMbcWordAscii(s:Bytes, p:Int, end:Int):Bool {
        var code = mbcToCode(s, p, end);
        if (code > ASCII_LIMIT) return false;
        return ONIGENC_IS_ASCII_CODE_WORD(code);
    }

    /** IS_MBC_WORD_ASCII_MODE of regexec.c */
    public static inline function isMbcWordAsciiMode(s:Bytes, p:Int, end:Int, mode:Int):Bool {
        return mode == 0 ? isMbcWord(s, p, end) : isMbcWordAscii(s, p, end);
    }

    // ---- regenc.c ----

    public static function onigencGetRightAdjustCharHead(s:Bytes, start:Int, p:Int):Int {
        var q = leftAdjustCharHead(s, start, p);
        if (q < p) {
            q += enclen(s, q);
        }
        return q;
    }

    public static function onigencGetPrevCharHead(s:Bytes, start:Int, p:Int):Int {
        if (p <= start)
            return NULL_UCHARP;
        return leftAdjustCharHead(s, start, p - 1);
    }

    public static function onigencStepBack(s:Bytes, start:Int, p:Int, n:Int):Int {
        while (p != NULL_UCHARP && n-- > 0) {
            if (p <= start)
                return NULL_UCHARP;
            p = leftAdjustCharHead(s, start, p - 1);
        }
        return p;
    }

    public static function onigencStep(s:Bytes, p:Int, end:Int, n:Int):Int {
        var q = p;
        while (n-- > 0) {
            q += enclen(s, q);
        }
        return q <= end ? q : NULL_UCHARP;
    }

    public static function onigencStrlen(s:Bytes, p:Int, end:Int):Int {
        var n = 0;
        var q = p;
        while (q < end) {
            q += enclen(s, q);
            n++;
        }
        return n;
    }

    /** onigenc_with_ascii_strncmp */
    public static function onigencWithAsciiStrncmp(s:Bytes, p:Int, end:Int, sascii:String, n:Int):Int {
        var i = 0;
        while (n-- > 0) {
            var a = i < sascii.length ? StringTools.fastCodeAt(sascii, i) : 0;
            if (p >= end) return a;
            var c = mbcToCode(s, p, end);
            var x = a - c;
            if (x != 0) return x;
            i++;
            p += enclen(s, p);
        }
        return 0;
    }

    public static function onigCodesCmp(a:Array<Int>, aOff:Int, b:Array<Int>, bOff:Int, n:Int):Int {
        for (i in 0...n) {
            if (a[aOff + i] != b[bOff + i])
                return -1;
        }
        return 0;
    }

    public static function onigCodesByteAt(codes:Array<Int>, at:Int):Int {
        var index = Std.int(at / 3);
        var b = at % 3;
        var code = codes[index];
        return (code >> ((2 - b) * 8)) & 0xff;
    }

    /** XDIGITVAL of regint.h */
    public static inline function XDIGITVAL(code:Int):Int {
        return (ONIGENC_IS_CODE_ASCII(code) && isCodeCtype(code, ONIGENC_CTYPE_DIGIT)) ? code - '0'.code
            : (isCodeCtype(code, ONIGENC_CTYPE_UPPER) ? code - 'A'.code + 10 : code - 'a'.code + 10);
    }

    public static inline function DIGITVAL(code:Int):Int {
        return code - '0'.code;
    }

    public static inline function IS_CODE_DIGIT_ASCII(code:Int):Bool {
        return ONIGENC_IS_CODE_ASCII(code) && isCodeCtype(code, ONIGENC_CTYPE_DIGIT);
    }

    public static inline function IS_CODE_XDIGIT_ASCII(code:Int):Bool {
        return ONIGENC_IS_CODE_ASCII(code) && isCodeCtype(code, ONIGENC_CTYPE_XDIGIT);
    }

    public static inline function IS_CODE_WORD_ASCII(code:Int):Bool {
        return ONIGENC_IS_CODE_ASCII(code) && isCodeWord(code);
    }

    /** onigenc_minimum_property_name_to_ctype is not used by UTF-8 (it uses the Unicode one). */

}
