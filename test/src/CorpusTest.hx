import oniguruma.OnigScanner;
import oniguruma.OnigString;
import oniguruma.OnigMatch;

/**
 * Replays the differential corpus recorded with the real vscode-oniguruma
 * 2.0.1 (see fixtures/README.md): regexes of TextMate grammars scanned over
 * sample lines, with the exact match index and capture offsets.
 */
class CorpusTest {

    public static var debug = false;
    public static var totalCalls = 0;
    public static var totalTime = 0.0;

    public static function run(name:String, json:String, failures:Array<String>, maxFailures:Int):{passed:Int, failed:Int} {
        var data:Dynamic = haxe.Json.parse(json);
        var lines:Array<String> = data.lines;
        var strings = [for (l in lines) new OnigString(l)];
        var regexes:Array<String> = data.regexes;
        var entries:Array<Dynamic> = data.entries;
        var passed = 0;
        var failed = 0;
        for (entry in entries) {
            var pats:Array<String> = [for (i in (entry.p:Array<Int>)) regexes[i]];
            var scanner:OnigScanner = null;
            var err:String = null;
            if (debug) Fixtures.Out.println('compile ' + haxe.Json.stringify(pats));
            try {
                scanner = new OnigScanner(pats);
            }
            catch (e:Dynamic) {
                err = Std.string(e);
            }
            if (entry.err != null || err != null) {
                if (entry.err != null && err != null) passed++;
                else {
                    failed++;
                    if (failures.length < maxFailures)
                        failures.push('$name compile ${haxe.Json.stringify(pats)}: expected ${entry.err == null ? "ok" : "error " + entry.err}, got ${err == null ? "ok" : "error " + err}');
                }
                continue;
            }
            var res:Array<Array<Dynamic>> = entry.r;
            for (rec in res) {
                var li:Int = rec[0];
                var pos:Int = rec[1];
                if (debug) Fixtures.Out.println('  scan ' + li + ' ' + pos);
                var t0 = haxe.Timer.stamp();
                var m:OnigMatch = null;
                var crash:String = null;
                try {
                    m = scanner.findNextMatchSync(strings[li], pos);
                }
                catch (e:Dynamic) {
                    crash = Std.string(e);
                }
                totalTime += haxe.Timer.stamp() - t0;
                totalCalls++;
                var got = encode(m);
                var exp = rec[2];
                if (crash == null && same(got, exp)) passed++;
                else {
                    failed++;
                    if (failures.length < maxFailures)
                        failures.push('$name ${haxe.Json.stringify(pats)} on ${haxe.Json.stringify(lines[li])} at $pos: expected ${haxe.Json.stringify(exp)}, got ${crash != null ? "CRASH " + crash : haxe.Json.stringify(got)}');
                }
            }
        }
        return {passed: passed, failed: failed};
    }

    static function encode(m:OnigMatch):Dynamic {
        if (m == null) return 0;
        var a:Array<Int> = [m.index];
        for (c in m.captureIndices) {
            a.push(c.start);
            a.push(c.end);
        }
        return a;
    }

    static function isUnset(v:Dynamic):Bool {
        var f:Float = v;
        return f == -1 || f == 4294967295.0 || f == -2147483648.0; // haxe.Json on hxcpp clamps 4294967295
    }

    static function same(a:Dynamic, b:Dynamic):Bool {
        if (Std.isOfType(a, Array) != Std.isOfType(b, Array)) return false;
        if (!Std.isOfType(a, Array)) return a == b;
        var x:Array<Int> = a;
        var y:Array<Int> = b;
        if (x.length != y.length) return false;
        for (i in 0...x.length) if ((x[i] : Float) != (y[i] : Float) && !(isUnset(x[i]) && isUnset(y[i]))) return false;
        return true;
    }

}
