#if macro
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.TypedExpr;
import haxe.macro.ExprTools;

using haxe.macro.Tools;
#end


@:keep
class Macros {
  
  inline static var NO_SUBST = "@noSubst";
  
  static var typePath:String;
  static var methodName:String;
  static var withCode:String;
  static var forwardArgs:Bool;
  static var logSubsts:Bool;
  
  /** `dotPath` is expected to be like `Debug.logRemove`. 
   * 
   * (no parentheses, full path)
   * logs to substs.log
   */
  #if !macro macro #end
  static public function substStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    Macros.typePath = typePath;
    Macros.methodName = methodName;
    Macros.withCode = withCode == null ? 'null' : withCode;
    Macros.forwardArgs = forwardArgs == true;
    Macros.logSubsts = logSubsts == true;
    trace("substStaticCall");
    trace(" typePath: " + Macros.typePath);
    trace(" methodName: " + Macros.methodName);
    trace(" withCode: " + Macros.withCode);
    trace(" forwardArgs: " + Macros.forwardArgs);
    trace(" logSubsts: " + Macros.logSubsts);
    Compiler.addMetadata(NO_SUBST, Macros.typePath, Macros.methodName, true);
    Compiler.addGlobalMetadata('', '@:build(Macros.build())');
  }
  
  #if !macro macro #end
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    for (field in fields) {
      switch (field.kind) {
        case FFun(func):
          if (field.meta != null && field.meta.length > 0) {
            trace("META: " + field.meta);
            var hasNoSubst = field.meta.filter(function(m) return StringTools.startsWith(m.name, NO_SUBST.substr(1))).length > 0;
            if (hasNoSubst) continue;
          }
          
          func.expr = makeNoOp(func.expr);
        default:
      }
    }
    
    return fields;
  }
  
  #if !macro macro #end
  static function makeNoOp(e:Expr):Expr {
    if (e == null) return null;
    
    var file = TPositionTools.getInfos(e.pos).file;
    var ereg = ~/[\\\/]std[\\\/]/;
    trace(ereg.match(file));
    if (ereg.match(file)) return e;
    
    return switch (e.expr) {
      case ECall(expr, params):
        trace("call " + expr);
        trace("params " + params);
        var resExpr = e;
        try {
          var typed:TypedExpr = Context.typeExpr(expr);
          var methodName = TTypedExprTools.toString(typed, true);
          trace("  " + methodName);
          if (methodName == Macros.typePath + "." + Macros.methodName) {
            trace("  Remove this");
            var noopFunc = Context.parse(
              Macros.withCode,
              e.pos
            );
            
            if (forwardArgs && params != null) {
              trace("Try to forward args: " + params.map(ExprTools.toString));
              noopFunc.expr = switch (noopFunc.expr) {
                case ECall(x, _):
                  ECall(x, params);
                case _:
                  noopFunc.expr;
              }
            }
            
            trace("Parsed: " + noopFunc);
            trace("        " + macro $noopFunc);
            //resExpr = resExpr;            // no changes
            resExpr = macro $noopFunc;    // subst with NOOP()
            //resExpr = macro null;         // subst with null
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