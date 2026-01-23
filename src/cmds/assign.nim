var globalStringCounter = 0

proc assignIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    target: string
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars)

    if args.len < 2:
        echo "[!] Error: assign command requires at least 2 arguments"
        return ("", "", "", commandsCalled, commandNum, vars)

    let varName = args[0]
    var value = args[1]
    var globalDecl = ""
    var entryCode = ""

    if target in ["exe", "ir", "zip"]:
        if not (varName in vars):
            echo "[!] Error: Variable '" & varName & "' is not defined."
            return ("", "", "", commandsCalled, commandNum, vars)

        let (llvmType, _, strLen, isConst) = vars[varName]

        if isConst:
            echo "[!] Error: Cannot assign to constant variable '" & varName & "'."
            return ("", "", "", commandsCalled, commandNum, vars)

        # Handle string assignment - need to create a new global constant
        if llvmType == "ptr":
            # Remove quotes
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            
            # Calculate string length (original + \n + \00)
            let newStrLen = value.len + 2
            
            # Create global string constant
            let globalName = ".str" & $globalStringCounter
            inc globalStringCounter
            
            # Generate global constant declaration
            globalDecl = "@" & globalName & " = private constant [" & $newStrLen & " x i8] c\"" & value & "\\0A\\00\""
            
            # Update variable to point to new global
            vars[varName] = (llvmType, "@" & globalName, newStrLen, isConst)
            
            # Store the new global reference
            entryCode = "  store ptr @" & globalName & ", ptr %" & varName & ", align 8"
        else:
            # For non-string types, store the value directly
            var alignment = case llvmType
            of "i1": "1"
            of "i8": "1"
            of "i16": "2"
            of "i32": "4"
            of "i64": "8"
            of "f32": "4"
            of "f64": "8"
            else: "8"

            # Update the variable value in the table
            vars[varName] = (llvmType, value, 0, isConst)
            
            # Generate IR code for assignment
            entryCode = "  store " & llvmType & " " & value & ", ptr %" & varName & ", align " & alignment
        
        return (globalDecl, "", entryCode, commandsCalled, commandNum, vars)
    
    elif target == "batch":
        # Batch assignment
        if not (varName in vars):
            echo "[!] Error: Variable '" & varName & "' is not defined."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        let (varType, _, strLen, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error: Cannot assign to constant variable '" & varName & "'."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        var batchValue = value
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                batchValue = value[1 .. ^1]
            if batchValue.len > 0 and (batchValue[^1] == '"' or batchValue[^1] == '\''):
                batchValue = batchValue[0 .. ^2]
        
        vars[varName] = (varType, batchValue, batchValue.len, isConst)
        let batchCode = "set " & varName & "=" & batchValue
        return ("", "", batchCode, commandsCalled, commandNum, vars)
    
    elif target == "rust":
        if not (varName in vars):
            echo "[!] Error: Variable '" & varName & "' is not defined."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        let (varType, _, strLen, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error: Cannot assign to constant variable '" & varName & "'."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        var rustValue = value
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                rustValue = value[1 .. ^1]
            if rustValue.len > 0 and (rustValue[^1] == '"' or rustValue[^1] == '\''):
                rustValue = rustValue[0 .. ^2]
            rustValue = "\"" & rustValue & "\".to_string()"
        
        vars[varName] = (varType, rustValue, rustValue.len, isConst)
        let rustCode = varName & " = " & rustValue & ";"
        return ("", "", rustCode, commandsCalled, commandNum, vars)
    
    elif target == "python":
        if not (varName in vars):
            echo "[!] Error: Variable '" & varName & "' is not defined."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        let (varType, _, strLen, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error: Cannot assign to constant variable '" & varName & "'."
            return ("", "", "", commandsCalled, commandNum, vars)
        
        vars[varName] = (varType, value, value.len, isConst)
        let pythonCode = varName & " = " & value
        return ("", "", pythonCode, commandsCalled, commandNum, vars)
    
    return ("", "", "", commandsCalled, commandNum, vars)