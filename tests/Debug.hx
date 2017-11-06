
@:keep
class Debug {
  
  static public function logRemove(s:String):String {
    var msg = "LOGREMOVE: " + s;
    trace(msg);
    return msg;
  }
  
  static public function NOOP():Void {
    trace("NOOP");
  }
}