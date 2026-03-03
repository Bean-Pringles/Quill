var randrandintCounter = 0

proc randrandintIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    
    if args.len < 2:
        echo "[!] Error on line " & $lineNumber & ": randint command requires at least 2 arguments"
        quit(1)

    # Evaluate arguments to handle both compile-time and runtime values
    var (minVal, _, isMinRuntime) = evalExpression(args[0], vars, target, lineNumber)
    var (maxVal, _, isMaxRuntime) = evalExpression(args[1], vars, target, lineNumber)
    
    var globalDecl: string = ""
    var newCommandNum = commandNum
    var entryCode: string = ""
    
    let ssaName = "randint_" & $randrandintCounter

    if target in ["exe", "ir", "zip"]:
        # Add PRNG functions
        if "makeSeed" notin commandsCalled:
            commandsCalled.add("makeSeed")
            globalDecl = "define i32 @make_seed() {\nentry:\n    %a = alloca i32\n    %addr = ptrtoint i32* %a to i32\n\n    ; xorshift scramble\n    %s1 = xor i32 %addr, 61\n    %s2 = lshr i32 %s1, 16\n    %s3 = xor i32 %s1, %s2\n    %s4 = mul i32 %s3, 9\n    %s5 = lshr i32 %s4, 4\n    %s6 = xor i32 %s4, %s5\n    %s7 = mul i32 %s6, 666444093\n    %s8 = lshr i32 %s7, 15\n    %result = xor i32 %s7, %s8\n\n    ret i32 %result\n}\n\n"
        
        if "prngFunc" notin commandsCalled:
            commandsCalled.add("prngFunc")
            globalDecl &= "define i32 @lcg_next(i32 %seed) {\nentry:\n    %mul = mul i32 %seed, 1664525\n    %add = add i32 %mul, 1013904223\n    ret i32 %add\n}\n\n"

        if "randRangeFunc" notin commandsCalled:
            commandsCalled.add("randRangeFunc")
            globalDecl &= "define i32 @rand_range(i32 %min, i32 %max) {\nentry:\n    %seed = call i32 @make_seed()\n    %next = call i32 @lcg_next(i32 %seed)\n\n    %range = sub i32 %max, %min\n    %range1 = add i32 %range, 1\n\n    %mod = urem i32 %next, %range1\n    %result = add i32 %mod, %min\n\n    ret i32 %result\n}\n\n"

        # Resolve runtime arguments to actual registers
        var minArg: string
        var maxArg: string
        
        if isMinRuntime:
            if minVal in vars:
                let (varType, varValue, _, _) = vars[minVal]
                if varType.startsWith("ssa_"):
                    minArg = varValue  # Already has % prefix
                else:
                    let loadReg = "%randmin_" & $randrandintCounter
                    entryCode &= "    " & loadReg & " = load i32, ptr %" & minVal & ", align 4\n"
                    minArg = loadReg
            else:
                minArg = minVal
        else:
            minArg = minVal
        
        if isMaxRuntime:
            if maxVal in vars:
                let (varType, varValue, _, _) = vars[maxVal]
                if varType.startsWith("ssa_"):
                    maxArg = varValue  # Already has % prefix
                else:
                    let loadReg = "%randmax_" & $randrandintCounter
                    entryCode &= "    " & loadReg & " = load i32, ptr %" & maxVal & ", align 4\n"
                    maxArg = loadReg
            else:
                maxArg = maxVal
        else:
            maxArg = maxVal

        # Generate the SSA value in entryCode
        entryCode &= "    %" & ssaName & " = call i32 @rand_range(i32 " & minArg & ", i32 " & maxArg & ")\n"
        
        # Register with "ssa_i32" type so llvmPost skips creating alloca
        vars[ssaName] = ("ssa_i32", "%" & ssaName, 0, false)

        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[ssaName])
    
    elif target == "batch":
        let varName = "randint_" & $randrandintCounter
        let cmd = "SET /A " & varName & "=(%RANDOM% * (" & maxVal & " - " & minVal & " + 1) / 32768) + " & minVal & "\n"
        
        # Add to vars so it can be referenced by other commands
        vars[varName] = ("i32", varName, 0, false)
        
        inc randrandintCounter
        return ("", "", cmd, commandsCalled, newCommandNum, vars, @[varName])

    elif target == "rust":
        if "use rand::Rng;" notin commandsCalled:
            commandsCalled.add("use rand::Rng;")
            globalDecl = "use rand::Rng;\n"

        let varName = "randint_" & $randrandintCounter
        entryCode = "let " & varName & ": i32 = rand::thread_rng().gen_range(" & minVal & "..=" & maxVal & ");\n"
        
        # Add to vars so it can be referenced by other commands
        vars[varName] = ("i32", varName, 0, false)
        
        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[varName])

    elif target == "python":
        if "import random" notin commandsCalled:
            commandsCalled.add("import random")
            globalDecl = "import random\n"
        
        let varName = "randint_" & $randrandintCounter
        entryCode = varName & " = random.randint(" & minVal & ", " & maxVal & ")\n"
        
        # Add to vars so it can be referenced by other commands
        vars[varName] = ("i32", varName, 0, false)
        
        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[varName])