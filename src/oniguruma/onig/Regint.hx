// Ported from Oniguruma 6.9.8: src/regint.h
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

import haxe.ds.Vector;
import oniguruma.onig.Onig.*;

/** Internal constants and helpers of regint.h (and the option macros of regparse.c). */
class Regint {

    public static inline var DEFAULT_PARSE_DEPTH_LIMIT:Int = 4096;
    public static inline var DEFAULT_MATCH_STACK_LIMIT_SIZE:Int = 0;
    public static inline var DEFAULT_RETRY_LIMIT_IN_MATCH:Int = 10000000;
    public static inline var DEFAULT_RETRY_LIMIT_IN_SEARCH:Int = 0;
    public static inline var DEFAULT_SUBEXP_CALL_LIMIT_IN_SEARCH:Int = 0;
    public static inline var DEFAULT_SUBEXP_CALL_MAX_NEST_LEVEL:Int = 20;

    public static inline var CHAR_MAP_SIZE:Int = 256;
    /** INFINITE_LEN (~0 as OnigLen). Lengths are kept below 2^31 in this port, see README.md. */
    public static inline var INFINITE_LEN:Int = 0x7fffffff;
    public static inline var STEP_BACK_MAX_CHAR_LEN:Int = 65535;
    public static inline var LOOK_BEHIND_MAX_CHAR_LEN:Int = STEP_BACK_MAX_CHAR_LEN;
    public static inline var ONIG_INT_MAX:Int = 0x7fffffff;

    public static inline var INFINITE_REPEAT:Int = -1;

    public static inline var SINGLE_BYTE_SIZE:Int = 256;
    public static inline var BITSET_REAL_SIZE:Int = 8;

    // stack pop level
    public static inline var STACK_POP_LEVEL_FREE:Int = 0;
    public static inline var STACK_POP_LEVEL_MEM_START:Int = 1;
    public static inline var STACK_POP_LEVEL_ALL:Int = 2;

    // optimize flags
    public static inline var OPTIMIZE_NONE:Int = 0;
    public static inline var OPTIMIZE_STR:Int = 1;
    public static inline var OPTIMIZE_STR_FAST:Int = 2;
    public static inline var OPTIMIZE_STR_FAST_STEP_FORWARD:Int = 3;
    public static inline var OPTIMIZE_MAP:Int = 4;

    public static inline var MEM_STATUS_BITS_NUM:Int = 32;

    // anchors
    public static inline var ANCR_PREC_READ:Int = 1 << 0;
    public static inline var ANCR_PREC_READ_NOT:Int = 1 << 1;
    public static inline var ANCR_LOOK_BEHIND:Int = 1 << 2;
    public static inline var ANCR_LOOK_BEHIND_NOT:Int = 1 << 3;
    public static inline var ANCR_BEGIN_BUF:Int = 1 << 4;
    public static inline var ANCR_BEGIN_LINE:Int = 1 << 5;
    public static inline var ANCR_BEGIN_POSITION:Int = 1 << 6;
    public static inline var ANCR_END_BUF:Int = 1 << 7;
    public static inline var ANCR_SEMI_END_BUF:Int = 1 << 8;
    public static inline var ANCR_END_LINE:Int = 1 << 9;
    public static inline var ANCR_WORD_BOUNDARY:Int = 1 << 10;
    public static inline var ANCR_NO_WORD_BOUNDARY:Int = 1 << 11;
    public static inline var ANCR_WORD_BEGIN:Int = 1 << 12;
    public static inline var ANCR_WORD_END:Int = 1 << 13;
    public static inline var ANCR_ANYCHAR_INF:Int = 1 << 14;
    public static inline var ANCR_ANYCHAR_INF_ML:Int = 1 << 15;
    public static inline var ANCR_TEXT_SEGMENT_BOUNDARY:Int = 1 << 16;
    public static inline var ANCR_NO_TEXT_SEGMENT_BOUNDARY:Int = 1 << 17;

    public static inline var ANCR_ANYCHAR_INF_MASK:Int = ANCR_ANYCHAR_INF | ANCR_ANYCHAR_INF_ML;
    public static inline var ANCR_END_BUF_MASK:Int = ANCR_END_BUF | ANCR_SEMI_END_BUF;

    public static inline function ANCHOR_HAS_BODY(type:Int):Bool {
        return type < ANCR_BEGIN_BUF;
    }

    public static inline function IS_WORD_ANCHOR_TYPE(type:Int):Bool {
        return type == ANCR_WORD_BOUNDARY || type == ANCR_NO_WORD_BOUNDARY || type == ANCR_WORD_BEGIN || type == ANCR_WORD_END;
    }

