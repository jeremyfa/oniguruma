// Ported from Oniguruma 6.9.8: src/regerror.c
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import oniguruma.onig.Onig.*;

class Regerror {

    static inline var MAX_ERROR_PAR_LEN:Int = 30;

    public static function onigErrorCodeToFormat(code:Int):String {
        return switch (code) {
            case ONIG_MISMATCH: "mismatch";
            case ONIG_NO_SUPPORT_CONFIG: "no support in this configuration";
            case ONIG_ABORT: "abort";
            case ONIGERR_MEMORY: "fail to memory allocation";
            case ONIGERR_MATCH_STACK_LIMIT_OVER: "match-stack limit over";
            case ONIGERR_PARSE_DEPTH_LIMIT_OVER: "parse depth limit over";
            case ONIGERR_RETRY_LIMIT_IN_MATCH_OVER: "retry-limit-in-match over";
            case ONIGERR_RETRY_LIMIT_IN_SEARCH_OVER: "retry-limit-in-search over";
            case ONIGERR_SUBEXP_CALL_LIMIT_IN_SEARCH_OVER: "subexp-call-limit-in-search over";
            case ONIGERR_TYPE_BUG: "undefined type (bug)";
            case ONIGERR_PARSER_BUG: "internal parser error (bug)";
            case ONIGERR_STACK_BUG: "stack error (bug)";
            case ONIGERR_UNDEFINED_BYTECODE: "undefined bytecode (bug)";
            case ONIGERR_UNEXPECTED_BYTECODE: "unexpected bytecode (bug)";
            case ONIGERR_DEFAULT_ENCODING_IS_NOT_SET: "default multibyte-encoding is not set";
            case ONIGERR_SPECIFIED_ENCODING_CANT_CONVERT_TO_WIDE_CHAR: "can't convert to wide-char on specified multibyte-encoding";
            case ONIGERR_FAIL_TO_INITIALIZE: "fail to initialize";
            case ONIGERR_INVALID_ARGUMENT: "invalid argument";
            case ONIGERR_END_PATTERN_AT_LEFT_BRACE: "end pattern at left brace";
            case ONIGERR_END_PATTERN_AT_LEFT_BRACKET: "end pattern at left bracket";
            case ONIGERR_EMPTY_CHAR_CLASS: "empty char-class";
            case ONIGERR_PREMATURE_END_OF_CHAR_CLASS: "premature end of char-class";
            case ONIGERR_END_PATTERN_AT_ESCAPE: "end pattern at escape";
            case ONIGERR_END_PATTERN_AT_META: "end pattern at meta";
            case ONIGERR_END_PATTERN_AT_CONTROL: "end pattern at control";
            case ONIGERR_META_CODE_SYNTAX: "invalid meta-code syntax";
            case ONIGERR_CONTROL_CODE_SYNTAX: "invalid control-code syntax";
            case ONIGERR_CHAR_CLASS_VALUE_AT_END_OF_RANGE: "char-class value at end of range";
            case ONIGERR_CHAR_CLASS_VALUE_AT_START_OF_RANGE: "char-class value at start of range";
            case ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS: "unmatched range specifier in char-class";
            case ONIGERR_TARGET_OF_REPEAT_OPERATOR_NOT_SPECIFIED: "target of repeat operator is not specified";
            case ONIGERR_TARGET_OF_REPEAT_OPERATOR_INVALID: "target of repeat operator is invalid";
            case ONIGERR_NESTED_REPEAT_OPERATOR: "nested repeat operator";
            case ONIGERR_UNMATCHED_CLOSE_PARENTHESIS: "unmatched close parenthesis";
            case ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS: "end pattern with unmatched parenthesis";
            case ONIGERR_END_PATTERN_IN_GROUP: "end pattern in group";
            case ONIGERR_UNDEFINED_GROUP_OPTION: "undefined group option";
            case ONIGERR_INVALID_GROUP_OPTION: "invalid group option";
            case ONIGERR_INVALID_POSIX_BRACKET_TYPE: "invalid POSIX bracket type";
            case ONIGERR_INVALID_LOOK_BEHIND_PATTERN: "invalid pattern in look-behind";
            case ONIGERR_INVALID_REPEAT_RANGE_PATTERN: "invalid repeat range {lower,upper}";
            case ONIGERR_TOO_BIG_NUMBER: "too big number";
            case ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE: "too big number for repeat range";
            case ONIGERR_UPPER_SMALLER_THAN_LOWER_IN_REPEAT_RANGE: "upper is smaller than lower in repeat range";
            case ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS: "empty range in char class";
            case ONIGERR_MISMATCH_CODE_LENGTH_IN_CLASS_RANGE: "mismatch multibyte code length in char-class range";
            case ONIGERR_TOO_MANY_MULTI_BYTE_RANGES: "too many multibyte code ranges are specified";
            case ONIGERR_TOO_SHORT_MULTI_BYTE_STRING: "too short multibyte code string";
            case ONIGERR_TOO_BIG_BACKREF_NUMBER: "too big backref number";
            case ONIGERR_INVALID_BACKREF: "invalid backref number/name";
            case ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED: "numbered backref/call is not allowed. (use name)";
            case ONIGERR_TOO_MANY_CAPTURES: "too many captures";
            case ONIGERR_TOO_BIG_WIDE_CHAR_VALUE: "too big wide-char value";
            case ONIGERR_TOO_LONG_WIDE_CHAR_VALUE: "too long wide-char value";
            case ONIGERR_UNDEFINED_OPERATOR: "undefined operator";
            case ONIGERR_INVALID_CODE_POINT_VALUE: "invalid code point value";
            case ONIGERR_EMPTY_GROUP_NAME: "group name is empty";
            case ONIGERR_INVALID_GROUP_NAME: "invalid group name <%n>";
            case ONIGERR_INVALID_CHAR_IN_GROUP_NAME: "invalid char in group name <%n>";
            case ONIGERR_UNDEFINED_NAME_REFERENCE: "undefined name <%n> reference";
            case ONIGERR_UNDEFINED_GROUP_REFERENCE: "undefined group <%n> reference";
            case ONIGERR_MULTIPLEX_DEFINED_NAME: "multiplex defined name <%n>";
            case ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL: "multiplex definition name <%n> call";
            case ONIGERR_NEVER_ENDING_RECURSION: "never ending recursion";
            case ONIGERR_GROUP_NUMBER_OVER_FOR_CAPTURE_HISTORY: "group number is too big for capture history";
            case ONIGERR_INVALID_CHAR_PROPERTY_NAME: "invalid character property name {%n}";
            case ONIGERR_INVALID_IF_ELSE_SYNTAX: "invalid if-else syntax";
            case ONIGERR_INVALID_ABSENT_GROUP_PATTERN: "invalid absent group pattern";
            case ONIGERR_INVALID_ABSENT_GROUP_GENERATOR_PATTERN: "invalid absent group generator pattern";
            case ONIGERR_INVALID_CALLOUT_PATTERN: "invalid callout pattern";
            case ONIGERR_INVALID_CALLOUT_NAME: "invalid callout name";
            case ONIGERR_UNDEFINED_CALLOUT_NAME: "undefined callout name";
            case ONIGERR_INVALID_CALLOUT_BODY: "invalid callout body";
            case ONIGERR_INVALID_CALLOUT_TAG_NAME: "invalid callout tag name";
            case ONIGERR_INVALID_CALLOUT_ARG: "invalid callout arg";
            case ONIGERR_NOT_SUPPORTED_ENCODING_COMBINATION: "not supported encoding combination";
            case ONIGERR_INVALID_COMBINATION_OF_OPTIONS: "invalid combination of options";
            case ONIGERR_VERY_INEFFICIENT_PATTERN: "very inefficient pattern";
            case ONIGERR_LIBRARY_IS_NOT_INITIALIZED: "library is not initialized";
            default: "undefined error code";
        }
    }

