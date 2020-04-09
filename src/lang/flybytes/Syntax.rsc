@doc{

.Synopsis Flybytes is an intermediate language just above the abstraction level of the JVM bytecode language.

.Description

Flybytes is an intermediate language towards JVM bytecode generation for Rascal-based compilers of Domain Specific Languages and Programming Languages.

### Context:

* you are implementing a textual or graphical DSL or a programming language using Rascal
* you want to target the JVM because of its general availability and the JIT compiler
* you do not have time to get into the hairy details of JVM bytecode generation, and do not have time for debugging on the JVM bytecode level
* you do want to profit from the Just In Time (JIT) compiler, so you need idiomatic JVM bytecode that the JIT compiler understands
* you understand the Java programming language pretty well
* you could generate Java code but that would be too slow and require a JDK as a dependency, or you need `invokedynamic` support for your language which Java does not offer.

### Solution:

1. Flybytes is an intermediate abstract syntax tree format that looks a lot like abstract syntax trees for Java code
1. You translate your own abstract syntax trees for your own language directly to Flybytes ASTs using Rascal
1. The Flybytes compiler use the [ASM framework](https://asm.ow2.io/) to generate bytecode in a single pass of the Flybytes AST
   * either the code is directly streamed to a class file (and optionally loaded)
   * or a reasonably clear error message is produced due to an error in the FlyBytes AST.
   
### Presumptions:

* Flybytes does not cover a priori type checking of the input Flybytes AST. So, a proper application of the Flybytes compiler assumes:
   * Your DSL has its own type checker and the compiler is not called if the input code still has serious type errors or name resolution errors (but you could also generate error nodes for partial compilation support)
   * Your compiler to Flybytes ASTs does not introduce new type errors with respect to the JVM's type system.
* Flybytes does not cover much name resolution, so for imports, foreign names and such you have to provide fully qualified names while generating Flybytes ASTs

### Features:

* Protection from ASM and JVM crashes: the Flybytes compiler does some on-the-fly type checking and error reporting in case you generated something weird.
* Tries to generate JVM bytecode that looks like it could have come from a Java compiler
* Offers many Java-like (high-level programming language) features:
   1. local variable names
   1. formal parameter names
   1. structured control flow: if, while, do-while, try-catch-finally, for, break, continue, return, switch
   1. monitor blocks
   1. full expression language (fully hides stack operations of JVM bytecode)
   1. class, method, and variable annotations 
   1. method invocation specialized towards specific JVM instructions (for efficiency's sake)
* Offers symbolic types and method descriptors (as opposed to mangled strings in JVM bytecode)
* Can generate JVM bytecode which would be type-incorrect for Java, but type-correct for the JVM.
* Additional dynamic language support via `invokedynamic` and construction and invocation of bootstrap methods
* Incrementally growing library of macros for typical program element snippets, such as loops over arrays and loops over iterables, etc.

### Status:

* Flybytes is experimental and currently in alpha stage. 
* Expect renamings and API changes
* The language is fully implemented, with the noted exception of nested classes
* The language is fully tested, with the noted exception of the invokedynamic feature

### TODO:

* add support for error nodes (to support partial compilation and running partially compiled classes)
* refactor compiler exceptions to Rascal exceptions (to help debugging Flybytes AST generators)
* add support for nested classes (helps in generating code for lambda expressions)

### Citations

The design of Flybtyes was informed by the JVM VM spec, the ASM library code and documentation and the Jitescript API:

* <https://docs.oracle.com/javase/specs/jvms/se8/jvms8.pdf>
* <https://asm.ow2.io/>
* <https://github.com/qmx/jitescript>
}
@author{Jurgen J. Vinju}
module lang::flybytes::Syntax

import List;

data Class(list[Annotation] annotations = [], loc src = |unknown:///|)
  = class(Type \type /* object(str name) */, 
      set[Modifier] modifiers = {\public()},
      Type super              = object(),
      list[Type]   interfaces = [],
      list[Field]  fields     = [], 
      list[Method] methods    = []
      //list[Class] children = [],
    )
  | interface(Type \type /* object(str name) */,
      list[Type]   interfaces = [],
      list[Field]  fields  = [],
      list[Method] methods = []
    )  
   ;
    
data Modifier
   = \public()
   | \private()
   | \protected()
   | \friendly()
   | \static()
   | \final()
   | \synchronized()
   | \abstract()
   ;

data Field(list[Annotation] annotations = [], set[Modifier] modifiers = {\private()}, loc src=|unknown:///|)
  = field(Type \type, str name, Exp init = defVal(\type));
         
data Method(list[Annotation] annotations = [], loc src=|unknown:///|)
  = method(Signature desc, list[Formal] formals, list[Stat] block, set[Modifier] modifiers = {\public()})
  | procedure(Signature desc, list[Formal] formals, list[Instruction] instructions, set[Modifier] modifiers = {\public()})
  | method(Signature desc, set[Modifier] modifiers={\abstract(), \public()})
  | static(list[Stat] block)
  ;

Method method(Modifier access, Type ret, str name, list[Formal] formals, list[Stat] block)
  = method(methodDesc(ret, name, [ var.\type | var <- formals]), formals, block, modifiers={access});

data Signature 
  = methodDesc(Type \return, str name, list[Type] formals)
  | constructorDesc(list[Type] formals)
  ;

data Type
  = byte()
  | boolean()
  | short()
  | character()
  | integer()
  | float()
  | double()
  | long()
  | object(str name)  
  | array(Type arg)
  | \void()
  | string()
  ;

data Annotation(RetentionPolicy retention=runtime())
  // values _must_ be str, int, real, list[int], list[str], list[real]
  = \anno(str annoClass, Type \type, value val, str name = "value")
  | \tag(str annoClass) /* tag annotation */
  ;
  
data RetentionPolicy
  = class()   // store in the class file, but drop at class loading time
  | runtime() // store in the class file, and keep for reflective access
  | source()  // forget immediately
  ;
 
@doc{optional init expressions will be used at run-time if `null` is passed as actual parameter}
data Formal
  = var(Type \type, str name, Exp init = defVal(\type)); 

@doc{Structured programming, OO primitives, JVM monitor blocks and breakpoints}
data Stat(loc src = |unknown:///|)
  = \store(str name, Exp \value)
  | \decl(Type \type, str name, Exp init = defVal(\type))
  | \astore(Exp array, Exp index, Exp arg)
  | \do(Exp exp) 
  | \return()
  | \return(Exp arg)
  | \putField(Type class, Exp receiver, Type \type, str name, Exp arg)
  | \putStatic(Type class, str name, Type \type, Exp arg)
  | \if(Exp condition, list[Stat] thenBlock)
  | \if(Exp condition, list[Stat] thenBlock, list[Stat] elseBlock)
  | \for(list[Stat] init, 
         Exp condition, 
         list[Stat] next, 
         list[Stat] statements, str label = "")
  | \block(list[Stat] block, str label = "") 
  | \break(str label = "")
  | \continue(str label = "")
  | \while(Exp condition, list[Stat] block, str label = "") 
  | \doWhile(list[Stat] block, Exp condition, str label = "") 
  | \throw(Exp arg) 
  // `monitor` guarantees release of the lock in case of exceptions, break and continue out of the block, 
  // but only if `release` and `acquire` are not used on the same lock object anywhere:
  | \monitor(Exp arg, list[Stat] block) 
  | \acquire(Exp arg) // this is a bare lock acquire with no regard for exceptions or break and continue
  | \release(Exp arg) // this is a bare lock release. do not mix with the monitor statement on the same lock object.
  | \try(list[Stat] block, list[Handler] \catch) 
  | \switch(Exp arg, list[Case] cases, SwitchOption option = lookup(/*for best performance on current JVMs*/))
  // raw bytecode instruction lists can be inlined directly
  | 
  // Invoke a super constructor, typically only used in constructor method bodies 
    invokeSuper(Signature desc, list[Exp] args)
  
  | \asm(list[Instruction] instructions) 
  ;

data SwitchOption
  = table()
  | lookup()
  | auto()
  ;
  
data Case 
  = \case(int key, list[Stat] block)
  | \default(list[Stat] block)
  ;
  
data Handler 
  = \catch(Type \type, str name, list[Stat] block)
  | \finally(list[Stat] block)
  ;

data Exp(loc src = |unknown:///|)
  = null()
  | \true()
  | \false()
  | load(str name)
  | aload(Exp array, Exp index)
  | \const(Type \type, value constant)
  | sblock(list[Stat] statements, Exp arg)
  
  | /* For invoking static methods of classes or interfaces */
    invokeStatic(Type class, Signature desc, list[Exp] args)
  
  | /* If no dynamic dispatch is needed, or searching superclasses is required, and you know which class 
     * implements the method, use this to invoke a method for efficiency's sake. 
     * The invocation is checked at class load time. 
     */
    invokeSpecial(Type class, Exp receiver, Signature desc, list[Exp] args)
  
  | /* If you do need dynamic dispatch, or the method is implemented in a superclass, and this is
     * not a default method of an interface, use this invocation method. You need to be sure the method
     * exists _somewhere_ reachable from the \class reference type.
     * The invocation is checked at class load time. 
     */
    invokeVirtual(Type class, Exp receiver, Signature desc, list[Exp] args)
  
  | /* For invoking methods you know only from interfaces, such as default methods. 
     * The method can even be absent at runtime in which case this throws a RuntimeException. 
     * The check occurs at the first invocation at run-time. 
     */
    invokeInterface(Type class, Exp receiver, Signature desc, list[Exp] args)
  
  | /* Generate a call site using a static "bootstrap" method, cache it and invoke it */
    /* NB: the first type in `desc` must be the receiver type if the method is not static,
     * and the first argument in `args` is then also the receiver itself */
    invokeDynamic(BootstrapCall handle, Signature desc, list[Exp] args)
      
  | newInstance(Type class, Signature desc, list[Exp] args)
  | getField(Type class, Exp receiver, Type \type, str name)
  | getStatic(Type class, Type \type, str name)
  | instanceof(Exp arg, Type class)
  | eq(Exp lhs, Exp rhs)
  | ne(Exp lhs, Exp rhs)
  | le(Exp lhs, Exp rhs)
  | gt(Exp lhs, Exp rhs)
  | ge(Exp lhs, Exp rhs)
  | lt(Exp lhs, Exp rhs)
  | newArray(Type \type, Exp size)
  | newInitArray(Type \type, list[Exp] args)
  | alength(Exp arg)
  | checkcast(Exp arg, Type \type)
  | coerce(Type from, Type to, Exp arg)
  | shr(Exp lhs, Exp shift)
  | shl(Exp lhs, Exp shift)
  | ushr(Exp lhs, Exp shift)
  | and(Exp lhs, Exp rhs)
  | sand(Exp lhs, Exp rhs) // short-circuit and
  | or(Exp lhs, Exp rhs)
  | sor(Exp lhs, Exp rhs) // short-circuit or
  | xor(Exp lhs, Exp rhs)
  | add(Exp lhs, Exp rhs)
  | sub(Exp lhs, Exp rhs)
  | div(Exp lhs, Exp rhs)
  | rem(Exp lhs, Exp rhs)
  | mul(Exp lhs, Exp rhs)
  | neg(Exp arg)
  | inc(str name, int inc)
  | cond(Exp condition, Exp thenExp, Exp elseExp)
  ;
 
data Instruction
  = LABEL(str label)
  | LINENUMBER(int line, str label)
  | LOCALVARIABLE(str name, Type \type, str \start, str end, int var)
  | TRYCATCH(Type \type, str \start, str end, str handler)
  | NOP()
  | ACONST_NULL()
  | ICONST_M1()
  | ICONST_0()
  | ICONST_1()
  | ICONST_2()
  | ICONST_3()
  | ICONST_4()
  | ICONST_5()
  | LCONST_0()
  | LCONST_1()
  | FCONST_0()
  | FCONST_1()
  | FCONST_2()
  | DCONST_0()
  | DCONST_1()
  | IALOAD()
  | LALOAD()
  | FALOAD()
  | DALOAD()
  | AALOAD()
  | BALOAD()
  | CALOAD()
  | SALOAD()
  | IASTORE()
  | LASTORE()
  | FASTORE()
  | DASTORE()
  | AASTORE()
  | BASTORE()
  | CASTORE()
  | SASTORE()
  | POP()
  | POP2()
  | DUP()
  | DUP_X1()
  | DUP_X2()
  | DUP2()
  | DUP2_X1()
  | DUP2_X2()
  | SWAP()
  | IADD()
  | LADD()
  | FADD()
  | DADD()
  | ISUB()
  | LSUB()
  | FSUB()
  | DSUB()
  | IMUL()
  | LMUL()
  | FMUL()
  | DMUL()
  | IDIV()
  | LDIV()
  | FDIV()
  | DDIV()
  | IREM()
  | LREM()
  | FREM()
  | DREM()
  | INEG()
  | LNEG()
  | FNEG()
  | DNEG()
  | ISHL()
  | LSHL()
  | ISHR()
  | LSHR()
  | IUSHR()
  | LUSHR()
  | IAND()
  | LAND()
  | IOR()
  | LOR()
  | IXOR()
  | LXOR()
  | I2L()
  | I2F()
  | I2D()
  | L2I()
  | L2F()
  | L2D()
  | F2I()
  | F2L()
  | F2D()
  | D2I()
  | D2L()
  | D2F()
  | I2B()
  | I2C()
  | I2S()
  | LCMP()
  | FCMPL()
  | FCMPG()
  | DCMPL()
  | DCMPG()
  | IRETURN()
  | LRETURN()
  | FRETURN()
  | DRETURN()
  | ARETURN()
  | RETURN()
  | ARRAYLENGTH()
  | ATHROW()
  | MONITORENTER()
  | MONITOREXIT()
  | ILOAD(int var)
  | LLOAD(int var)
  | FLOAD(int var)
  | DLOAD(int var)
  | ALOAD(int var)
  | ISTORE(int var)
  | LSTORE(int var)
  | FSTORE(int var)
  | DSTORE(int var)
  | ASTORE(int var)
  | RET(int var)
  | BIPUSH(int val)
  | SIPUSH(int val)
  | NEWARRAY(Type element)
  | LDC(Type \type, value constant)
  | IINC(int var, int inc)
  | IFEQ(str label)
  | IFNE(str label)
  | IFLT(str label)
  | IFGE(str label)
  | IFGT(str label)
  | IFLE(str label)
  | IF_ICMPEQ(str label)
  | IF_ICMPNE(str label)
  | IF_ICMPLT(str label)
  | IF_ICMPGE(str label)
  | IF_ICMPGT(str label)
  | IF_ICMPLE(str label)
  | IF_ACMPEQ(str label)
  | IF_ACMPNE(str label)
  | GOTO(str label)
  | JSR(str label)
  | IFNULL(str label)
  | IFNONNULL(str label)
  | TABLESWITCH(int min, int max, str defaultLabel, list[str] labels)
  | LOOKUPSWITCH(str defaultLabel, list[int] keys, list[str] labels)
  | GETSTATIC(Type class, str name, Type \type)
  | PUTSTATIC(Type class, str name, Type \type)
  | GETFIELD(Type class, str name, Type \type)
  | PUTFIELD(Type class, str name, Type \type)
  | INVOKEVIRTUAL(Type class, Signature desc, bool isInterface)
  | INVOKESPECIAL(Type class, Signature desc, bool isInterface)
  | INVOKESTATIC(Type class, Signature desc, bool isInterface)
  | INVOKEINTERFACE(Type class, Signature desc, bool isInterface)
  | INVOKEDYNAMIC(Signature desc, BootstrapCall handle)
  | NEW(Type \type)
  | ANEWARRAY(Type \type)
  | CHECKCAST(Type \type)
  | INSTANCEOF(Type \type)
  | MULTIANEWARRAY(Type \type, int numDimensions)
  | exp(Exp expression, str label="")
  | stat(Stat statement, str label="")
  ;
  
Exp defVal(boolean()) = const(boolean(), false);
Exp defVal(integer()) = const(integer(), 0);
Exp defVal(long()) = const(long(), 0);
Exp defVal(byte()) = const(byte(), 0);
Exp defVal(character()) = const(character(), 0);
Exp defVal(short()) = const(short(), 0);
Exp defVal(float()) = const(float(), 0.0);
Exp defVal(double()) = const(double(), 0.0);
Exp defVal(object(str _)) = null();
Exp defVal(array(Type _)) = null();
Exp defVal(string()) = null();
 
 // Below some convenience macros for
 // generating methods and constructors:

@synopsis{Object is the top of the JVMs type system} 
Type object() = object("java.lang.Object");

@synopsis{Generates `name+=i;`}
Stat incr(str name, int i) = \do(inc(name, i));

@synopsis{Generates `super(f1, f2); for a given anonymous constructor of type (F1 f1, F2 f2)`}
Stat invokeSuper(list[Type] formals, list[Exp] args)
  = invokeSuper(constructorDesc(formals), args);
  
@synopsis{Generates `super();`}  
Stat invokeSuper() = invokeSuper([], []);
  
@synopsis{Generates a main method `public static final void main(String[] args) { block }`}
Method main(str args, list[Stat] block) 
  = method(methodDesc(\void(), "main", [array(string())]), 
      [var(array(string()), args)], 
      block, 
      modifiers={\public(), \static(), \final()});
      
@synopsis{Short-hand for generating a normal method}
Method method(Modifier access, Type ret, str name, list[Formal] args, list[Stat] block)
  = method(methodDesc(ret, name, [a.\type | a <- args]), 
           args, 
           block, 
           modifiers={access});

@synopsis{Short-hand for generating a normal public method}
Method method(Type ret, str name, list[Formal] args, list[Stat] block)
  = method(\public(), ret, name, args, block);
            
@synopsis{Short-hand for generating a static method}           
Method staticMethod(Modifier access, Type ret, str name, list[Formal] args, list[Stat] block)
  = method(methodDesc(ret, name, [a.\type | a <- args]), 
           args, 
           block, 
           modifiers={static(), access});

@synopsis{Short-hand for generating a public static method}           
Method staticMethod(Type ret, str name, list[Formal] args, list[Stat] block)
  = staticMethod(\public, ret, name, args, block);

@synopsis{Short-hand for generating a constructor.}
@pitfalls{Don't forgot to generate a super call.}    
Method constructor(Modifier access, list[Formal] formals, list[Stat] block)
  = method(constructorDesc([ var.\type | var <- formals]), formals, block, modifiers={access});
  
@synopsis{"new" short-hand with parameters}
Exp new(Type class, list[Type] argTypes, list[Exp] args)
  = newInstance(class, constructorDesc(argTypes), args);
  
@synopsis{"new" short-hand, without parameters}
Exp new(Type class) = new(class, [], []);
      
@synopsis{Load the standard "this" reference for every object.} 
@pitfalls{This works only inside non-static methods and inside constructors} 
Exp this() = load("this");

private Type CURRENT = object("\<current\>");

@synopsis{the "<current>" class refers to the class currently being compiled, for convenience's sake.}
Type current() = CURRENT;

@synopsis{Load a field from the currently compiled class}
Exp getField(Type \type, str name) = getField(CURRENT, this(), \type, name);
 
@synopsis{Load a static field from the currently compiled class}  
Exp getStatic(Type \type, str name) = getStatic(CURRENT, \type, name);
  
@synopsis{Store a field in the currently compiled class}  
Stat putField(Type \type, str name, Exp arg) = putField(CURRENT, this(), \type, name, arg);  

@synopsis{Store a static field in the currently defined class}
Stat putStatic(Type \type, str name, Exp arg) = putStatic(CURRENT, name, \type, arg);
 
@synopsis{Invoke a static method on the currently defined class} 
Exp invokeStatic(Signature desc, list[Exp] args) = invokeStatic(CURRENT, desc, args);

@synopsis{Invoke a method on the currently defined class using invokeSpecial} 
Exp invokeSpecial(Exp receiver, Signature desc, list[Exp] args)
  = invokeSpecial(CURRENT, receiver, desc, args);

@synopsis{Invoke a method on the currently defined class using invokeVirtual}
Exp invokeVirtual(Exp receiver, Signature desc, list[Exp] args)
  = invokeVirtual(CURRENT, receiver, desc, args);
  
@synopsis{Invoke a method on the currently defined interface using invokeInterface}  
Exp invokeInterface(Exp receiver, Signature desc, list[Exp] args)
  = invokeVirtual(CURRENT, receiver, desc, args);
   
Exp iconst(int i) = const(integer(), i);
Exp sconst(int i) = const(short(), i);
Exp bconst(int i) = const(byte(), i);
Exp cconst(int i) = const(character(), i);
Exp zconst(bool i) = const(boolean(), i);
Exp jconst(int i) = const(long(), i);
Exp sconst(str i) = const(string(), i);
Exp dconst(real i) = const(double(), i);
Exp fconst(real i) = const(float(), i);

// dynamic invoke needs a lot of extra detail, which is all below this line:

@doc{
A bootstrap handle is a name of a static method (as defined by its host class,
its name and its type signature), and a list of "constant" arguments. 

These "constant"
arguments can be used to declare properties of the call site which can then be used by
the bootstrap method to define in which way the dynamic call must be resolved. So these
argument help to avoid having to define a combinatorially large number of bootstrap methods
(one for each call site situation).  

It's advisable to use the convenience function below to create a `BootstrapCall` instance:
  * `bootstrap(Type class, str name, list[BootstrapInfo] args)`
  
That function makes sure to line up the additional information in the extra arguments about 
the call site with the static type of the static bootstrap method.
} 
data BootstrapCall = bootstrap(Type class, Signature desc, list[CallSiteInfo] args);
 
@synopsis{generate a bootstrap call with all the required standard parameters, and optionally more.}
@benefits{
* A raw BootstrapCall must return a CallSite and take a MethodHandle.Lookup, a string and a MethodType as the first three parameters.    
This convenience function guarantees that this the true, but allows for adding additional static information about
the call site.
* The types of the additional parameters are inferred automatically from the CallSiteInfo structures, so 
you do not have to distribute this information during code generation.
}
@pitfalls{
* the signature of the bootstrap method `name` in `class` (which you might have written in Java, or generated
in a different part of your compiler) must be the exactly the same as generated here.
}        
BootstrapCall bootstrap(Type class, str name, list[CallSiteInfo] args)
  = bootstrap(class,  
      methodDesc(object("java.lang.invoke.CallSite"),
                 name,
                 [
                    object("java.lang.invoke.MethodHandles$Lookup"),
                    string(),
                    object("java.lang.invoke.MethodType"),
                    *[callsiteInfoType(a) | a <- args]
                 ]),
       args);

@synopsis{Generate a basic bootstrap caller with only the minimally required information for a dynamic invoke.}
@benefits{This is the starting point for any use of invokeDynamic. Get this working first and add additional information
later}
@pitfalls{Writing bootstrap method implementations is hard.}
BootstrapCall bootstrap(str name, list[CallSiteInfo] args)
  = bootstrap(object("\<CURRENT\>"), name, args);
  
@synopsis{
Convenience function to use existing BootstrapCall information to generate a fitting bootstrap 
method to call.
}  
@description{
This function mirrors the `bootstrap` function; it generates the method referenced by the output of that function.
}
@benefits{
* the bootstrap method and the bootstrapCall information have to be aligned perfectly. If you use the pair
of functions `bootstrapMethod` and `bootstrap` together then this alignment is guaranteed. 
}
@pitfalls{
* generating the body of a bootstrap method can be challenging. It is recommended to first write the example
in Java and decompile the resulting method, and copy the result into the `body` parameter of this function.
* another solution is to keep the source of the bootstrap method completely in Java, but making sure the 
signatures keep matching inside the BootstrapCall data. This is usually possible; when the bootstrap method
is generic enough.
}
Method bootstrapMethod(BootstrapCall b, list[Stat] body)
  = method(b.desc, 
      [
         var(object("java.lang.invoke.MethodHandles$Lookup"), "callerClass"),
         var(string(), "dynMethodName"),
         var(object("java.lang.invoke.MethodType"), "dynMethodType"),
         *[var(callsiteInfoType(b.args[i]), "info_<i>") | i <- index(b.args)]
      ], 
      body, modifiers={\public(), \static()});
      
     
data CallSiteInfo
  = stringInfo(str s)
  | classInfo(str name)
  | integerInfo(int i)
  | longInfo(int l)
  | floatInfo(real f)
  | doubleInfo(real d)
  | methodTypeInfo(Signature desc)
  | // see MethodHandles.lookup().findVirtual for more information
    virtualHandle(Type class, str name, Signature desc)
  | // see MethodHandles.lookup().findSpecial for more information
    specialHandle(Type class, str name, Signature desc, Type caller)
  | // see MethodHandles.lookup().findGetter for more information
    getterHandle(Type class, str name, Type \type)
  | // see MethodHandles.lookup().findSetter for more information
    setterHandle(Type class, str name, Type \type)
  | // see MethodHandles.lookup().findStaticGetter for more information
    staticGetterHandle(Type class, str name, Type \type)
  | // see MethodHandles.lookup().findStaticSetter for more information
    staticSetterHandle(Type class, str name, Type \type)
  | // see MethodHandles.lookup().findConstructor for more information
    constructorHandle(Type class, Signature desc)
  ;
  
@synopsis{Type inference for callsiteInfo parameters to bootstrap methods.}  
Type callsiteInfoType(stringInfo(_))             = string();
Type callsiteInfoType(classInfo(_))              = object("java.lang.Class");
Type callsiteInfoType(integerInfo(_))            = integer();
Type callsiteInfoType(longInfo(_))               = long();
Type callsiteInfoType(floatInfo(_))              = float();
Type callsiteInfoType(doubleInfo(_))             = double();
Type callsiteInfoType(virtualHandle(_,_,_))      = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(specialHandle(_,_,_,_))    = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(getterHandle(_,_,_))       = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(setterHandle(_,_,_))       = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(staticGetterHandle(_,_,_)) = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(staticSetterHandle(_,_,_)) = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(constructorHandle(_,_))    = object("java.lang.invoke.MethodHandle");
Type callsiteInfoType(methodTypeInfo(_))         = object("java.lang.invoke.MethodType");
