
@:build(Macros.build())
class Debug {
  
  static public function log(s:String):String {
    var msg = "LOG: " + s;
    trace(msg);
    return msg;
  }
}