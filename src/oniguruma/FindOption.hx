// Ported from vscode-oniguruma 2.0.1: src/index.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/** Search and compile options (`FindOption` in vscode-oniguruma), same order and values. */
enum abstract FindOption(Int) to Int {
    /** equivalent of ONIG_OPTION_DEFAULT */
    var Default = 0;
    /** equivalent of ONIG_OPTION_NONE */
    var None = 1;
    var Ignorecase = 2;
    var Extend = 3;
    var Multiline = 4;
    var Singleline = 5;
    var FindLongest = 6;
    var FindNotEmpty = 7;
    var NegateSingleline = 8;
    var DontCaptureGroup = 9;
    var CaptureGroup = 10;
    var Notbol = 11;
    var Noteol = 12;
    var CheckValidityOfString = 13;
    var IgnorecaseIsAscii = 14;
    var WordIsAscii = 15;
    var DigitIsAscii = 16;
    var SpaceIsAscii = 17;
    var PosixIsAscii = 18;
    var TextSegmentExtendedGraphemeCluster = 19;
    var TextSegmentWord = 20;
    /** (str) isn't considered as begin of string (* fail \A) */
    var NotBeginString = 21;
    /** (end) isn't considered as end of string (* fail \z, \Z) */
    var NotEndString = 22;
    /** (start) isn't considered as start position of search (* fail \G) */
    var NotBeginPosition = 23;
    var CallbackEachMatch = 24;
    /** used for debugging purposes. */
    var DebugCall = 25;
}