    // opcodes
    public static inline var OP_FINISH:Int = 0;
    public static inline var OP_END:Int = 1;
    public static inline var OP_STR_1:Int = 2;
    public static inline var OP_STR_2:Int = 3;
    public static inline var OP_STR_3:Int = 4;
    public static inline var OP_STR_4:Int = 5;
    public static inline var OP_STR_5:Int = 6;
    public static inline var OP_STR_N:Int = 7;
    public static inline var OP_STR_MB2N1:Int = 8;
    public static inline var OP_STR_MB2N2:Int = 9;
    public static inline var OP_STR_MB2N3:Int = 10;
    public static inline var OP_STR_MB2N:Int = 11;
    public static inline var OP_STR_MB3N:Int = 12;
    public static inline var OP_STR_MBN:Int = 13;
    public static inline var OP_CCLASS:Int = 14;
    public static inline var OP_CCLASS_MB:Int = 15;
    public static inline var OP_CCLASS_MIX:Int = 16;
    public static inline var OP_CCLASS_NOT:Int = 17;
    public static inline var OP_CCLASS_MB_NOT:Int = 18;
    public static inline var OP_CCLASS_MIX_NOT:Int = 19;
    public static inline var OP_ANYCHAR:Int = 20;
    public static inline var OP_ANYCHAR_ML:Int = 21;
    public static inline var OP_ANYCHAR_STAR:Int = 22;
    public static inline var OP_ANYCHAR_ML_STAR:Int = 23;
    public static inline var OP_ANYCHAR_STAR_PEEK_NEXT:Int = 24;
    public static inline var OP_ANYCHAR_ML_STAR_PEEK_NEXT:Int = 25;
    public static inline var OP_WORD:Int = 26;
    public static inline var OP_WORD_ASCII:Int = 27;
    public static inline var OP_NO_WORD:Int = 28;
    public static inline var OP_NO_WORD_ASCII:Int = 29;
    public static inline var OP_WORD_BOUNDARY:Int = 30;
    public static inline var OP_NO_WORD_BOUNDARY:Int = 31;
    public static inline var OP_WORD_BEGIN:Int = 32;
    public static inline var OP_WORD_END:Int = 33;
    public static inline var OP_TEXT_SEGMENT_BOUNDARY:Int = 34;
    public static inline var OP_BEGIN_BUF:Int = 35;
    public static inline var OP_END_BUF:Int = 36;
    public static inline var OP_BEGIN_LINE:Int = 37;
    public static inline var OP_END_LINE:Int = 38;
    public static inline var OP_SEMI_END_BUF:Int = 39;
    public static inline var OP_CHECK_POSITION:Int = 40;
    public static inline var OP_BACKREF1:Int = 41;
    public static inline var OP_BACKREF2:Int = 42;
    public static inline var OP_BACKREF_N:Int = 43;
    public static inline var OP_BACKREF_N_IC:Int = 44;
    public static inline var OP_BACKREF_MULTI:Int = 45;
    public static inline var OP_BACKREF_MULTI_IC:Int = 46;
    public static inline var OP_BACKREF_WITH_LEVEL:Int = 47;
    public static inline var OP_BACKREF_WITH_LEVEL_IC:Int = 48;
    public static inline var OP_BACKREF_CHECK:Int = 49;
    public static inline var OP_BACKREF_CHECK_WITH_LEVEL:Int = 50;
    public static inline var OP_MEM_START:Int = 51;
    public static inline var OP_MEM_START_PUSH:Int = 52;
    public static inline var OP_MEM_END_PUSH:Int = 53;
    public static inline var OP_MEM_END_PUSH_REC:Int = 54;
    public static inline var OP_MEM_END:Int = 55;
    public static inline var OP_MEM_END_REC:Int = 56;
    public static inline var OP_FAIL:Int = 57;
    public static inline var OP_JUMP:Int = 58;
    public static inline var OP_PUSH:Int = 59;
    public static inline var OP_PUSH_SUPER:Int = 60;
    public static inline var OP_POP:Int = 61;
    public static inline var OP_POP_TO_MARK:Int = 62;
    public static inline var OP_PUSH_OR_JUMP_EXACT1:Int = 63;
    public static inline var OP_PUSH_IF_PEEK_NEXT:Int = 64;
    public static inline var OP_REPEAT:Int = 65;
    public static inline var OP_REPEAT_NG:Int = 66;
    public static inline var OP_REPEAT_INC:Int = 67;
    public static inline var OP_REPEAT_INC_NG:Int = 68;
    public static inline var OP_EMPTY_CHECK_START:Int = 69;
    public static inline var OP_EMPTY_CHECK_END:Int = 70;
    public static inline var OP_EMPTY_CHECK_END_MEMST:Int = 71;
    public static inline var OP_EMPTY_CHECK_END_MEMST_PUSH:Int = 72;
    public static inline var OP_MOVE:Int = 73;
    public static inline var OP_STEP_BACK_START:Int = 74;
    public static inline var OP_STEP_BACK_NEXT:Int = 75;
    public static inline var OP_CUT_TO_MARK:Int = 76;
    public static inline var OP_MARK:Int = 77;
    public static inline var OP_SAVE_VAL:Int = 78;
    public static inline var OP_UPDATE_VAR:Int = 79;
    public static inline var OP_CALL:Int = 80;
    public static inline var OP_RETURN:Int = 81;
    public static inline var OP_CALLOUT_CONTENTS:Int = 82;
    public static inline var OP_CALLOUT_NAME:Int = 83;

