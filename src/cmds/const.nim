proc constIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int, bool)], target: string, lineNumber: int): (
    string, string, string, seq[string], int, Table[string, (string, string, int, bool)]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars)

    if args.len < 3:
        echo "[!] Error on line " & $lineNumber & ": up const command requires at least 3 arguments (name, type, value)"
        quit(1)
    
    let varName = args[0]
    let varType = args[1]
    var value = args[2 ..< args.len].join(" ")
    var globalDecl = ""
    var strLen = 0

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

        # Handle string literals - create global constant
        if varType == "string":
            # Remove quotes
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            
            # Calculate string length (original + \n + \00)
            strLen = value.len + 2
            
            # Create global string constant
            let globalName = ".str" & $globalStringCounter
            inc globalStringCounter
            
            # Generate global constant declaration
            globalDecl = "@" & globalName & " = private constant [" & $strLen & " x i8] c\"" & value & "\\0A\\00\""

            # Store: global constant name, LLVM type, string length, isConst
            vars[varName] = (llvmType, "@" & globalName, strLen, true)
        else:
            # For non-string types, store directly (strLen = 0 for non-strings)
            vars[varName] = (llvmType, value, 0, true)
        
        return (globalDecl, "", "", commandsCalled, commandNum, vars)
    
    elif target == "batch":
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            strLen = value.len
        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen, true)
        return ("", "", "", commandsCalled, commandNum, vars)

    elif target == "rust":
        var rustVal = value
        var rustType = case varType
            of "string": "String"
            of "i32": "i32"
            of "i64": "i64"
            of "f32": "f32"
            of "f64": "f64"
            of "bool": "bool"
            else: varType

        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            strLen = value.len
            rustVal = rustVal & ".to_string()"
        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen, true)
        let rustCode = "let " & varName & ": " & rustType & " = " & rustVal & ";"
        return ("", "", rustCode, commandsCalled, commandNum, vars)

    elif target == "python":
        var pythonVal = value
        var pythonType = case varType
        of "string": "str"
        of "i32", "i64": "int"
        of "f32", "f64": "float"
        of "bool": "bool"
        else: varType

        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            strLen = value.len
        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen, true)
        let pythonCode = varName & ": " & pythonType & " = " & pythonVal
        return ("", "", pythonCode, commandsCalled, commandNum, vars)

    return ("", "", "", commandsCalled, commandNum, vars)