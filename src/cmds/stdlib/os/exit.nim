var osexitnum: int = 0

proc osexitIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    
    # Get exit code argument, if any
    var exitCode: string
    var isRuntime: bool = false
    
    if args.len == 0:
        exitCode = "0"
        isRuntime = false
    elif args.len > 1:
        echo "os.exit() takes at most one argument, but got " & $args.len, lineNumber
        quit(1)
    else:
        var (evalResult, _, runtimeFlag) = evalExpression(args[0], vars, target, lineNumber)
        exitCode = evalResult
        isRuntime = runtimeFlag
        
    if target in ["exe", "ir", "zip"]:
        var code: string
        var exitValue: string  # The actual register/value to use
        
        # Resolve the runtime value to an actual register
        if isRuntime:
            if exitCode in vars:
                let (varType, varValue, _, _) = vars[exitCode]
                
                # SSA values are already registers - use directly
                if varType.startsWith("ssa_"):
                    exitValue = varValue  # Already has % prefix like "%randint_0"
                else:
                    # It's a pointer variable - need to load it
                    let loadReg = "%exit_val_" & $osexitnum
                    code &= "    " & loadReg & " = load i32, ptr %" & exitCode & ", align 4\n"
                    exitValue = loadReg
                    inc osexitnum
            else:
                # Raw register or expression - use as-is
                exitValue = exitCode
        else:
            # Compile-time constant - use as literal
            exitValue = exitCode
        
        when defined(windows):
            code &= "    ret i32 " & exitValue & "\n"
        else:
            # Linux - need to use the exit value in the syscall
            # syscall 60 is exit, exit code goes in %rdi
            if isRuntime:
                let exitExt = "%exit_ext_" & $osexitnum
                code &= "    " & exitExt & " = sext i32 " & exitValue & " to i64\n"
                code &= "    call void asm sideeffect \"movq $0, %rdi; movl $$60, %eax; syscall\", \"r,~{dirflag},~{fpsr},~{flags}\"(i64 " & exitExt & ")\n"
                inc osexitnum
            else:
                code &= "    call void asm sideeffect \"movl $$60, %eax; movl $$" & exitValue & ", %edi; syscall\", \"~{dirflag},~{fpsr},~{flags}\"()\n"

        return ("", "", code, commandsCalled, commandNum + 1, vars, @[])

    elif target == "batch":
        var code: string
        
        if isRuntime:
            # Runtime variable - reference it with %varname%
            code = "exit /b %" & exitCode & "%\n"
        else:
            # Literal value
            code = "exit /b " & exitCode & "\n"
        
        return ("", "", code, commandsCalled, commandNum + 1, vars, @[])

    elif target == "rust":
        var functionsDef: string
        var code: string

        if "use std::process;" notin commandsCalled:
            commandsCalled.add("use std::process;")
            functionsDef &= "use std::process;\n"

        if isRuntime:
            # Runtime variable - use variable name directly, cast to i32
            code = "process::exit(" & exitCode & " as i32);\n"
        else:
            # Literal value
            code = "process::exit(" & exitCode & ");\n"

        return ("", functionsDef, code, commandsCalled, commandNum + 1, vars, @[])
    
    elif target == "python":
        var functionsDef: string
        var code: string

        if "import sys" notin commandsCalled:
            commandsCalled.add("import sys")
            functionsDef &= "import sys\n"

        if isRuntime:
            # Runtime variable - use variable name directly
            code = "sys.exit(" & exitCode & ")\n"
        else:
            # Literal value
            code = "sys.exit(" & exitCode & ")\n"

        return ("", functionsDef, code, commandsCalled, commandNum + 1, vars, @[])