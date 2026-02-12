proc constIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int, bool)], cmdVal: seq[string], target: string, lineNumber: int): (
    string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)

    if args.len < 3:
        echo "[!] Error on line " & $lineNumber & ": up const command requires at least 3 arguments (name, type, value)"
        quit(1)
    
    let varName = args[0]
    let varType = args[1]
    var entryCode: string
    var globalDecl: string
    var strLen = 0
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

        # Handle string literals - create global constant
        if varType == "string":
            # FIXED: Check if this is a runtime value from cmdVal (nested input call result)
            # cmdVal[0] contains the buffer pointer (e.g., "%bufPtr0")
            var actualValue = value
            if cmdVal.len > 0 and cmdVal[0] != "":
                # This came from a nested command call (like input)
                actualValue = cmdVal[0]  # FIXED: Use cmdVal[0] instead of cmdVal[2]
            
            # Check if it's a runtime value (starts with %)
            let isRuntimeValue = actualValue.len > 0 and actualValue[0] == '%'
            
            if isRuntimeValue:
                # Don't generate store here - let the parser handle it
                entryCode = ""
                # FIXED: Now actualValue is "%bufPtr0" not empty!
                vars[varName] = (llvmType, actualValue, 0, true)
            else:
                # String literal - create global constant
                var cleanValue = actualValue
                # Remove quotes
                if cleanValue.len > 0 and (cleanValue[0] == '"' or cleanValue[0] == '\''):
                    cleanValue = cleanValue[1 .. ^1]
                if cleanValue.len > 0 and (cleanValue[^1] == '"' or cleanValue[^1] == '\''):
                    cleanValue = cleanValue[0 .. ^2]
                
                strLen = cleanValue.len + 2
                let globalName = ".str" & $globalStringCounter
                inc globalStringCounter
                
                globalDecl = "@" & globalName & " = private constant [" & $strLen & " x i8] c\"" & cleanValue & "\\0A\\00\""
                
                # ✓ GENERATE THE STORE NOW in entryCode
                entryCode = "  store ptr @" & globalName & ", ptr %" & varName & ", align 8"
                
                vars[varName] = (llvmType, "@" & globalName, strLen, false)
        else:
            # For non-string types, store directly (strLen = 0 for non-strings)
            vars[varName] = (llvmType, value, 0, false)

        return (globalDecl, "", entryCode, commandsCalled, commandNum, vars, @[])

    elif target == "batch":
        var batchCode: string
        var cleanValue = value
        
        # Check if the value is a command (like input_var0)
        if isCommand(value, vars):
            # It's a command result - store reference to the input variable
            vars[varName] = (varType, value, 0, true)
            batchCode = "set " & varName & "=!" & value & "!"
        else:
            # It's a literal value
            if varType == "string":
                if cleanValue.len > 0 and (cleanValue[0] == '"' or cleanValue[0] == '\''):
                    cleanValue = cleanValue[1 .. ^1]
                if cleanValue.len > 0 and (cleanValue[^1] == '"' or cleanValue[^1] == '\''):
                    cleanValue = cleanValue[0 .. ^2]
                strLen = cleanValue.len
            else:
                strLen = 0
            
            cleanValue = cleanValue.replace("!", "^!")

            vars[varName] = (varType, cleanValue, strLen, false)
            batchCode = "set " & varName & "=" & cleanValue
        
        return ("", "", batchCode, commandsCalled, commandNum, vars, @[])

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
        return ("", "", rustCode, commandsCalled, commandNum, vars, @[])

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
        return ("", "", pythonCode, commandsCalled, commandNum, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])