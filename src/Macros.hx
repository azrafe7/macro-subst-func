#if macro
import haxe.macro.Type.ClassType;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.TypedExpr;
import haxe.macro.ExprTools;

using haxe.macro.Tools;


@:keep
class Macros {
  
  inline static var NO_SUBST = "noSubst";
  inline static var META_NO_SUBST = "@" + NO_SUBST;
  
  static var typePath:String;
  static var methodName:String;
  static var withCode:String;
  static var forwardArgs:Bool;
  static var logSubsts:Bool;
  
  static var fullMethodName:String;
  
  static public function printInfo():Void {
    trace("substStaticCall");
    trace("  typePath: " + Macros.typePath);
    trace("  methodName: " + Macros.methodName);
    trace("  withCode: " + Macros.withCode);
    trace("  forwardArgs: " + Macros.forwardArgs);
    trace("  logSubsts: " + Macros.logSubsts);
    trace("");
    trace("  fullMethodName: " + Macros.fullMethodName);
  }
    
  static public function substStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    Macros.typePath = typePath;
    Macros.methodName = methodName;
    Macros.withCode = withCode == null ? 'null' : withCode;
    Macros.forwardArgs = forwardArgs == true;
    Macros.logSubsts = logSubsts == true;
    
    Macros.fullMethodName = [Macros.typePath, Macros.methodName].join(".");
    
    printInfo();
    
    Compiler.addMetadata(META_NO_SUBST, Macros.typePath, Macros.methodName, true);
    Compiler.addGlobalMetadata('', '@:build(Macros.build())');
  }
  
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    for (field in fields) {
      var className = Context.getLocalClass();
      
      // don't mess with things in std
      trace("IN_STD : " + isInStd(field.pos));
      if (isInStd(field.pos)) {
        trace('SKIPPING CLASS $className');
        return null;
      }
      
      var classType:ClassType = getClassTypeOwnerOf(field);
      trace("TYPE   : " + classType);
      trace("METAS  : " + classType.meta.get().map(function(m) return m.name));
      trace("NOSUBST: " + classType.meta.has(NO_SUBST));
      
      if (classType.meta.has(NO_SUBST)) {
        trace('SKIPPING CLASS $className');
        return null;
      }
      
      switch (field.kind) {
        case FFun(func):
          if (field.meta != null && field.meta.length > 0) {
            
            trace("META: " + field.meta);
            var hasNoSubst = field.meta.filter(function(m) return StringTools.startsWith(m.name, NO_SUBST)).length > 0;
            if (hasNoSubst) {
            trace('SKIPPING METHOD ${field.name}');
              continue;
            }
          }
          
          trace("FIELD: " + field.name);
          trace("FEXPR(before): " + func.expr);
          
          level = 0;
          func.expr = substExprCall(func.expr);
          trace("FEXPR(after): " + func.expr);
        default:
      }
    }
    
    return fields;
  }
  
  static var level = 0;
  
  static function substExprCall(e:Expr):Expr {

    var indent = [for (i in 0...level + 1) " "].join("");
    trace((level++) + indent + e);
    
    return switch (e.expr) {
      case ECall(expr, params):
        trace(indent + " call " + expr);
        trace(indent + " call() " + expr.toString());
        trace(indent + " params " + params);
        var resExpr = e;
        try {
          trace(indent + " TRY");
          var callString = expr.toString();
          var shouldSubst = callString == Macros.fullMethodName;
          trace(indent + "  SHOULD_SUBST: " + shouldSubst);
          
          if (shouldSubst) {
            trace(indent + "   subst this");
            var substFunc = Context.parse(
              Macros.withCode,
              e.pos
            );
            
            if (forwardArgs && params != null) {
              trace(indent + "   forward args: " + params.map(ExprTools.toString));
              substFunc.expr = switch (substFunc.expr) {
                case ECall(x, _):
                  ECall(x, params);
                case _:
                  substFunc.expr;
              }
            }
            
            trace(indent + "  substFunc: " + substFunc);
            trace(indent + "  substFunc(): " + substFunc.toString());
            //resExpr = resExpr;            // no changes
            resExpr = substFunc;    // subst
            //resExpr = macro null;         // subst with null
          }
        } catch (err:Dynamic) {
          trace(indent + " CATCH: " + err);
        }
        trace(level + indent + "resExpr");
        resExpr;
        
      case _:
        ExprTools.map(e, substExprCall);
    }
  }
  
  static public function getClassTypeOwnerOf(f:Field):ClassType {
    return Context.getLocalClass().get();
  }
  
  static public function isInStd(pos:Position):Bool {
    var file = TPositionTools.getInfos(pos).file;
    var ereg = ~/[\\\/]std[\\\/]/;
    return ereg.match(file);
  }
}
#end