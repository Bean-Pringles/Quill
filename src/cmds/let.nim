import tables
import strutils

var globalStringCounter = 0

proc letIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int)], batchMode: bool): (
    string, seq[string], int, Table[string, (string, string, int)]) =
    ## Generates IR for let statement: let x: i32 = 4
    ## args[0] = variable name (x)
    ## args[1] = type (i32)
    ## args[2] = value (4)
    ## vars now stores: (llvmType, value, stringLength) - stringLength only used for strings
    
    if args.len < 3:
        echo "Error: let command requires at least 3 arguments (name, type, value)"
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

    if not batchMode:
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
            
            # Store: global constant name, LLVM type, string length
            vars[varName] = (llvmType, "@" & globalName, strLen)
        else:
            # For non-string types, store directly (strLen = 0 for non-strings)
            vars[varName] = (llvmType, value, 0)
    else:
        # Batch mode: store with original type names
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                value = value[1 .. ^1]
            if value.len > 0 and (value[^1] == '"' or value[^1] == '\''):
                value = value[0 .. ^2]
            
            strLen = value.len
        else:
            strLen = 0
        
        vars[varName] = (varType, value, strLen)

    # Return IR code (global string constants) or empty string for other types
    return (irCode, commandsCalled, commandNum, vars)