module lang::mujava::api::System

import lang::mujava::Syntax;

// print object to System.out (toString() is called automatically)    
Stat stdout(Exp arg)
   = \do(println("out", arg));

// print object to System.err (toString() is called automatically)
Stat stderr(Exp arg)
   = \do(println("err", arg));

// not-public because it depends on the magic constants "err" and "out" to work         
private Exp println(str stream, Exp arg)
   = invokeVirtual(reference("java.io.PrintStream"), getStatic(reference("java.lang.System"), reference("java.io.PrintStream"), stream), 
         methodDesc(\void(), "println", [object()]), [arg]);         