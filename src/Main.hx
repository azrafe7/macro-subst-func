import Macros;
import mylib.MyLib;
import Debug.log;


@:build(Macros.build())
class Main {
  static var str = "string";
  
  static public function main():Void {
    Debug.log(str);
    trace(str);
    work();
    var ml = new MyLib(13);
  }
  
  static public function work():Void {
    for (i in 0...3) {
      trace(i);
      log(Std.string(i));
    }
  }
}