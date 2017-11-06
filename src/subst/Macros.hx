package subst;

#if !macro
/** Implementation only available in macro. */
class Macros {
#else
import haxe.ds.Map;
import haxe.macro.Type.ClassType;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.TypedExpr;
import haxe.macro.ExprTools;

using haxe.macro.Tools;


typedef ConfigHash = String;


class SubstConfig {
  
  public var typePath:String;
  public var methodName:String;
  public var withCode:String;
  public var forwardArgs:Bool;
  public var logSubsts:Bool;
  
  public var fullMethodName:String;
  
  public var hash:ConfigHash;
  public var params:String = null;
  
  public function new(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false):Void {
    this.typePath = typePath;
    this.methodName = methodName;
    this.withCode = withCode == null ? 'null' : withCode;
    this.forwardArgs = forwardArgs == true;
    this.logSubsts = logSubsts == true;
    
    this.fullMethodName = [this.typePath, this.methodName].join(".");
    this.hash = StringTools.replace(this.asParams(), " ", "");
  }
  
  public function asParams():String {
    if (this.params == null) {
      this.params = '"$typePath","$methodName",\'$withCode\',$forwardArgs,$logSubsts';
    }
    return this.params;
  }
  
  public function toString():String {
    return ["",
      "substStaticCall",
      "  typePath: " + typePath,
      "  methodName: " + methodName,
      "  withCode: " + withCode,
      "  forwardArgs: " + forwardArgs,
      "  logSubsts: " + logSubsts,
      "",
      "  fullMethodName: " + fullMethodName,
      ""].join("\n");
  }
}

@:keep
class Macros {
  
  inline static var NO_SUBST = "noSubst";
  inline static var META_NO_SUBST = "@" + NO_SUBST;
  
  static var configs:Map<ConfigHash, SubstConfig> = new Map();
  static var substitutions:Map<ConfigHash, Array<String>> = new Map();
  static var inited = false;
  
  static var currConfig:SubstConfig;
  
  
  static public function globalSubstStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    var config = new SubstConfig(typePath, methodName, withCode, forwardArgs, logSubsts);
    Compiler.addGlobalMetadata('', "@:build(subst.Macros.substStaticCall(" + config.asParams() + "))");
  }
  
  static public function substStaticCall(typePath:String, methodName:String, ?withCode:String, forwardArgs:Bool = false, logSubsts:Bool = false) {
    
    currConfig = new SubstConfig(typePath, methodName, withCode, forwardArgs, logSubsts);
    if (!configs.exists(currConfig.hash)) {
      dbg("START" + currConfig.toString());
      configs[currConfig.hash] = currConfig;
      substitutions[currConfig.hash] = [];
    }
    
    if (!inited) {
      Context.onAfterTyping(function (_):Void {
        for (k in substitutions.keys()) {
          var entry = substitutions[k];
          var substsStr = entry.map(function(s) return "\n  " + s).join("");
          dbg("END" + configs[k].toString() + '\n  substitutions: ${entry.length}' + substsStr + "\n");
        }
      });
    }
    inited = true;
    
    return build();
  }
  
  static function build() {
    
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
        
        var shouldSubst = (callString == currConfig.fullMethodName);
        dbg(indent + "  SHOULD_SUBST: " + shouldSubst);
          
        if (shouldSubst) {
          dbg(indent + "   subst this");
          var substFunc = Context.parse(
            currConfig.withCode,
            e.pos
          );
          
          if (currConfig.forwardArgs && params != null) {
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
          substitutions[currConfig.hash].push(e.pos + ': ${e.toString()} => ${substFunc.toString()}');
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
