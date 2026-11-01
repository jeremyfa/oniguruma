import oniguruma.OnigScanner;
import oniguruma.OnigString;
import Fixtures.Out;

/**
 * Benchmark: compiles every scanner of the corpus, then replays all the
 * findNextMatchSync calls of the corpus (same calls as bench-wasm.mjs runs
 * with the real vscode-oniguruma).
 * Usage: node bin/bench.js fixtures [rounds]
 */
class Bench {

    static var keep:Dynamic;

    /** heap in use after a full collection (node needs --expose-gc) */
    static function memory():String {
        #if js
        js.Syntax.code("if (global.gc) { global.gc(); global.gc(); }");
        var u:Float = js.Syntax.code("process.memoryUsage().heapUsed");
        var ab:Float = js.Syntax.code("process.memoryUsage().arrayBuffers");
        var rss:Float = js.Syntax.code("process.memoryUsage().rss");
        return Std.int(u / 1048576) + ' MB heap, ' + Std.int(ab / 1048576) + ' MB array buffers, ' + Std.int(rss / 1048576) + ' MB rss';
        #elseif cpp
        cpp.vm.Gc.run(true);
        cpp.vm.Gc.run(true);
        var u = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
        return Std.int(u / 1048576) + ' MB in use';
        #else
        return '?';
        #end
    }

    static function main() {
        var args = Fixtures.args();
        Fixtures.dir = args.length > 0 ? args[0] : 'fixtures';
        var rounds = args.length > 1 ? Std.parseInt(args[1]) : 3;
        var sets = [];
        var compileTime = 0.0;
        var numScanners = 0;
        for (file in Fixtures.list()) {
            if (!StringTools.startsWith(file, 'corpus-') || file == 'corpus-timing.json') continue;
            var data:Dynamic = haxe.Json.parse(Fixtures.read(file));
            var lines:Array<String> = data.lines;
            var regexes:Array<String> = data.regexes;
            var entries:Array<Dynamic> = data.entries;
            var strings = [for (l in lines) new OnigString(l)];
            for (entry in entries) {
                if (entry.err != null) continue;
                var pats = [for (i in (entry.p:Array<Int>)) regexes[i]];
                var t0 = haxe.Timer.stamp();
                var scanner = new OnigScanner(pats);
                compileTime += haxe.Timer.stamp() - t0;
                numScanners++;
                var res:Array<Array<Dynamic>> = entry.r;
                var calls = new Array<Int>();
                for (rec in res) {
                    calls.push(rec[0]);
                    calls.push(rec[1]);
                }
                sets.push({scanner: scanner, strings: strings, calls: calls});
            }
        }
        Out.println('memory after compile: ' + memory());
        var numCalls = 0;
        for (s in sets) numCalls += Std.int(s.calls.length / 2);
        Out.println('scanners: $numScanners, compile: ' + Std.int(compileTime * 1000) + ' ms (' + Math.round(compileTime * 1e6 / numScanners) + ' us per scanner)');
        for (r in 0...rounds) {
            var t0 = haxe.Timer.stamp();
            for (s in sets) {
                var calls = s.calls;
                var i = 0;
                while (i < calls.length) {
                    s.scanner.findNextMatchSync(s.strings[calls[i]], calls[i + 1]);
                    i += 2;
                }
            }
            var t = haxe.Timer.stamp() - t0;
            Out.println('round $r: $numCalls calls in ' + Std.int(t * 1000) + ' ms, ' + (Math.round(t * 1e9 / numCalls) / 1000) + ' us per call');
        }
        Out.println('memory after searches: ' + memory());
        keep = sets;
    }

}