    // SaveType
    public static inline var SAVE_KEEP:Int = 0;
    public static inline var SAVE_S:Int = 1;
    public static inline var SAVE_RIGHT_RANGE:Int = 2;

    // UpdateVarType
    public static inline var UPDATE_VAR_KEEP_FROM_STACK_LAST:Int = 0;
    public static inline var UPDATE_VAR_S_FROM_STACK:Int = 1;
    public static inline var UPDATE_VAR_RIGHT_RANGE_FROM_STACK:Int = 2;
    public static inline var UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK:Int = 3;
    public static inline var UPDATE_VAR_RIGHT_RANGE_TO_S:Int = 4;
    public static inline var UPDATE_VAR_RIGHT_RANGE_INIT:Int = 5;

    // CheckPositionType
    public static inline var CHECK_POSITION_SEARCH_START:Int = 0;
    public static inline var CHECK_POSITION_CURRENT_RIGHT_RANGE:Int = 1;

    // TextSegmentBoundaryType
    public static inline var EXTENDED_GRAPHEME_CLUSTER_BOUNDARY:Int = 0;
    public static inline var WORD_BOUNDARY:Int = 1;

    // ---- MEM_STATUS ----

    public static inline function MEM_STATUS_AT(stats:Int, n:Int):Bool {
        return n < MEM_STATUS_BITS_NUM ? (stats & (1 << n)) != 0 : (stats & 1) != 0;
    }

    public static inline function MEM_STATUS_AT0(stats:Int, n:Int):Bool {
        return (n > 0 && n < MEM_STATUS_BITS_NUM) ? (stats & (1 << n)) != 0 : (stats & 1) != 0;
    }

    public static inline function MEM_STATUS_IS_ALL_ON(stats:Int):Bool {
        return (stats & 1) != 0;
    }

    public static inline function MEM_STATUS_ON(stats:Int, n:Int):Int {
        if (n < MEM_STATUS_BITS_NUM) {
            if (n != 0)
                stats |= (1 << n);
        }
        else
            stats |= 1;
        return stats;
    }

    public static inline function MEM_STATUS_ON_SIMPLE(stats:Int, n:Int):Int {
        if (n < MEM_STATUS_BITS_NUM)
            stats |= (1 << n);
        return stats;
    }

    public static inline function MEM_STATUS_LIMIT_AT(stats:Int, n:Int):Bool {
        return n < MEM_STATUS_BITS_NUM ? (stats & (1 << n)) != 0 : false;
    }

    public static inline function MEM_STATUS_LIMIT_ON(stats:Int, n:Int):Int {
        if (n < MEM_STATUS_BITS_NUM && n != 0) {
            stats |= (1 << n);
        }
        return stats;
    }

    // ---- bitset ----

    public static inline function newBitSet():Vector<Int> {
        var v = new Vector<Int>(BITSET_REAL_SIZE);
        for (i in 0...BITSET_REAL_SIZE) v[i] = 0;
        return v;
    }

    public static inline function BITSET_AT(bs:Vector<Int>, pos:Int):Bool {
        return (bs[pos >>> 5] & (1 << (pos & 0x1f))) != 0;
    }

    public static inline function BITSET_SET_BIT(bs:Vector<Int>, pos:Int):Void {
        bs[pos >>> 5] |= (1 << (pos & 0x1f));
    }

    public static inline function BITSET_CLEAR_BIT(bs:Vector<Int>, pos:Int):Void {
        bs[pos >>> 5] &= ~(1 << (pos & 0x1f));
    }

    public static inline function BITSET_CLEAR(bs:Vector<Int>):Void {
        for (i in 0...BITSET_REAL_SIZE) bs[i] = 0;
    }

    // ---- options ----

