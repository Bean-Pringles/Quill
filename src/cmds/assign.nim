proc isCommand*(arg: string, vars: Table[string, (string, string, int, bool)]): bool =
    # Determine if argument is a command call (not a variable or string literal)
    # String literals have quotes
    # Variables are in the vars table (user-defined Quill variables)
    # Everything else (including evaluated commands like %bufPtr0) is treated as a command
    
    if arg.len == 0:
        return false
    
    var strippedArg = arg.strip()
    
    # Check if it's a quoted string literal
    if strippedArg.len >= 2:
        if (strippedArg[0] == '"' and strippedArg[^1] == '"') or
           (strippedArg[0] == '\'' and strippedArg[^1] == '\''):
            return false
    
    # Check if it's a known user variable in the vars table
    if strippedArg in vars:
        return false
    
    # If it doesn't have quotes and isn't a user variable, it's a command
    # (This includes evaluated commands like %bufPtr0, function calls, etc.)
    return true

var globalStringCounter = 0

proc assignIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)
    if args.len < 2:
        echo "[!] Error on line " & $lineNumber & ": up assign command requires at least 2 arguments"
        quit(1)

    let varName = args[0]
    var value = args[1 ..< args.len].join(" ")
    var globalDecl: string
    var entryCode: string
    var newCommandNum = commandNum

    # Check if value is a command result (starts with %)
    var isCommandResult = value.startsWith("%")
    # Check if value is a variable reference
    var isVariableRef = value in vars

    if target in ["exe", "ir", "zip"]:
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" & varName & "' is not defined."
            quit(1)

        let (llvmType, _, _, isConst) = vars[varName]

        if isConst:
            echo "[!] Error on line " & $lineNumber & ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)
        
        if isCommandResult:
            # Generate a store to update the variable
            vars[varName] = (llvmType, value, 0, true)
            entryCode = "  store ptr " & value & ", ptr %" & varName & ", align 8"
            return ("", "", entryCode, commandsCalled, newCommandNum, vars, @[])

        if isVariableRef:
            # This is a reference to another variable
            # We need to load from the source variable and store to the destination
            let (_, srcValue, srcStrLen, srcIsCommandResult) = vars[value]
            
            # Generate load and store
            let tempReg = "%temp_assign_" & $commandNum
            inc newCommandNum
            
            entryCode = "  " & tempReg & " = load ptr, ptr %" & value & ", align 8\n"
            entryCode &= "  store ptr " & tempReg & ", ptr %" & varName & ", align 8"
            
            # FIXED: Preserve the original buffer reference (srcValue), not tempReg!
            # This ensures that if srcValue is "%bufPtr6", copy also tracks "%bufPtr6"
            # so print can find the correct @bytesRead6
            vars[varName] = (llvmType, srcValue, srcStrLen, srcIsCommandResult)
            
            return ("", "", entryCode, commandsCalled, newCommandNum, vars, @[])

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
            vars[varName] = (llvmType, "@" & globalName, newStrLen, false)
            
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
            vars[varName] = (llvmType, value, 0, false)
            
            # Generate IR code for assignment
            entryCode = "  store " & llvmType & " " & value & ", ptr %" & varName & ", align " & alignment
        
        return (globalDecl, "", entryCode, commandsCalled, newCommandNum, vars, @[])
    
    elif target == "batch":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" & varName & "' is not defined."
            quit(1)
        
        let (varType, _, _, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error on line " & $lineNumber & ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)
        
        if isCommandResult or value.startsWith("input_var"):
            vars[varName] = (varType, value, 0, false)
            let batchCode = "set " & varName & "=!" & value & "!"
            return ("", "", batchCode, commandsCalled, newCommandNum, vars, @[])
        
        if isVariableRef:
            # Variable to variable assignment in batch
            vars[varName] = (varType, value, 0, false)
            let batchCode = "set " & varName & "=!" & value & "!"
            return ("", "", batchCode, commandsCalled, newCommandNum, vars, @[])
        
        var batchValue = value
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                batchValue = value[1 .. ^1]
            if batchValue.len > 0 and (batchValue[^1] == '"' or batchValue[^1] == '\''):
                batchValue = batchValue[0 .. ^2]
        
        vars[varName] = (varType, batchValue, batchValue.len, false)
        let batchCode = "set " & varName & "=" & batchValue
        return ("", "", batchCode, commandsCalled, newCommandNum, vars, @[])
    
    elif target == "rust":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" & varName & "' is not defined."
            quit(1)
        
        let (varType, _, _, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error on line " & $lineNumber & ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)
        
        if isCommandResult or value.startsWith("input_string"):
            vars[varName] = (varType, value, 0, false)
            let rustCode = varName & " = " & value & ".trim().to_string();"
            return ("", "", rustCode, commandsCalled, newCommandNum, vars, @[])
        
        if isVariableRef:
            # Variable to variable assignment
            vars[varName] = (varType, value, 0, false)
            let rustCode = varName & " = " & value & ".clone();"
            return ("", "", rustCode, commandsCalled, newCommandNum, vars, @[])
        
        var rustValue = value
        if varType == "string":
            if value.len > 0 and (value[0] == '"' or value[0] == '\''):
                rustValue = value[1 .. ^1]
            if rustValue.len > 0 and (rustValue[^1] == '"' or rustValue[^1] == '\''):
                rustValue = rustValue[0 .. ^2]
            rustValue = "\"" & rustValue & "\".to_string()"
        
        vars[varName] = (varType, rustValue, rustValue.len, false)
        let rustCode = varName & " = " & rustValue & ";"
        return ("", "", rustCode, commandsCalled, newCommandNum, vars, @[])
    
    elif target == "python":
        if not (varName in vars):
            echo "[!] Error on line " & $lineNumber & ": up Variable '" & varName & "' is not defined."
            quit(1)
        
        let (varType, _, _, isConst) = vars[varName]
        
        if isConst:
            echo "[!] Error on line " & $lineNumber & ": up Cannot assign to constant variable '" & varName & "'."
            quit(1)
        
        if isCommandResult or value.startsWith("input_var"):
            vars[varName] = (varType, value, 0, false)
            let pythonCode = varName & " = " & value & ".strip()"
            return ("", "", pythonCode, commandsCalled, newCommandNum, vars, @[])
        
        if isVariableRef:
            # Variable to variable assignment
            vars[varName] = (varType, value, 0, false)
            let pythonCode = varName & " = " & value
            return ("", "", pythonCode, commandsCalled, newCommandNum, vars, @[])
        
        vars[varName] = (varType, value, value.len, false)
        let pythonCode = varName & " = " & value
        return ("", "", pythonCode, commandsCalled, newCommandNum, vars, @[])
    
    return ("", "", "", commandsCalled, newCommandNum, vars, @[])