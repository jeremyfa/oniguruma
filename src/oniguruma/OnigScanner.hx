// Ported from vscode-oniguruma 2.0.1: src/index.ts (OnigScanner) and src/onig.cc
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

import haxe.io.Bytes;
import oniguruma.onig.OnigErrorInfo;
import oniguruma.onig.OnigRegion;
import oniguruma.onig.OnigRegSet;
import oniguruma.onig.OnigSyntaxType;
import oniguruma.onig.Regex;
import oniguruma.onig.Regerror;
import oniguruma.onig.Regexec;
import oniguruma.onig.Regsyntax;
import oniguruma.onig.Onig;

/** Thrown when a pattern does not compile (the message is Oniguruma's error message). */
class OnigError extends haxe.Exception {}

/** `OnigRegExp` of onig.cc: a compiled pattern with its search cache. */
private class OnigRegExp {

    public var regex:Regex;
    public var region:OnigRegion;
    public var hasGAnchor:Bool;
    public var lastSearchStrCacheId:Int = 0;
    public var lastSearchPosition:Int = 0;
    public var lastSearchOnigOption:Int = Onig.ONIG_OPTION_NONE;
    public var lastSearchMatched:Bool = false;

    public function new(regex:Regex, data:Bytes, length:Int) {
        this.regex = regex;
        this.region = new OnigRegion();
        this.hasGAnchor = computeHasGAnchor(data, length);
    }

    static function computeHasGAnchor(str:Bytes, len:Int):Bool {
        for (pos in 0...len) {
            if (str.get(pos) == '\\'.code && pos + 1 < len) {
                if (str.get(pos + 1) == 'G'.code) {
                    return true;
                }
            }
        }
        return false;
    }

    function searchUncached(strData:Bytes, strLength:Int, position:Int, onigOption:Int):OnigRegion {
        var status = Regexec.onigSearch(regex, strData, strLength, position, strLength, region, onigOption);
        if (status == Onig.ONIG_MISMATCH || status < 0) {
            lastSearchMatched = false;
            return null;
        }
        lastSearchMatched = true;
        return region;
    }

    public function search(strCacheId:Int, strData:Bytes, strLength:Int, position:Int, onigOption:Int):OnigRegion {
        if (hasGAnchor) {
            // Should not use caching, because the regular expression
            // targets the current search position (\G)
            return searchUncached(strData, strLength, position, onigOption);
        }
        if (lastSearchStrCacheId == strCacheId && lastSearchOnigOption == onigOption && lastSearchPosition <= position) {
            if (!lastSearchMatched) {
                // last time there was no match
                return null;
            }
            if (region.beg[0] >= position) {
                // last time there was a match and it occured after position
                return region;
            }
        }
        lastSearchStrCacheId = strCacheId;
        lastSearchPosition = position;
        lastSearchOnigOption = onigOption;
        return searchUncached(strData, strLength, position, onigOption);
    }

}

/**
 * Searches several patterns at once and returns the leftmost match
 * (the first pattern wins on ties), like vscode-oniguruma's `OnigScanner`.
 */
class OnigScanner {

    @:allow(oniguruma.OnigLib)
    static var defaultDebugCall = false;

    final rset:OnigRegSet;
    final regexes:Array<OnigRegExp>;
    final count:Int;
    final options:Array<FindOption>;
    final optionBits:Int;

    public function new(patterns:Array<String>, ?config:OnigScannerConfig) {
        this.options = (config != null && config.options != null) ? config.options : [FindOption.CaptureGroup];
        var opts = onigOptions(this.options);
        this.optionBits = opts;
        var syntax = onigSyntax((config != null && config.syntax != null) ? config.syntax : Syntax.Default);

        // createOnigScanner of onig.cc
        count = patterns.length;
        regexes = [];
        var regs:Array<Regex> = [];
        for (i in 0...count) {
            var ps = new OnigString(patterns[i]);
            var data = ps.utf8Value;
            var einfo = new OnigErrorInfo();
            var reg = new Regex();
            var status = Regex.onigNew(reg, data, 0, ps.utf8Length, opts, syntax, einfo);
            if (status != Onig.ONIG_NORMAL) {
                throw new OnigError(Regerror.onigErrorCodeToStr(status, einfo));
            }
            regexes.push(new OnigRegExp(reg, data, ps.utf8Length));
            regs.push(reg);
        }
        rset = OnigRegSet.onigRegsetNew(regs);
    }

    public function dispose():Void {}

    /**
     * `findNextMatchSync(string, startPosition, options)`: `string` is a
     * `String` or an `OnigString` (prefer the latter when searching a line many
     * times), positions are UTF-16 code units.
     */
    public function findNextMatchSync(string:OnigScannerInput, startPosition:Int, ?options:Array<FindOption>):Null<OnigMatch> {
        var opts = optionBits;
        if (options != null) {
            opts |= onigOptions(options);
        }
        return _findNextMatchSync(string, startPosition, opts);
    }

