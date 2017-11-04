#if macro
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.TypedExpr;
import haxe.macro.ExprTools;

using haxe.macro.Tools;
#end


class Macros {
  
  #if macro
  static public function build() {
    
    var fields = Context.getBuildFields();
    trace(Context.getLocalType());
    
    for (field in fields) {
      switch (field.kind) {  
        case FFun(func):
          //trace('FEXPR(${field.name}): ' + func.expr.toString());
          func.expr = loop(func.expr);
        
        default:
      }
    }
    
    return fields;
  }
  
  
  static function loop(e:Expr):Expr {
    
    return switch (e.expr) {
      case ECall(expr, params):
        var resExpr = e;
        try {
          var type = Context.typeof(e);
          trace("TYPE: " + type);
        } catch(err:Dynamic) {
          trace("CATCH: " + err);
        }
        resExpr;
        
      case _:
        ExprTools.map(e, loop);
    }
  }
  #end
}