package mylib;

import Debug.log;

@:build(Macros.build())
class MyLib {
  
  var i:Int;
  
  public function new(i:Int):Void {
    this.i = i;
    Debug.log("new MyLib(" + i + ")");
  }
}


