package mylib;

import Debug;

@:keep
class MyLib {
  
  var i:Int;
  
  public function new(i:Int):Void {
    this.i = i;
    Debug.logRemove("new MyLib(" + i + ")");
  }
  
  static public function name():Void {
    trace("inside MyLib");
  }
}


