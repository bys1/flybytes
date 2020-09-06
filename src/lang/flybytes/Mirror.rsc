@doc{
.Synopsis Provides a native interface to Java objects via class and object reflection.

.Description

Using this Mirror representation you can test generated class files by loading the class
and executing static methods on the classes, getting static fields, allocating new instances,
calling methods on these instances, etc. There is also support for native arrays.
}
module lang::flybytes::Mirror

import lang::flybytes::Syntax;

data Mirror
  = class(str class, 
        Mirror (Signature method, list[Mirror] args) invokeStatic,
        Mirror (str name) getStatic,
        Mirror (Signature constructor, list[Mirror] args) newInstance,
        Mirror (Type \type) getAnnotation)
  | object(Mirror classMirror, 
        Mirror (Signature method, list[Mirror] args) invoke,
        Mirror (str name) getField,
        &T  (type[&T] expect) toValue)
  | array(int () length,
        Mirror (int index) load)
  | \null()
  ;
              
@javaClass{lang.flybytes.internal.ClassCompiler}
@reflect{for stdout}
@memo
@doc{reflects a Rascal value as a JVM object Mirror}
java Mirror val(value v);

@javaClass{lang.flybytes.internal.ClassCompiler}
@reflect{for stdout}
@memo
@doc{reflects a JVM class object as Mirror class}
java Mirror classMirror(str name);

@javaClass{lang.flybytes.internal.ClassCompiler}
@reflect{for stdout}
@doc{creates a mirrored array}
java Mirror array(Type \type, list[Mirror] elems);

@javaClass{lang.flybytes.internal.ClassCompiler}
@reflect{for stdout}
@doc{creates a mirrored array}
java Mirror array(Type \type, int length);

str toString(Mirror m:object(_, _, _, _)) = m.invoke(methodDesc(string(),"toString", []), []).toValue(#str);
str toString(class(str name, _, _, _, _)) = name;
str toString(null()) = "\<null\>";
str toString(Mirror m:array(_, _)) = "array[<m.length()>]";              
   
Mirror integer(int v)
  = val(v).invoke(methodDesc(integer(), "intValue", []), []);
  
Mirror long(int v)
  = val(v).invoke(methodDesc(integer(), "longValue", []), []);
  
Mirror byte(int v)
  = classMirror("java.lang.Byte").invokeStatic(methodDesc(byte(), "parseByte", [string()]), [\string("<v>")]);  

Mirror short(int v)
  = classMirror("java.lang.Short").invokeStatic(methodDesc(byte(), "parseShort", [string()]), [\string("<v>")]);  

Mirror character(int v)
  = classMirror("java.lang.Character").invokeStatic(methodDesc(array(character()), "toChars", [integer()]), [\integer(v)]).load(0); 

Mirror string(str v)
  = val(v).invoke(methodDesc(string(), "getValue", []), []);
  
Mirror double(real v)
  = val(v).invoke(methodDesc(string(), "doubleValue", []), []);
  
Mirror float(real v)
  = val(v).invoke(methodDesc(string(), "floatValue", []), []);
  
Mirror boolean(bool v)
  = val(v).invoke(methodDesc(string(), "getValue", []), []);  

Mirror prim(integer(), int t) = integer(t);
Mirror prim(short(), int t) = short(t);
Mirror prim(byte(), int t) = byte(t);
Mirror prim(long(), int t) = long(t);
Mirror prim(double(), real t) = double(t);
Mirror prim(float(), real t) = float(t);
Mirror prim(string(), str t) = string(t); 
Mirror prim(character(), int t) = character(t); 
Mirror prim(boolean(), bool t) = boolean(t); 


int integer(Mirror i) = i.toValue(#int);
int long(Mirror l) = l.toValue(#int);
int byte(Mirror b) = b.toValue(#int);
int short(Mirror s) = s.toValue(#int);
str string(Mirror s) = s.toValue(#str);
real double(Mirror d) = d.toValue(#real);
real float(Mirror f) = f.toValue(#real);
int character(Mirror f) = f.toValue(#int);
bool boolean(Mirror f) = f.toValue(#bool);
  
