import oniguruma.*;

/** The tests of vscode-oniguruma 2.0.1 (src/test/index.test.ts), translated. */
class VscodeOnigurumaTest {

    static var passed = 0;
    static var failed = 0;
    static var failures:Array<String>;
    static var current = '';

    static function m(index:Int, caps:Array<Array<Int>>):String {
        return new OnigMatch(index, [for (c in caps) new OnigCaptureIndex(c[0], c[1], c[1] - c[0])]).toString();
    }

    static function eq(got:Null<OnigMatch>, expected:Null<String>) {
        var g = got == null ? 'null' : got.toString();
        var e = expected == null ? 'null' : expected;
        if (g == e) passed++;
        else {
            failed++;
            failures.push('vscode-oniguruma $current: expected $e, got $g');
        }
    }

    public static function run(f:Array<String>):{passed:Int, failed:Int} {
        failures = f;

        current = 'simple1';
        var scanner = new OnigScanner(['ell', 'wo']);
        var s = new OnigString('Hello world!');
        eq(scanner.findNextMatchSync(s, 0), m(0, [[1, 4]]));
        eq(scanner.findNextMatchSync(s, 2), m(1, [[6, 8]]));

        current = 'simple2';
        scanner = new OnigScanner(['a', 'b', 'c']);
        eq(scanner.findNextMatchSync('x', 0), null);
        eq(scanner.findNextMatchSync('xxaxxbxxc', 0), m(0, [[2, 3]]));
        eq(scanner.findNextMatchSync('xxaxxbxxc', 4), m(1, [[5, 6]]));
        eq(scanner.findNextMatchSync('xxaxxbxxc', 7), m(2, [[8, 9]]));
        eq(scanner.findNextMatchSync('xxaxxbxxc', 9), null);

        current = 'unicode1';
        var scanner1 = new OnigScanner(['1', '2']);
        eq(scanner1.findNextMatchSync('ab…cde21', 5), m(1, [[6, 7]]));
        var scanner2 = new OnigScanner(['"']);
        eq(scanner2.findNextMatchSync('{"…": 1}', 1), m(0, [[1, 2]]));

        current = 'unicode2';
        scanner = new OnigScanner(['Y', 'X']);
        eq(scanner.findNextMatchSync('a💻bYX', 0), m(0, [[4, 5]]));
        eq(scanner.findNextMatchSync('a💻bYX', 1), m(0, [[4, 5]]));
        eq(scanner.findNextMatchSync('a💻bYX', 3), m(0, [[4, 5]]));
        eq(scanner.findNextMatchSync('a💻bYX', 4), m(0, [[4, 5]]));
        eq(scanner.findNextMatchSync('a💻bYX', 5), m(1, [[5, 6]]));

        current = 'unicode3';
        scanner = new OnigScanner(['Возврат']);
        eq(scanner.findNextMatchSync('Возврат long_var_name;', 0), m(0, [[0, 7]]));

        current = 'unicode4';
        scanner = new OnigScanner(['X']);
        var a = 'X' + String.fromCharCode(0xd83c) + 'X';
        eq(scanner.findNextMatchSync(a, 0), m(0, [[0, 1]]));
        eq(scanner.findNextMatchSync(a, 1), m(0, [[2, 3]]));
        eq(scanner.findNextMatchSync(a, 2), m(0, [[2, 3]]));
        var b = 'X' + String.fromCharCode(0xdfff) + 'X';
        eq(scanner.findNextMatchSync(b, 0), m(0, [[0, 1]]));
        eq(scanner.findNextMatchSync(b, 1), m(0, [[2, 3]]));
        eq(scanner.findNextMatchSync(b, 2), m(0, [[2, 3]]));
        /* These are actually valid, just testing the min & max */
        eq(scanner.findNextMatchSync('X' + String.fromCharCode(0xd800) + String.fromCharCode(0xdc00) + 'X', 2), m(0, [[3, 4]]));
        eq(scanner.findNextMatchSync('X' + String.fromCharCode(0xdbff) + String.fromCharCode(0xdfff) + 'X', 2), m(0, [[3, 4]]));

        current = 'out of bounds';
        scanner = new OnigScanner(['X']);
        eq(scanner.findNextMatchSync('X💻X', -1000), m(0, [[0, 1]]));
        eq(scanner.findNextMatchSync('X💻X', 1000), null);

        current = 'regex with \\G';
        var str = new OnigString('first-and-second');
        scanner = new OnigScanner(['\\G-and']);
        eq(scanner.findNextMatchSync(str, 0), null);
        eq(scanner.findNextMatchSync(str, 5), m(0, [[5, 9]]));

        current = 'kkos/oniguruma#192';
        str = new OnigString("    while (i < len && f(array[i]))");
        scanner = new OnigScanner(["(?x)\n  (?<!\\+\\+|--)(?<=[({\\[,?=>:*]|&&|\\|\\||\\?|\\*\\/|^await|[^\\._$[:alnum:]]await|^return|[^\\._$[:alnum:]]return|^default|[^\\._$[:alnum:]]default|^yield|[^\\._$[:alnum:]]yield|^)\\s*\n  (?!<\\s*[_$[:alpha:]][_$[:alnum:]]*((\\s+extends\\s+[^=>])|,)) # look ahead is not type parameter of arrow\n  (?=(<)\\s*(?:([_$[:alpha:]][-_$[:alnum:].]*)(?<!\\.|-)(:))?((?:[a-z][a-z0-9]*|([_$[:alpha:]][-_$[:alnum:].]*))(?<!\\.|-))(?=((<\\s*)|(\\s+))(?!\\?)|\\/?>))"]);
        eq(scanner.findNextMatchSync(str, 0), null);

        current = 'FindOption.NotBeginPosition';
        str = new OnigString('first-and-second');
        scanner = new OnigScanner(['\\G-and']);
        eq(scanner.findNextMatchSync(str, 5), m(0, [[5, 9]]));
        eq(scanner.findNextMatchSync(str, 5, [FindOption.NotBeginPosition]), null);

        current = 'FindOption.NotBeginString';
        str = new OnigString('first-and-first');
        scanner = new OnigScanner(['\\Afirst']);
        eq(scanner.findNextMatchSync(str, 10), null);
        eq(scanner.findNextMatchSync(str, 0), m(0, [[0, 5]]));
        eq(scanner.findNextMatchSync(str, 0, [FindOption.NotBeginString]), null);

        current = 'FindOption.NotEndString';
        str = new OnigString('first-and-first');
        scanner = new OnigScanner(['first\\z']);
        eq(scanner.findNextMatchSync(str, 10), m(0, [[10, 15]]));
        eq(scanner.findNextMatchSync(str, 10, [FindOption.NotEndString]), null);

        current = 'Configure scanner';
        str = new OnigString('ABCD');
        scanner = new OnigScanner(['^[a-z]*$'], {options: [FindOption.Ignorecase]});
        eq(scanner.findNextMatchSync(str, 0), m(0, [[0, 4]]));

        current = 'Configure syntax';
        str = new OnigString('first-and-first');
        scanner = new OnigScanner(['^(?P<name>.*)$'], {syntax: Syntax.Python});
        eq(scanner.findNextMatchSync(str, 0), m(0, [[0, 15], [0, 15]]));

        current = 'Throw error';
        var msg:String = null;
        try {
            new OnigScanner(['(?P<name>a*)']);
        }
        catch (e:OnigScanner.OnigError) {
            msg = e.message;
        }
        if (msg != null && msg.indexOf('undefined group option') != -1) passed++;
        else {
            failed++;
            failures.push('vscode-oniguruma Throw error: got ' + msg);
        }

        return {passed: passed, failed: failed};
    }

}
