import subst.Macros;
import haxe.Int64;
import mylib.MyLib;
import Debug.logRemove;

@:keep
//@:build(subst.Macros.build())
class Main {
  
  static var str = "string";
  static var i64 = Int64.fromFloat(255.);
  
  static public function main():Void {
    logRemove(str);
    Debug.logRemove(Std.string(i64));
    logRemove(str + " " + i64);
    trace(str + " " + i64);
    Main.work();
    var ml = new MyLib(13);
  }
  
  @:keep
  static public function work():Void {
    for (i in 0...3) {
      trace(i);
      logRemove(Std.string(i));
    }
  }
}