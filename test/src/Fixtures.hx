/** Reads the test fixtures from disk (node and hxcpp). */
class Fixtures {

    public static var dir:String = null;

    public static function read(name:String):String {
        var path = dir + '/' + name;
        #if js
        return js.Syntax.code("require('fs').readFileSync({0}, 'utf8')", path);
        #else
        return sys.io.File.getContent(path);
        #end
    }

    public static function list():Array<String> {
        #if js
        var files:Array<String> = js.Syntax.code("require('fs').readdirSync({0})", dir);
        #else
        var files = sys.FileSystem.readDirectory(dir);
        #end
        files.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        return files;
    }

    public static function args():Array<String> {
        #if js
        var a:Array<String> = js.Syntax.code("process.argv.slice(2)");
        return a;
        #else
        return Sys.args();
        #end
    }

}

class Out {
    public static function println(s:String):Void {
        #if js
        js.Syntax.code("console.log({0})", s);
        #else
        Sys.println(s);
        #end
    }
}
