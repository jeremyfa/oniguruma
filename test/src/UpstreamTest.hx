import haxe.io.Bytes;
import oniguruma.*;
import oniguruma.onig.*;

/**
 * The upstream Oniguruma 6.9.8 tests (test/test_utf8.c, test_back.c,
 * test_options.c, test_syntax.c), converted to data (fixtures/upstream-*.json).
 * Each case is checked twice: with the engine API against the expectation
 * of the C test, and through OnigScanner against the result recorded with the
 * real vscode-oniguruma 2.0.1 (field `vs`, forward cases with valid UTF-8).
 */
class UpstreamTest {

    public static function run(name:String, json:String, failures:Array<String>, maxFailures:Int):{passed:Int, failed:Int} {
        var cases:Array<Dynamic> = haxe.Json.parse(json);
        var passed = 0;
        var failed = 0;
        for (c in cases) {
            var p = Bytes.ofHex(c.p);
            var s = Bytes.ofHex(c.s);
            var syntax = syntaxOf(c.syn);
            var err = checkEngine(c, p, s, syntax);
            if (err == null) passed++;
            else {
                failed++;
                if (failures.length < maxFailures)
                    failures.push('$name #${c.line} engine /${p.toString()}/ "${s.toString()}": $err');
            }
            if (c.vs != null) {
                var e2 = checkScanner(c, p, s);
                if (e2 == null) passed++;
                else {
                    failed++;
                    if (failures.length < maxFailures)
                        failures.push('$name #${c.line} scanner /${p.toString()}/ "${s.toString()}": $e2');
                }
            }
        }
        return {passed: passed, failed: failed};
    }

    static function syntaxOf(name:String):OnigSyntaxType {
        return switch (name) {
            case 'PERL': Regsyntax.OnigSyntaxPerl;
            case 'JAVA': Regsyntax.OnigSyntaxJava;
            case 'PYTHON': Regsyntax.OnigSyntaxPython;
            default: Regsyntax.OnigDefaultSyntax;
        }
    }

    static function checkEngine(c:Dynamic, p:Bytes, s:Bytes, syntax:OnigSyntaxType):String {
        var reg = new Regex();
        var einfo = new OnigErrorInfo();
        var r:Int;
        try {
            r = Regex.onigNew(reg, p, 0, p.length, c.opt, syntax, einfo);
        }
        catch (e:Dynamic) {
            return 'CRASH in compile: ' + e;
        }
        var kind:String = c.k;
        if (r != 0) {
            if (kind == 'e' && r == c.err) return null;
            return 'compile error $r (${Regerror.onigErrorCodeToStr(r, einfo)}), expected ' + (kind == 'e' ? 'error ${c.err}' : kind);
        }
        var region = new OnigRegion();
        var data = Bytes.alloc(s.length + 8);
        data.blit(0, s, 0, s.length);
        try {
            if (c.back)
                r = Regexec.onigSearch(reg, data, s.length, s.length, 0, region, c.opt);
            else
                r = Regexec.onigSearch(reg, data, s.length, 0, s.length, region, c.opt);
        }
        catch (e:Dynamic) {
            return 'CRASH in search: ' + e;
        }
        if (r < Onig.ONIG_MISMATCH) {
            if (kind == 'e' && r == c.err) return null;
            return 'search error $r, expected ' + kind;
        }
        if (r == Onig.ONIG_MISMATCH) {
            if (kind == 'n') return null;
            return 'mismatch, expected ' + (kind == 'e' ? 'error ${c.err}' : '${c.f}-${c.t}');
        }
        if (kind == 'n') return 'match ${region.beg[0]}-${region.end[0]}, expected mismatch';
        // like xx() of the C tests: an e() case also passes with a match at 0-0
        var m:Int = kind == 'e' ? 0 : c.m;
        var f:Int = kind == 'e' ? 0 : c.f;
        var t:Int = kind == 'e' ? 0 : c.t;
        if (region.beg[m] == f && region.end[m] == t) return null;
        return 'got ${region.beg[m]}-${region.end[m]} (group $m), expected $f-$t';
    }

    static function checkScanner(c:Dynamic, p:Bytes, s:Bytes):String {
        var opts:Array<FindOption> = [for (o in (c.vsopt:Array<Int>)) cast o];
        var syn:Syntax = switch (c.syn) {
            case 'PERL': Syntax.Perl;
            case 'JAVA': Syntax.Java;
            case 'PYTHON': Syntax.Python;
            default: Syntax.Default;
        }
        var got:Dynamic;
        try {
            var scanner = new OnigScanner([p.toString()], {options: opts, syntax: syn});
            var m = scanner.findNextMatchSync(s.toString(), 0);
            if (m == null) got = 0;
            else {
                var a:Array<Int> = [m.index];
                for (ci in m.captureIndices) {
                    a.push(ci.start);
                    a.push(ci.end);
                }
                got = a;
            }
        }
        catch (e:OnigScanner.OnigError) {
            got = 'error: ' + e.message;
        }
        catch (e:Dynamic) {
            return 'CRASH ' + e;
        }
        var exp:Dynamic = c.vs;
        if (Std.isOfType(exp, String) || Std.isOfType(got, String)) {
            if (Std.isOfType(exp, String) && Std.isOfType(got, String)) {
                // error messages with a pattern part may differ (vscode-oniguruma formats them after freeing the pattern)
                var es:String = exp;
                var gs:String = got;
                if (es == gs || (es.indexOf('<') != -1 && es.substr(0, es.indexOf('<')) == gs.substr(0, gs.indexOf('<')))) return null;
            }
            return 'got ${haxe.Json.stringify(got)}, expected ${haxe.Json.stringify(exp)}';
        }
        if (Std.isOfType(exp, Array) != Std.isOfType(got, Array))
            return 'got ${haxe.Json.stringify(got)}, expected ${haxe.Json.stringify(exp)}';
        if (!Std.isOfType(exp, Array)) return null;
        var x:Array<Dynamic> = exp;
        var y:Array<Dynamic> = got;
        var ok = x.length == y.length;
        if (ok) for (i in 0...x.length) {
            var a:Float = x[i];
            var b:Float = y[i];
            if (a != b && !(isUnset(a) && isUnset(b))) ok = false;
        }
        return ok ? null : 'got ${haxe.Json.stringify(got)}, expected ${haxe.Json.stringify(exp)}';
    }

    static function isUnset(f:Float):Bool {
        return f == -1 || f == 4294967295.0 || f == -2147483648.0;
    }

}
