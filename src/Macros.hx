#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.TypedExpr;
import haxe.macro.ExprTools;

using haxe.macro.Tools;
#end


@:keep
class Macros {
  
  #if !macro macro #end
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    for (field in fields) {
      switch (field.kind) {
        case FFun(func):
          func.expr = makeNoOp(func.expr);
        default:
      }
    }
    
    return fields;
  }
  
  #if !macro macro #end
  static function makeNoOp(e:Expr):Expr {
    
    return switch (e.expr) {
      case ECall(expr, params):
        trace("call " + expr);
        var resExpr = e;
        try {
          var typed:TypedExpr = Context.typeExpr(expr);
          var methodName = TTypedExprTools.toString(typed, true);
          trace("  " + methodName);
          if (methodName == "Debug.logRemove") {
            trace("  Remove this");
            var noopFunc = Context.parseInlineString(
              "Macros.NOOP()",
              Context.currentPos()
            );
            
            trace("Parsed: " + noopFunc);
            resExpr = macro $noopFunc;
            //resExpr = macro null;
          }
        } catch (err:Dynamic){
          trace("SKIP: " + err);
        }
        resExpr;
        
      default:
        ExprTools.map(e, makeNoOp);
    }
  }
  
  static public function NOOP():Void {
    trace("NOOP");
  }
}