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
  
  /** `dotPath` is expected to be like `Debug.logRemove`. 
   * 
   * (no parentheses, full path)
   * logs to substs.log
   */
  static public function substStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    Macros.typePath = typePath;
    Macros.methodName = methodName;
    Macros.withCode = withCode == null ? 'null' : withCode;
    Macros.forwardArgs = forwardArgs == true;
    Macros.logSubsts = logSubsts == true;
    trace("substStaticCall");
    trace("  typePath: " + Macros.typePath);
    trace("  methodName: " + Macros.methodName);
    trace("  withCode: " + Macros.withCode);
    trace("  forwardArgs: " + Macros.forwardArgs);
    trace("  logSubsts: " + Macros.logSubsts);
    Compiler.addMetadata(META_NO_SUBST, Macros.typePath, Macros.methodName, true);
    Compiler.addGlobalMetadata('', '@:build(Macros.build())');
  }
  
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    //Context.onTypeNotFound(function (typeStr:String):TypeDefinition {
      //trace("NOT FOUND " + typeStr);
      //return null;
    //});
    
    for (field in fields) {
      //var file = TPositionTools.getInfos(field.pos).file;
      //var ereg = ~/[\\\/]std[\\\/]/;
      //trace(ereg.match(file) + " " + file);
      //if (ereg.match(file)) return null;
      
      var className = Context.getLocalClass();
      
      // don't mess with things in std
      trace("IN_STD  :" + isInStd(field.pos));
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
          func.expr = makeNoOp(func.expr);
          trace("FEXPR(after): " + func.expr);
        default:
      }
    }
    
    return fields;
  }
  
  static var level = 0;
  
  static function makeNoOp(e:Expr):Expr {
    //return e;
    //if (e == null) {
      //trace(" returning null");
      //return null;
    //}
    //trace(Context.getLocalClass().get());
    var indent = [for (i in 0...level + 1) " "].join("");
    trace((level++) + indent + e);
    //var file = TPositionTools.getInfos(e.pos).file;
    //var ereg = ~/[\\\/]std[\\\/]/;
    //trace(ereg.match(file) + " " + file);
    //if (ereg.match(file)) return e;
    
    return switch (e.expr) {
      case ECall(expr, params):
        trace(indent + " call " + expr);
        trace(indent + " params " + params);
        var resExpr = e;
        try {
          trace(indent + " TRY");
          trace(indent + "  ISCALLPATH: " + isCallTo(Macros.typePath + "." + Macros.methodName, e));
          //var type = Context.typeof(resExpr);
          //trace("TYPE: " + type);
          //var methodName = TTypeTools.toString(type);
          
          var extractedCIdent = switch (expr) {
            case {expr:EConst(CIdent(name)), pos:_}: name;
            case _: "";
          };
          var methodName = Macros.typePath + "." + extractedCIdent;
          
          trace(indent + "  METH: " + methodName);
          if (methodName == Macros.typePath + "." + Macros.methodName) {
            trace(indent + "   subst this");
            var noopFunc = Context.parse(
              Macros.withCode,
              e.pos
            );
            
            if (forwardArgs && params != null) {
              trace(indent + "   forward args: " + params.map(ExprTools.toString));
              noopFunc.expr = switch (noopFunc.expr) {
                case ECall(x, _):
                  ECall(x, params);
                case _:
                  noopFunc.expr;
              }
            }
            
            trace(indent + "  noopFunc: " + noopFunc);
            //resExpr = resExpr;            // no changes
            resExpr = noopFunc;    // subst with NOOP()
            //resExpr = macro null;         // subst with null
          }
        } catch (err:Dynamic) {
          trace(indent + " CATCH: " + err);
        }
        trace(level + indent + "resExpr");
        resExpr;
        
      case _:
        ExprTools.map(e, makeNoOp);
    }
  }
  
  static public function isCallTo(call:String, expr:Expr):Bool {
    var callPath = call.split(".");
    return _isCallTo(callPath, expr);
  }
  
  static function _isCallTo(callPath:Array<String>, expr:Expr, idx:Int = 0):Bool {
    var lastIdx = callPath.length - 1;
    if (lastIdx < 0) return false;
    var currPart = callPath.shift();
    
    return switch (expr.expr) {
      case EField(fieldExpr, name):
        if (name == currPart) {
          if (idx == lastIdx) true;
          else _isCallTo(callPath, fieldExpr, idx + 1);
        } else {
          false;
        }
        
      case ECall(callExpr, params):
        switch (callExpr.expr) {
          case EConst(CIdent(name)):
            if (name == currPart) {
              if (idx == lastIdx) true;
              else _isCallTo(callPath, callExpr, idx + 1);
            } else {
              false;
            }
          
          case _:
            false;
        }
            
      case _:
        false;
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