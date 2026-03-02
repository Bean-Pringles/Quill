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

    let smallVal = args[0]
    let bigVal = args[1]
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

        # Generate the SSA value in entryCode
        entryCode = "    %" & ssaName & " = call i32 @rand_range(i32 " & smallVal & ", i32 " & bigVal & ")\n"
        
        # Register with "ssa_i32" type so llvmPost skips creating alloca
        vars[ssaName] = ("ssa_i32", "%" & ssaName, 0, false)

        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[ssaName])
    
    elif target == "batch":
        let varName = "randint_" & $randrandintCounter
        let cmd = "SET /A " & varName & "=(%RANDOM% * (" & bigVal & " - " & smallVal & " + 1) / 32768) + " & smallVal
        inc randrandintCounter
        return ("", "", cmd, commandsCalled, newCommandNum, vars, @[varName])
    
    elif target == "rust":
        if "use rand::Rng;" notin commandsCalled:
            commandsCalled.add("use rand::Rng;")
            globalDecl = "use rand::Rng;\n"

        let varName = "randint_" & $randrandintCounter
        entryCode = "let " & varName & ": i32 = rng.gen_range(" & smallVal & ".." & bigVal & ");"
        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[varName])
    
    elif target == "python":
        if "import random" notin commandsCalled:
            commandsCalled.add("import random")
            globalDecl = "import random\n"
        
        let varName = "randint_" & $randrandintCounter
        entryCode = varName & " = random.randint(" & smallVal & ", " & bigVal & ")"
        inc randrandintCounter
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[varName])
    
    return ("", "", "", commandsCalled, commandNum, vars, @[])