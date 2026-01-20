var globalStringCounter = 0

proc constIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int, bool)], target: string): (
    string, seq[string], int, Table[string, (string, string, int, bool)]) =
    ## Generates IR for const statement: const x: i32 = 4
    ## args[0] = variable name (x)
    ## args[1] = type (i32)
    ## args[2] = value (4)
    ## vars now stores: (llvmType, value, stringLength, isConst) - stringLength only used for strings

    if args.len < 3:
        echo "Error: const command requires at least 3 arguments (name, type, value)"
        return ("", commandsCalled, commandNum, vars)
    
    let varName = args[0]
    let varType = args[1]
    var value = args[2 ..< args.len].join(" ")
    var irCode = ""
    var strLen = 0

    if varName in commandsCalled:
        echo "[!] Error: Variable '" & varName & "' is being redefined."
        return ("", commandsCalled, commandNum, vars)

    # Add to commands called to prevent redefinition (do this in both modes)
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
            else: varType  # Pass through unknown types

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
            irCode = "@" & globalName & " = private constant [" & $strLen & " x i8] c\"" & value & "\\0A\\00\"\n"

            # Store: global constant name, LLVM type, string length, isConst
            vars[varName] = (llvmType, "@" & globalName, strLen, true)
        else:
            # For non-string types, store directly (strLen = 0 for non-strings)
            vars[varName] = (llvmType, value, 0, true)
    
    elif target == "batch":
        # Batch mode: store with original type names
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            
            strLen = value.len
        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen, true)

    elif target == "rust":
        # Rust mode: store with original type names
        var rustVal = value
        var rustType = case varType
            of "string": "String"
            of "i32": "i32"
            of "i64": "i64"
            of "f32": "f32"
            of "f64": "f64"
            of "bool": "bool"
            else: varType  # Pass through unknown types

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

        irCode = "let " & varName & ": " & rustType & " = " & rustVal & ";"

    elif target == "python":
        # Python mode: store with original type names
        var pythonVal = value
        var pythonType = case varType
        of "string": "str"
        of "i32", "i64": "int"
        of "f32", "f64": "float"
        of "bool": "bool"
        else: varType  # Pass through unknown types

        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            
            strLen = value.len

        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen, true)

        irCode = varName & ": " & pythonType & " = " & pythonVal

    # Return IR code (global string constants) or empty string for other types
    return (irCode, commandsCalled, commandNum, vars)