    function _findNextMatchSync(string:OnigString, startPosition:Int, opts:Int):Null<OnigMatch> {
        var strData = string.utf8Value;
        var strLength = string.utf8Length;
        var position = string.convertUtf16OffsetToUtf8(startPosition);

        // findNextOnigScannerMatch of onig.cc
        var bestResultIndex = 0;
        var bestResult:OnigRegion = null;
        if (strLength < 1000) {
            // for short strings, it is better to use the RegSet API, but for longer strings caching pays off
            bestResultIndex = rset.search(strData, strLength, position, strLength, OnigRegSet.ONIG_REGSET_POSITION_LEAD, opts);
            if (bestResultIndex < 0) {
                return null;
            }
            bestResult = rset.getRegion(bestResultIndex);
        }
        else {
            var bestLocation = 0;
            for (i in 0...count) {
                var result = regexes[i].search(string.id, strData, strLength, position, opts);
                if (result != null && result.numRegs > 0) {
                    var location = result.beg[0];
                    if (bestResult == null || location < bestLocation) {
                        bestLocation = location;
                        bestResult = result;
                        bestResultIndex = i;
                    }
                    if (location == position) {
                        break;
                    }
                }
            }
            if (bestResult == null) {
                return null;
            }
        }

        // encodeOnigRegion + decoding in index.ts
        if (bestResult.numRegs > 1000) {
            return null;
        }
        var num = bestResult.numRegs;
        var captureIndices = new Array<OnigCaptureIndex>();
        captureIndices.resize(num);
        for (i in 0...num) {
            var beg = string.convertUtf8OffsetToUtf16(bestResult.beg[i]);
            var end = string.convertUtf8OffsetToUtf16(bestResult.end[i]);
            captureIndices[i] = new OnigCaptureIndex(beg, end, end - beg);
        }
        return new OnigMatch(bestResultIndex, captureIndices);
    }

    static function onigOptions(options:Array<FindOption>):Int {
        var acc = Onig.ONIG_OPTION_NONE;
        for (o in options) {
            acc |= onigOption(o);
        }
        return acc;
    }

    static function onigSyntax(syntax:Syntax):OnigSyntaxType {
        return switch syntax {
            case Default: Regsyntax.OnigDefaultSyntax;
            case Asis: Regsyntax.OnigSyntaxASIS;
            case PosixBasic: Regsyntax.OnigSyntaxPosixBasic;
            case PosixExtended: Regsyntax.OnigSyntaxPosixExtended;
            case Emacs: Regsyntax.OnigSyntaxEmacs;
            case Grep: Regsyntax.OnigSyntaxGrep;
            case GnuRegex: Regsyntax.OnigSyntaxGnuRegex;
            case Java: Regsyntax.OnigSyntaxJava;
            case Perl: Regsyntax.OnigSyntaxPerl;
            case PerlNg: Regsyntax.OnigSyntaxPerl_NG;
            case Ruby: Regsyntax.OnigSyntaxRuby;
            case Python: Regsyntax.OnigSyntaxPython;
            case Oniguruma: Regsyntax.OnigSyntaxOniguruma;
        }
    }

    static function onigOption(option:FindOption):Int {
        return switch option {
            case None: Onig.ONIG_OPTION_NONE;
            case Default: Onig.ONIG_OPTION_DEFAULT;
            case Ignorecase: Onig.ONIG_OPTION_IGNORECASE;
            case Extend: Onig.ONIG_OPTION_EXTEND;
            case Multiline: Onig.ONIG_OPTION_MULTILINE;
            case Singleline: Onig.ONIG_OPTION_SINGLELINE;
            case FindLongest: Onig.ONIG_OPTION_FIND_LONGEST;
            case FindNotEmpty: Onig.ONIG_OPTION_FIND_NOT_EMPTY;
            case NegateSingleline: Onig.ONIG_OPTION_NEGATE_SINGLELINE;
            case DontCaptureGroup: Onig.ONIG_OPTION_DONT_CAPTURE_GROUP;
            case CaptureGroup: Onig.ONIG_OPTION_CAPTURE_GROUP;
            case Notbol: Onig.ONIG_OPTION_NOTBOL;
            case Noteol: Onig.ONIG_OPTION_NOTEOL;
            case CheckValidityOfString: Onig.ONIG_OPTION_CHECK_VALIDITY_OF_STRING;
            case IgnorecaseIsAscii: Onig.ONIG_OPTION_IGNORECASE_IS_ASCII;
            case WordIsAscii: Onig.ONIG_OPTION_WORD_IS_ASCII;
            case DigitIsAscii: Onig.ONIG_OPTION_DIGIT_IS_ASCII;
            case SpaceIsAscii: Onig.ONIG_OPTION_SPACE_IS_ASCII;
            case PosixIsAscii: Onig.ONIG_OPTION_POSIX_IS_ASCII;
            case TextSegmentExtendedGraphemeCluster: Onig.ONIG_OPTION_TEXT_SEGMENT_EXTENDED_GRAPHEME_CLUSTER;
            case TextSegmentWord: Onig.ONIG_OPTION_TEXT_SEGMENT_WORD;
            case NotBeginString: Onig.ONIG_OPTION_NOT_BEGIN_STRING;
            case NotEndString: Onig.ONIG_OPTION_NOT_END_STRING;
            case NotBeginPosition: Onig.ONIG_OPTION_NOT_BEGIN_POSITION;
            case CallbackEachMatch: Onig.ONIG_OPTION_CALLBACK_EACH_MATCH;
            case DebugCall: Onig.ONIG_OPTION_DEFAULT;
        }
    }

}
