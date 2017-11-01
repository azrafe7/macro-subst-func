import Macros;
import haxe.Int64;
import mylib.MyLib;
import Debug.logRemove;

@:keep
@removeCall
@:build(Macros.build())
class Main {
  
  static var str = "string";
  static var i64 = Int64.fromFloat(255.);
  
  static public function main():Void {
    logRemove("HIDE " + str);
    Debug.logRemove("HIDE " + Std.string(i64));
    logRemove("HIDE " + str + " " + i64);
    trace("SHOW " + str + " " + i64);
    work();
  }
  
  @:keep
  static public function work():Void {
    for (i in 0...3) {
      trace("SHOW " + i);
      logRemove("HIDE " + Std.string(i));
    }
  }
}