    public static inline function OPTON_FIND_LONGEST(o:Int):Bool return (o & ONIG_OPTION_FIND_LONGEST) != 0;
    public static inline function OPTON_FIND_NOT_EMPTY(o:Int):Bool return (o & ONIG_OPTION_FIND_NOT_EMPTY) != 0;
    public static inline function OPTON_NEGATE_SINGLELINE(o:Int):Bool return (o & ONIG_OPTION_NEGATE_SINGLELINE) != 0;
    public static inline function OPTON_DONT_CAPTURE_GROUP(o:Int):Bool return (o & ONIG_OPTION_DONT_CAPTURE_GROUP) != 0;
    public static inline function OPTON_CAPTURE_GROUP(o:Int):Bool return (o & ONIG_OPTION_CAPTURE_GROUP) != 0;
    public static inline function OPTON_NOTBOL(o:Int):Bool return (o & ONIG_OPTION_NOTBOL) != 0;
    public static inline function OPTON_NOTEOL(o:Int):Bool return (o & ONIG_OPTION_NOTEOL) != 0;
    public static inline function OPTON_POSIX_REGION(o:Int):Bool return (o & ONIG_OPTION_POSIX_REGION) != 0;
    public static inline function OPTON_CHECK_VALIDITY_OF_STRING(o:Int):Bool return (o & ONIG_OPTION_CHECK_VALIDITY_OF_STRING) != 0;
    public static inline function OPTON_NOT_BEGIN_STRING(o:Int):Bool return (o & ONIG_OPTION_NOT_BEGIN_STRING) != 0;
    public static inline function OPTON_NOT_END_STRING(o:Int):Bool return (o & ONIG_OPTION_NOT_END_STRING) != 0;
    public static inline function OPTON_NOT_BEGIN_POSITION(o:Int):Bool return (o & ONIG_OPTION_NOT_BEGIN_POSITION) != 0;
    public static inline function OPTON_CALLBACK_EACH_MATCH(o:Int):Bool return (o & ONIG_OPTION_CALLBACK_EACH_MATCH) != 0;

    public static inline function OPTON_SINGLELINE(o:Int):Bool return (o & ONIG_OPTION_SINGLELINE) != 0;
    public static inline function OPTON_MULTILINE(o:Int):Bool return (o & ONIG_OPTION_MULTILINE) != 0;
    public static inline function OPTON_IGNORECASE(o:Int):Bool return (o & ONIG_OPTION_IGNORECASE) != 0;
    public static inline function OPTON_EXTEND(o:Int):Bool return (o & ONIG_OPTION_EXTEND) != 0;
    public static inline function OPTON_WORD_ASCII(o:Int):Bool return (o & (ONIG_OPTION_WORD_IS_ASCII | ONIG_OPTION_POSIX_IS_ASCII)) != 0;
    public static inline function OPTON_DIGIT_ASCII(o:Int):Bool return (o & (ONIG_OPTION_DIGIT_IS_ASCII | ONIG_OPTION_POSIX_IS_ASCII)) != 0;
    public static inline function OPTON_SPACE_ASCII(o:Int):Bool return (o & (ONIG_OPTION_SPACE_IS_ASCII | ONIG_OPTION_POSIX_IS_ASCII)) != 0;
    public static inline function OPTON_POSIX_ASCII(o:Int):Bool return (o & ONIG_OPTION_POSIX_IS_ASCII) != 0;
    public static inline function OPTON_TEXT_SEGMENT_WORD(o:Int):Bool return (o & ONIG_OPTION_TEXT_SEGMENT_WORD) != 0;

    public static inline function OPTON_IS_ASCII_MODE_CTYPE(ctype:Int, options:Int):Bool {
        return ctype >= 0 && ((ctype < ONIGENC_CTYPE_ASCII && OPTON_POSIX_ASCII(options))
            || (ctype == ONIGENC_CTYPE_WORD && OPTON_WORD_ASCII(options))
            || (ctype == ONIGENC_CTYPE_DIGIT && OPTON_DIGIT_ASCII(options))
            || (ctype == ONIGENC_CTYPE_SPACE && OPTON_SPACE_ASCII(options)));
    }

    public static inline function IS_SYNTAX_OP(syn:OnigSyntaxType, opm:Int):Bool return (syn.op & opm) != 0;
    public static inline function IS_SYNTAX_OP2(syn:OnigSyntaxType, opm:Int):Bool return (syn.op2 & opm) != 0;
    public static inline function IS_SYNTAX_BV(syn:OnigSyntaxType, bvm:Int):Bool return (syn.behavior & bvm) != 0;

    public static inline function IS_MC_ESC_CODE(code:Int, syn:OnigSyntaxType):Bool {
        return code == syn.metaEsc && !IS_SYNTAX_OP2(syn, ONIG_SYN_OP2_INEFFECTIVE_ESCAPE);
    }

}
