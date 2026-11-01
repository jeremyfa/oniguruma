// Ported from vscode-oniguruma 2.0.1: src/index.ts (UtfString, OnigString)
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

import haxe.io.Bytes;
import oniguruma.onig.IntArray;

/**
 * A string prepared for matching: the engine works on its UTF-8 encoding,
 * exactly like vscode-oniguruma, and offsets are converted back to UTF-16
 * code units. Reuse one `OnigString` for many searches on the same line.
 */
class OnigString {

    static var LAST_ID = 0;
    static inline var PADDING:Int = 8;

    public final id:Int;
    public final content:String;
    public final utf16Length:Int;
    public final utf8Length:Int;
    /** UTF-8 encoding of `content` (lone surrogates are encoded as 3 byte sequences, like upstream), followed by zero bytes. */
    public final utf8Value:Bytes;
    public final utf16OffsetToUtf8:Null<IntArray>;
    public final utf8OffsetToUtf16:Null<IntArray>;

    public function new(str:String) {
        id = ++LAST_ID;
        content = str;

        var utf16Length = str.length;
        var utf8Length = utf8ByteLength(str);
        var computeIndicesMapping = (utf8Length != utf16Length);
        var utf16OffsetToUtf8:IntArray = computeIndicesMapping ? new IntArray(utf16Length + 1) : null;
        if (computeIndicesMapping) {
            utf16OffsetToUtf8[utf16Length] = utf8Length;
        }
        var utf8OffsetToUtf16:IntArray = computeIndicesMapping ? new IntArray(utf8Length + 1) : null;
        if (computeIndicesMapping) {
            utf8OffsetToUtf16[utf8Length] = utf16Length;
        }
        // a few zero bytes after the string: like the C engine, the search may read
        // the byte at the end position (it is never part of a match)
        var utf8Value = Bytes.alloc(utf8Length + PADDING);
        utf8Value.fill(utf8Length, PADDING, 0);

        var i8 = 0;
        var i16 = 0;
        while (i16 < utf16Length) {
            var charCode = StringTools.fastCodeAt(str, i16);
            var codePoint = charCode;
            var wasSurrogatePair = false;

            if (charCode >= 0xd800 && charCode <= 0xdbff) {
                // Hit a high surrogate, try to look for a matching low surrogate
                if (i16 + 1 < utf16Length) {
                    var nextCharCode = StringTools.fastCodeAt(str, i16 + 1);
                    if (nextCharCode >= 0xdc00 && nextCharCode <= 0xdfff) {
                        // Found the matching low surrogate
                        codePoint = (((charCode - 0xd800) << 10) + 0x10000) | (nextCharCode - 0xdc00);
                        wasSurrogatePair = true;
                    }
                }
            }

            if (computeIndicesMapping) {
                utf16OffsetToUtf8[i16] = i8;
                if (wasSurrogatePair) {
                    utf16OffsetToUtf8[i16 + 1] = i8;
                }
                if (codePoint <= 0x7f) {
                    utf8OffsetToUtf16[i8 + 0] = i16;
                }
                else if (codePoint <= 0x7ff) {
                    utf8OffsetToUtf16[i8 + 0] = i16;
                    utf8OffsetToUtf16[i8 + 1] = i16;
                }
                else if (codePoint <= 0xffff) {
                    utf8OffsetToUtf16[i8 + 0] = i16;
                    utf8OffsetToUtf16[i8 + 1] = i16;
                    utf8OffsetToUtf16[i8 + 2] = i16;
                }
                else {
                    utf8OffsetToUtf16[i8 + 0] = i16;
                    utf8OffsetToUtf16[i8 + 1] = i16;
                    utf8OffsetToUtf16[i8 + 2] = i16;
                    utf8OffsetToUtf16[i8 + 3] = i16;
                }
            }

            if (codePoint <= 0x7f) {
                utf8Value.set(i8++, codePoint);
            }
            else if (codePoint <= 0x7ff) {
                utf8Value.set(i8++, 0xc0 | ((codePoint & 0x7c0) >>> 6));
                utf8Value.set(i8++, 0x80 | (codePoint & 0x3f));
            }
            else if (codePoint <= 0xffff) {
                utf8Value.set(i8++, 0xe0 | ((codePoint & 0xf000) >>> 12));
                utf8Value.set(i8++, 0x80 | ((codePoint & 0xfc0) >>> 6));
                utf8Value.set(i8++, 0x80 | (codePoint & 0x3f));
            }
            else {
                utf8Value.set(i8++, 0xf0 | ((codePoint & 0x1c0000) >>> 18));
                utf8Value.set(i8++, 0x80 | ((codePoint & 0x3f000) >>> 12));
                utf8Value.set(i8++, 0x80 | ((codePoint & 0xfc0) >>> 6));
                utf8Value.set(i8++, 0x80 | (codePoint & 0x3f));
            }

            if (wasSurrogatePair) {
                i16++;
            }
            i16++;
        }

        this.utf16Length = utf16Length;
        this.utf8Length = utf8Length;
        this.utf8Value = utf8Value;
        this.utf16OffsetToUtf8 = utf16OffsetToUtf8;
        this.utf8OffsetToUtf16 = utf8OffsetToUtf16;
    }

    static function utf8ByteLength(str:String):Int {
        var result = 0;
        var len = str.length;
        var i = 0;
        while (i < len) {
            var charCode = StringTools.fastCodeAt(str, i);
            var codepoint = charCode;
            var wasSurrogatePair = false;
            if (charCode >= 0xd800 && charCode <= 0xdbff) {
                if (i + 1 < len) {
                    var nextCharCode = StringTools.fastCodeAt(str, i + 1);
                    if (nextCharCode >= 0xdc00 && nextCharCode <= 0xdfff) {
                        codepoint = (((charCode - 0xd800) << 10) + 0x10000) | (nextCharCode - 0xdc00);
                        wasSurrogatePair = true;
                    }
                }
            }
            if (codepoint <= 0x7f) result += 1;
            else if (codepoint <= 0x7ff) result += 2;
            else if (codepoint <= 0xffff) result += 3;
            else result += 4;
            if (wasSurrogatePair) i++;
            i++;
        }
        return result;
    }

    /**
     * The offsets come from the engine as unsigned 32 bit values (vscode-oniguruma
     * reads them from HEAPU32): an unset group (-1) is 0xffffffff, which maps to
     * `utf16Length` with a mapping, and stays 0xffffffff without one (-1 on
     * targets with 32 bit integers, 4294967295 on JavaScript, like upstream).
     */
    public inline function convertUtf8OffsetToUtf16(utf8Offset:Int):Int {
        if (utf8OffsetToUtf16 != null) {
            if (utf8Offset < 0 || utf8Offset > utf8Length) {
                return utf16Length;
            }
            return utf8OffsetToUtf16[utf8Offset];
        }
        return utf8Offset >>> 0;
    }

    public inline function convertUtf16OffsetToUtf8(utf16Offset:Int):Int {
        if (utf16OffsetToUtf8 != null) {
            if (utf16Offset < 0) {
                return 0;
            }
            if (utf16Offset > utf16Length) {
                return utf8Length;
            }
            return utf16OffsetToUtf8[utf16Offset];
        }
        return utf16Offset;
    }

    /** Nothing to free in Haxe; kept for API compatibility. */
    public function dispose():Void {}

}
