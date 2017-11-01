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
  static public function remove(functionName:String) {
    trace(functionName);
    return macro null;
  }
  
  #if !macro macro #end
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    for (field in fields) {
      switch (field.kind) {
        case FFun(func):
          var name = field.name;
          trace(name + "()");
          trace("---" + func.expr.toString());
          
          func.expr = dbg(func.expr);
          //return macro $v{Macros.noOp};
          
          //func.expr = makeNoOp(func.expr);
          
          
          
        default:
          
      }
    }
    
    return fields;
  }
  
  #if !macro macro #end
  static function dbg(e:Expr):Expr {
    
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
              Context.currentPos());
            
            trace("Parsed: " + noopFunc);
            resExpr = macro $noopFunc;
          }
        } catch (err:Dynamic){
          trace("SKIP: " + err);
        }
        resExpr;
      default:
        ExprTools.map(e, dbg);
    }
  }
  
  
  #if !macro macro #end
  static function makeNoOp(expr:Expr):Expr {
    if (expr == null) return null;
    
    switch (expr.expr) {
      case ECall(expr, params):
        //trace(ExprTools.toString(expr));
        var typed:TypedExpr = Context.typeExpr(expr);
        trace("typedExpr: " + typed.toString());
        //trace("type: " + typed.t);
        //var complexType = TTypeTools.toComplexType(type);
        //
        //switch complexType {
          //case TPath(p):
            //trace(p);
          //case TFunction(args, ret):
            //trace(args);
          //default:
        //}
        
        //trace(TComplexTypeTools.toString(complexType));
        //trace("call");
        switch (expr.expr) {
          case EConst(CIdent(id)) if (id == "log"):
            trace("found");
            return macro null;
          default:
            return expr;
        }
        //return ExprTools.map(e.expr, makeNoOp);
      default:
        return ExprTools.map(expr, makeNoOp);
    }
  }
  
  static public function NOOP():Void {
    trace("NOOP");
  }
}