    public static function onigIsErrorCodeNeedsParam(code:Int):Bool {
        switch (code) {
            case ONIGERR_UNDEFINED_NAME_REFERENCE, ONIGERR_UNDEFINED_GROUP_REFERENCE, ONIGERR_MULTIPLEX_DEFINED_NAME,
                ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL, ONIGERR_INVALID_GROUP_NAME, ONIGERR_INVALID_CHAR_IN_GROUP_NAME,
                ONIGERR_INVALID_CHAR_PROPERTY_NAME:
                return true;
            default:
                return false;
        }
    }

    /** onig_error_code_to_str */
    public static function onigErrorCodeToStr(code:Int, einfo:OnigErrorInfo):String {
        if (onigIsErrorCodeNeedsParam(code) && einfo != null) {
            // to_ascii (UTF-8: bytes are copied as is)
            var bufSize = MAX_ERROR_PAR_LEN - 3;
            var len = 0;
            var isOver = false;
            var par:Bytes = null;
            if (einfo.pattern != null && einfo.par >= 0) {
                var n = einfo.parEnd - einfo.par;
                len = n < bufSize ? n : bufSize;
                isOver = bufSize < n;
                par = einfo.pattern.sub(einfo.par, len);
            }
            var q = onigErrorCodeToFormat(code);
            var out = new BytesBuffer();
            var i = 0;
            while (i < q.length) {
                var c = StringTools.fastCodeAt(q, i);
                if (c == '%'.code && i + 1 < q.length && StringTools.fastCodeAt(q, i + 1) == 'n'.code) {
                    if (par != null) out.add(par);
                    if (isOver) out.addString("...");
                    i += 2;
                }
                else {
                    out.addByte(c);
                    i++;
                }
            }
            return out.getBytes().toString();
        }
        return onigErrorCodeToFormat(code);
    }

}
