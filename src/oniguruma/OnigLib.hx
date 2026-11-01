// Ported from vscode-oniguruma 2.0.1: src/index.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package oniguruma;

/**
 * The engine in the shape of vscode-textmate's `IOnigLib`
 * (`createOnigScanner` / `createOnigString`), with vscode-oniguruma's
 * module functions as statics.
 */
class OnigLib {

    public function new() {}

    public function createOnigScanner(patterns:Array<String>):OnigScanner {
        return new OnigScanner(patterns);
    }

    public function createOnigString(str:String):OnigString {
        return new OnigString(str);
    }

    /** `createOnigScanner` module function of vscode-oniguruma. */
    public static function createScanner(patterns:Array<String>):OnigScanner {
        return new OnigScanner(patterns);
    }

    /** `createOnigString` module function of vscode-oniguruma. */
    public static function createString(str:String):OnigString {
        return new OnigString(str);
    }

    /** `setDefaultDebugCall` of vscode-oniguruma. */
    public static function setDefaultDebugCall(defaultDebugCall:Bool):Void {
        OnigScanner.defaultDebugCall = defaultDebugCall;
    }

}
