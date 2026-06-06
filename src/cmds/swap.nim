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
    
    inc swapBuf
    var entryCode: string
    # Swap Values
    let (var1Type, var1Val, var1StrLen, isMut1) = vars[var1]
    let (var2Type, var2Val, var2StrLen, isMut2) = vars[var2]
    vars[var1] = (var2Type, var2Val, var2StrLen, isMut2)
    vars[var2] = (var1Type, var1Val, var1StrLen, isMut1)


    if not(isMut1 and isMut2):
        var errorVarSwap: string
        
        if not(isMut1):
            errorVarSwap = var1
        elif not(isMut2):
            errorVarSwap = var2

        echo "[!] Error on line " & $lineNumber & ":  The variable " & errorVarSwap & " is unmutable."

    # if target in ["exe", "ir", "zip"]:


    if target == "python":
        entryCode = "swap" & $swapBuf & " = " & $var1Val & "\ndel " & var2 & "\n" & var1 & " = " & var2 & "\n" & var2 & " = " & "swap" & $swapBuf & "\ndel" & "swap" & $swapBuf

    elif target == "batch":
        entryCode = "set swap" & $swapBuf & "=%" & var1 & "%\nset " & var1 & "=%" & var2 & "%\nset " & var2 & "=%swap" & $swapBuf & "%\ndel swap" & $swapBuf

    elif target == "rust":
        entryCode = "let swap" & $swapBuf & " = " & var1 & ";\n" & var1 & " = " & var2 & ";\n" & var2 & " = swap" & $swapBuf    

    return ("", "", entryCode, commandsCalled, commandNum, vars, @[])