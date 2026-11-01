/**
 * Test runner of the Oniguruma port.
 *
 * Usage: node bin/test.js <fixtures dir> [filter]
 *        bin/cpp/Main <fixtures dir> [filter]
 */
import Fixtures.Out;

class Main {

    static function main() {
        var args = Fixtures.args();
        Fixtures.dir = args.length > 0 ? args[0] : 'fixtures';
        var filter = args.length > 1 ? args[1] : null;
        CorpusTest.debug = args.length > 2 && args[2] == 'debug';
        var failures:Array<String> = [];
        var totalPassed = 0;
        var totalFailed = 0;
        var start = haxe.Timer.stamp();

        function report(name:String, passed:Int, failed:Int) {
            totalPassed += passed;
            totalFailed += failed;
            Out.println('$name: $passed passed, $failed failed');
        }

        if (filter == null || 'vscode-oniguruma'.indexOf(filter) != -1) {
            var r = VscodeOnigurumaTest.run(failures);
            report('vscode-oniguruma', r.passed, r.failed);
        }

        for (file in Fixtures.list()) {
            if (!StringTools.startsWith(file, 'corpus-') || file == 'corpus-timing.json') continue;
            if (filter != null && file.indexOf(filter) == -1) continue;
            var r = CorpusTest.run(file, Fixtures.read(file), failures, 200);
            report(file, r.passed, r.failed);
        }

        for (file in Fixtures.list()) {
            if (!StringTools.startsWith(file, 'upstream-')) continue;
            if (filter != null && file.indexOf(filter) == -1) continue;
            var r = UpstreamTest.run(file, Fixtures.read(file), failures, 200);
            report(file, r.passed, r.failed);
        }

        for (f in failures) Out.println('FAIL ' + f);
        Out.println('TOTAL: $totalPassed passed, $totalFailed failed (' + Std.int((haxe.Timer.stamp() - start) * 1000) + ' ms)');
        if (CorpusTest.totalCalls > 0) {
            Out.println('corpus: ' + CorpusTest.totalCalls + ' findNextMatchSync calls in ' + Std.int(CorpusTest.totalTime * 1000) + ' ms, '
                + (Math.round(CorpusTest.totalTime * 1e9 / CorpusTest.totalCalls) / 1000) + ' us per call');
        }
        #if sys
        Sys.exit(totalFailed == 0 ? 0 : 1);
        #else
        js.Syntax.code("process.exitCode = {0}", totalFailed == 0 ? 0 : 1);
        #end
    }

}
