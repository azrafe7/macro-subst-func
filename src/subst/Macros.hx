package subst;

#if !macro
/** Implementation only available in macro. */
class Macros {
#else
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
  
  static var substitutions:Array<String>;
  
  
  static public function printInfo():Void {
    dbg("substStaticCall");
    dbg("  typePath: " + Macros.typePath);
    dbg("  methodName: " + Macros.methodName);
    dbg("  withCode: " + Macros.withCode);
    dbg("  forwardArgs: " + Macros.forwardArgs);
    dbg("  logSubsts: " + Macros.logSubsts);
    dbg("");
    dbg("  fullMethodName: " + Macros.fullMethodName);
    dbg("");
  }
  
  static public function substStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    Macros.typePath = typePath;
    Macros.methodName = methodName;
    Macros.withCode = withCode == null ? 'null' : withCode;
    Macros.forwardArgs = forwardArgs == true;
    Macros.logSubsts = logSubsts == true;
    
    Macros.fullMethodName = [Macros.typePath, Macros.methodName].join(".");
    
    printInfo();
    
    Macros.substitutions = [];
    Compiler.addMetadata(META_NO_SUBST, Macros.typePath, Macros.methodName, true);
    Compiler.addGlobalMetadata('', '@:build(subst.Macros.build())');
    
    Context.onAfterTyping(function (_):Void {
      var substs = Macros.substitutions.map(function(s) return "\n  " + s).join("");
      dbg('Substitutions: ${Macros.substitutions.length}' + substs);
    });
  }
  
  static public function build() {
    
    var fields = Context.getBuildFields();
    
    for (field in fields) {
      var className = Context.getLocalClass();
      dbg("CLASS  : " + className);
      
      // don't mess with things in std
      dbg("IN_STD : " + isInStd(field.pos) + ' (${field.pos})');
      if (isInStd(field.pos)) {
        dbg('SKIPPING CLASS (in std)');
        return null;
      }
      
      var classType:Null<ClassType> = getClassTypeOwnerOf(field);
      if (classType == null) {
        dbg('SKIPPING CLASS (type == null)');
        return null;
      }
      
      if (classType != null) {
        dbg("TYPE   : " + classType);
        dbg("METAS  : " + classType.meta.get().map(function(m) return m.name));
        dbg("NOSUBST: " + classType.meta.has(NO_SUBST));
        
        //dbg('ERRRO SKIPPING ');
        //return null;
      }
      
      if (classType.meta.has(NO_SUBST)) {
        dbg('SKIPPING CLASS (marked with $META_NO_SUBST)');
        return null;
      }
      
      switch (field.kind) {
        case FFun(func):
          if (field.meta != null && field.meta.length > 0) {
            
            dbg("META: " + field.meta);
            var hasNoSubst = field.meta.filter(function(m) return StringTools.startsWith(m.name, NO_SUBST)).length > 0;
            if (hasNoSubst) {
            dbg('SKIPPING METHOD ${field.name}');
              continue;
            }
          }
          
          dbg("FIELD: " + field.name);
          dbg("FEXPR(before): " + func.expr);
          
          level = 0;
          func.expr = substExprCall(func.expr);
          dbg("FEXPR(after): " + func.expr);
        default:
      }
    }
    
    return fields;
  }
  
  static var level = 0;
  
  static function substExprCall(e:Expr):Expr {

    if (e == null) return null;
    var indent = [for (i in 0...level + 1) " "].join("");
    dbg((level++) + indent + e);
    
    return switch (e.expr) {
      case ECall(expr, params):
        dbg(indent + " call " + expr);
        dbg(indent + " call() " + expr.toString());
        dbg(indent + " params " + params);
        var resExpr = e;
        
        var callString = "";
        var succesfulTyping = false;
        // NOTE(az): reenable this when https://github.com/HaxeFoundation/haxe/issues/6736 is fixed
        //try {
          //// try to type expr
          //dbg(indent + " TRY");
          //var typedExpr:TypedExpr = Context.typeExpr(expr);
          //var methodName = TTypedExprTools.toString(typedExpr, true);
          //succesfulTyping = true;
          //callString = methodName;
          //dbg(indent + "  GOT A TYPED_EXPR");
        //} catch (err:Dynamic) {
          //dbg(indent + " CATCH: " + err);
        //}
        
        // unsuccessful typing, use expr.toString()
        if (!succesfulTyping) callString = expr.toString();
        
        var shouldSubst = (callString == Macros.fullMethodName);
        dbg(indent + "  SHOULD_SUBST: " + shouldSubst);
          
        if (shouldSubst) {
          dbg(indent + "   subst this");
          var substFunc = Context.parse(
            Macros.withCode,
            e.pos
          );
          
          if (forwardArgs && params != null) {
            dbg(indent + "   forward args: " + params.map(ExprTools.toString));
            substFunc.expr = switch (substFunc.expr) {
              case ECall(x, _):
                ECall(x, params);
              case _:
                substFunc.expr;
            }
          }
          
          dbg(indent + "  substFunc: " + substFunc);
          dbg(indent + "  substFunc(): " + substFunc.toString());
          //resExpr = resExpr;            // no changes
          resExpr = substFunc;    // subst
          //resExpr = macro null;         // subst with null
          
          dbg(indent + " SUBSTED");
          Macros.substitutions.push('${e.toString()} => ${substFunc.toString()}');
        }
          
        dbg(level + indent + "resExpr");
        resExpr;
        
      case _:
        ExprTools.map(e, substExprCall);
    }
  }
  
  static public function getClassTypeOwnerOf(f:Field):Null<ClassType> {
    try {
      return Context.getLocalClass().get();
    } catch (err:Dynamic) {
      dbg("getClassTypeOwnerOf() FAILED");
    }
    return null;
  }
  
  static public function isInStd(pos:Position):Bool {
    var file = TPositionTools.getInfos(pos).file;
    var ereg = ~/[\\\/]std[\\\/]/;
    return ereg.match(file);
  }
  
#end


#if subst_debug
  static function dbg(v:Dynamic, ?infos:haxe.PosInfos):Void {
    haxe.Log.trace(v, infos);
  }
#else
  inline static function dbg(v:Dynamic, ?infos:haxe.PosInfos):Void { }
#end
}
