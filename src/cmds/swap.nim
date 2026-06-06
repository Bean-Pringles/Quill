var swapBuf*: int = 0

proc swapIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)

    if args.len != 2:
        echo "[!] Error on line " & $lineNumber & ": swap command requires two variables"
        quit(1)

    let var1: string = args[0]
    let var2: string = args[1]
    
    if not ((var1 in vars) and (var2 in vars)):
        var errorVar: string

        if not ((var1 in vars)):
            errorVar = var1
        else:
            errorVar = var2
        
        echo "[!] Error on line " & $lineNumber & ": The variable " & $errorVar & "is not declared."
        quit(1)
    
    inc swapBuf
    var entryCode: string
    # Swap Values
    let (var1Type, var1Val, var1StrLen, isConst1) = vars[var1]
    let (var2Type, var2Val, var2StrLen, isConst2) = vars[var2]
    vars[var1] = (var2Type, var2Val, var2StrLen, isConst2)
    vars[var2] = (var1Type, var1Val, var1StrLen, isConst1)

    echo isConst1
    echo isConst2

    if (isConst1 and isConst2):
        var errorVarSwap: string
        
        if isConst1:
            errorVarSwap = var1
        elif isConst2:
            errorVarSwap = var2

        echo "[!] Error on line " & $lineNumber & ":  The variable " & errorVarSwap & " is unmutable."
        quit(1)

    if var1Type != var2Type:
        echo "[!] Error on line " & $lineNumber & ": The variables " & var1 & " and " & var2 & " are of different types."
        quit(1)
    
    if target in ["exe", "ir", "zip"]:
        entryCode = "; LLVM IR swap\n" &
            "  \n%swap" & $swapBuf & " = alloca i32\n" &
            "  store i32 %" & var1 & ", i32* %swap" & $swapBuf & "\n" &
            "  %" & var1 & "_val = load i32, i32* %" & var2 & "\n" &
            "  store i32 %" & var1 & "_val, i32* %" & var1 & "\n" &
            "  %" & var2 & "_val = load i32, i32* %swap" & $swapBuf & "\n" &
            "  \nstore i32 %" & var2 & "_val, i32* %" & var2

    elif target == "python":
        entryCode = "swap" & $swapBuf & " = " & $var1Val & "\ndel " & var2 & "\n" & var1 & " = " & var2 & "\n" & var2 & " = " & "swap" & $swapBuf & "\ndel" & "swap" & $swapBuf

    elif target == "batch":
        entryCode = "set swap" & $swapBuf & "=%" & var1 & "%\nset " & var1 & "=%" & var2 & "%\nset " & var2 & "=%swap" & $swapBuf & "%\ndel swap" & $swapBuf

    elif target == "rust":
        entryCode = "let swap" & $swapBuf & " = " & var1 & ";\n" & var1 & " = " & var2 & ";\n" & var2 & " = swap" & $swapBuf    

    return ("", "", entryCode, commandsCalled, commandNum, vars, @[])