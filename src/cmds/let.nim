proc letIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int, bool)], cmdVal: seq[string], target: string, lineNumber: int): (
    string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)

    if args.len < 3:
        echo "[!] Error on line " & $lineNumber & ": up let command requires at least 3 arguments (name, type, value)"
        quit(1)
    
    let varName = args[0]
    let varType = args[1]
    var entryCode: string
    var globalDecl: string
    var value = args[2 ..< args.len].join(" ")

    if varName in commandsCalled:
        echo "[!] Error on line " & $lineNumber & ": up Variable '" & varName & "' is being redefined."
        quit(1)

    # Add to commands called to prevent redefinition
    commandsCalled.add(varName)

    if target in ["exe", "ir", "zip"]:
        # Map language types to LLVM types
        var llvmType = case varType
            of "string": "ptr"
            of "i32": "i32"
            of "i64": "i64"
            of "f32": "float"
            of "f64": "double"
            of "bool": "i1"
            else: varType

        if varType == "string":
            # Check if this is a runtime value from cmdVal (nested input call result)
            var actualValue = value
            if cmdVal.len > 0 and cmdVal[0] != "":
                actualValue = cmdVal[0]
            
            # Check if it's a runtime value (starts with %)
            let isRuntimeValue = actualValue.len > 0 and actualValue[0] == '%'
            
            if isRuntimeValue:
                entryCode = ""
                vars[varName] = (llvmType, actualValue, 0, true)
            else:
                # Evaluate the expression at compile time
                let (evalResult, evalType, isRuntime) = evalExpression(actualValue, vars, target, lineNumber)
                
                if isRuntime:
                    # It's a variable reference
                    vars[varName] = (llvmType, evalResult, 0, true)
                    entryCode = ""
                else:
                    # It's a compile-time constant
                    let strLen = evalResult.len + 2
                    let globalName = ".str" & $globalStringCounter
                    inc globalStringCounter
                    
                    globalDecl = "@" & globalName & " = private constant [" & $strLen & " x i8] c\"" & evalResult & "\\0A\\00\""
                    entryCode = "  store ptr @" & globalName & ", ptr %" & varName & ", align 8"
                    vars[varName] = (llvmType, "@" & globalName, strLen, false)
        else:
            # Evaluate numeric expression at compile time
            let (evalResult, evalType, isRuntime) = evalExpression(value, vars, target, lineNumber)
            vars[varName] = (llvmType, evalResult, 0, false)
            entryCode = ""

        return (globalDecl, "", entryCode, commandsCalled, commandNum, vars, @[])

    elif target == "batch":
        var batchCode: string
        
        # Evaluate expression
        let (evalResult, evalType, isRuntime) = evalExpression(value, vars, target, lineNumber)
        
        # Check if the value is a command (like input_var0)
        if evalResult.startsWith("input_var") or isCommand(evalResult, vars):
            vars[varName] = (varType, evalResult, 0, true)
            batchCode = "set " & varName & "=!" & evalResult & "!"
        else:
            let cleanValue = evalResult.replace("!", "^!")
            vars[varName] = (varType, cleanValue, cleanValue.len, false)
            batchCode = "set " & varName & "=" & cleanValue
        
        return ("", "", batchCode, commandsCalled, commandNum, vars, @[])

    elif target == "rust":
        let (evalResult, evalType, isRuntime) = evalExpression(value, vars, target, lineNumber)
        
        var rustType = case varType
            of "string": "String"
            of "i32": "i32"
            of "i64": "i64"
            of "f32": "f32"
            of "f64": "f64"
            of "bool": "bool"
            else: varType

        var rustVal = evalResult
        if varType == "string" and not isRuntime:
            rustVal = "\"" & evalResult & "\".to_string()"
        elif varType == "string" and evalResult.startsWith("input_string"):
            rustVal = evalResult & ".trim().to_string()"
        
        vars[varName] = (varType, evalResult, evalResult.len, false)
        let rustCode = "let mut " & varName & ": " & rustType & " = " & rustVal & ";"
        return ("", "", rustCode, commandsCalled, commandNum, vars, @[])

    elif target == "python":
        let (evalResult, evalType, isRuntime) = evalExpression(value, vars, target, lineNumber)
        
        var pythonType = case varType
        of "string": "str"
        of "i32", "i64": "int"
        of "f32", "f64": "float"
        of "bool": "bool"
        else: varType

        var pythonVal = evalResult
        if varType == "string" and not isRuntime and not evalResult.startsWith("input_var"):
            pythonVal = "\"" & evalResult & "\""
        
        vars[varName] = (varType, evalResult, evalResult.len, false)
        let pythonCode = varName & ": " & pythonType & " = " & pythonVal
        return ("", "", pythonCode, commandsCalled, commandNum, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])