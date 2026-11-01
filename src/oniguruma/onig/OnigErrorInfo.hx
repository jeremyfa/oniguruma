// Ported from Oniguruma 6.9.8: src/oniguruma.h (OnigErrorInfo)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;

class OnigErrorInfo {

    /** The pattern `par` and `parEnd` point into (null when not set). */
    public var pattern:Bytes = null;
    public var par:Int = -1;
    public var parEnd:Int = -1;

    public function new() {}

}
