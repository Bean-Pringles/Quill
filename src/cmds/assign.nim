var globalStringCounter = 0

proc assignIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string,
        int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)
    if args.len < 2:
        echo "[!] Error on line " & $lineNumber & ": up assign command requires at least 2 arguments"
        quit(1)

    let varName = args[0]
    var value = args[1 ..< args.len].join(" ")
    var globalDecl: string
    var entryCode: string
    var newCommandNum = commandNum

    if target in ["exe", "ir", "zip"]:
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" &
                    varName & "' is not defined."
            quit(1)

        let (llvmType, _, _, isConst) = vars[varName]

        if isConst:
            echo "[!] Error on line " & $lineNumber &
                    ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)

        # Evaluate the expression
        let (evalResult, evalType, isRuntime) = evalExpression(value, vars,
                target, lineNumber)

        # Check if it's a command result (starts with %)
        if evalResult.startsWith("%"):
            vars[varName] = (llvmType, evalResult, 0, true)
            entryCode = "  store ptr " & evalResult & ", ptr %" & varName & ", align 8"
            return ("", "", entryCode, commandsCalled, newCommandNum, vars, @[])

        # Check if it's a variable reference
        if isRuntime and evalResult in vars:
            let (_, srcValue, srcStrLen, srcIsCommandResult) = vars[evalResult]

            let tempReg = "%temp_assign_" & $commandNum
            inc newCommandNum

            entryCode = "  " & tempReg & " = load ptr, ptr %" & evalResult & ", align 8\n"
            entryCode &= "  store ptr " & tempReg & ", ptr %" & varName & ", align 8"

            vars[varName] = (llvmType, srcValue, srcStrLen, srcIsCommandResult)

            return ("", "", entryCode, commandsCalled, newCommandNum, vars, @[])

        # Handle compile-time evaluated expressions
        if llvmType == "ptr":
            let newStrLen = evalResult.len + 2
            let globalName = ".str" & $globalStringCounter
            inc globalStringCounter

            globalDecl = "@" & globalName & " = private constant [" &
                    $newStrLen & " x i8] c\"" & evalResult & "\\0A\\00\""
            vars[varName] = (llvmType, "@" & globalName, newStrLen, false)
            entryCode = "  store ptr @" & globalName & ", ptr %" & varName & ", align 8"
        else:
            var alignment = case llvmType
            of "i1": "1"
            of "i8": "1"
            of "i16": "2"
            of "i32": "4"
            of "i64": "8"
            of "f32": "4"
            of "f64": "8"
            else: "8"

            vars[varName] = (llvmType, evalResult, 0, false)
            entryCode = "  store " & llvmType & " " & evalResult & ", ptr %" &
                    varName & ", align " & alignment

        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars,
                @[])

    elif target == "batch":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" &
                    varName & "' is not defined."
            quit(1)

        let (varType, _, _, isConst) = vars[varName]

        if isConst:
            echo "[!] Error on line " & $lineNumber &
                    ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)

        let (evalResult, evalType, isRuntime) = evalExpression(value, vars,
                target, lineNumber)

        if evalResult.startsWith("input_var") or isRuntime:
            vars[varName] = (varType, evalResult, 0, false)
            let batchCode = "set " & varName & "=!" & evalResult & "!"
            return ("", "", batchCode, commandsCalled, newCommandNum, vars, @[])

        vars[varName] = (varType, evalResult, evalResult.len, false)
        let batchCode = "set " & varName & "=" & evalResult
        return ("", "", batchCode, commandsCalled, newCommandNum, vars, @[])

    elif target == "rust":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" &
                    varName & "' is not defined."
            quit(1)

        let (varType, _, _, isConst) = vars[varName]

        if isConst:
            echo "[!] Error on line " & $lineNumber &
                    ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)

        let (evalResult, evalType, isRuntime) = evalExpression(value, vars,
                target, lineNumber)

        if evalResult.startsWith("input_string") or isRuntime:
            vars[varName] = (varType, evalResult, 0, false)
            if evalType == "string":
                let rustCode = varName & " = " & evalResult & ".trim().to_string();"
                return ("", "", rustCode, commandsCalled, newCommandNum, vars,
                        @[])
            else:
                let rustCode = varName & " = " & evalResult & ";"
                return ("", "", rustCode, commandsCalled, newCommandNum, vars,
                        @[])

        var rustValue = evalResult
        if varType == "string":
            rustValue = "\"" & evalResult & "\".to_string()"

        vars[varName] = (varType, rustValue, rustValue.len, false)
        let rustCode = varName & " = " & rustValue & ";"
        return ("", "", rustCode, commandsCalled, newCommandNum, vars, @[])

    elif target == "python":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" &
                    varName & "' is not defined."
            quit(1)

        let (varType, _, _, isConst) = vars[varName]

        if isConst:
            echo "[!] Error on line " & $lineNumber &
                    ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)

        let (evalResult, evalType, isRuntime) = evalExpression(value, vars,
                target, lineNumber)

        if evalResult.startsWith("input_var") or isRuntime:
            vars[varName] = (varType, evalResult, 0, false)
            let pythonCode = varName & " = " & evalResult
            return ("", "", pythonCode, commandsCalled, newCommandNum, vars, @[])

        vars[varName] = (varType, evalResult, evalResult.len, false)
        let pythonCode = varName & " = " & evalResult
        return ("", "", pythonCode, commandsCalled, newCommandNum, vars, @[])

    return ("", "", "", commandsCalled, newCommandNum, vars, @[])
