var printGlobalCounter = 0

proc printIRGenerator(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    target: string, 
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars)

    if args.len == 0:
        return ("", "", "", commandsCalled, commandNum, vars)

    if target in ["exe", "ir", "zip"]:
        var globalStringRef = ""
        var byteCount = 0
        var needsNewGlobal = true
        var globalDecl = ""
        var functionDef = ""
        
        # Check if argument is a variable
        if args[0] in vars:
            let (varType, varValue, strLength, _) = vars[args[0]]
            
            # If it's a string variable, use the existing global constant
            if varType == "ptr" and varValue.startsWith("@.str"):
                globalStringRef = varValue
                byteCount = strLength
                needsNewGlobal = false
            else:
                # For non-string types, we need to convert to string
                var strValue = varValue
                byteCount = strValue.len + 2
                globalStringRef = "@.strPrint" & $printGlobalCounter
                inc printGlobalCounter
                
                # Create global string constant
                globalDecl = globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\""
                needsNewGlobal = false
        
        # Create new global string constant if needed (for literal strings)
        if needsNewGlobal:
            # Remove quotes if present
            var strValue = args[0]
            if strValue.len > 0 and (strValue[0] == '"' or strValue[0] == '\''):
                strValue = strValue[1 .. ^1]
            if strValue.len > 0 and (strValue[^1] == '"' or strValue[^1] == '\''):
                strValue = strValue[0 .. ^2]
            
            byteCount = strValue.len + 2  # +1 for \n, +1 for \00
            globalStringRef = "@.strPrint" & $printGlobalCounter
            inc printGlobalCounter
            
            globalDecl = globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\""
        
        # Generate print function
        functionDef = "define i32 @print" & $commandNum & "() {\n"
        functionDef &= "entry:\n"
        functionDef &= "    %str_ptr = getelementptr inbounds [" & $byteCount & " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"

        # Platform-specific syscall
        when defined(linux):
            functionDef &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
            functionDef &= "    ret i32 0\n"
            functionDef &= "}"
            
            # Only declare write syscall once
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                if globalDecl != "":
                    globalDecl = "declare i64 @write(i32, ptr, i64)\n" & globalDecl
                else:
                    globalDecl = "declare i64 @write(i32, ptr, i64)"
        
        elif defined(windows):
            functionDef &= "    %stdout = call ptr @GetStdHandle(i32 -11)\n"
            functionDef &= "    %bytes_written = alloca i32, align 4\n"
            functionDef &= "    %result = call i32 @WriteFile(ptr %stdout, ptr %str_ptr, i32 " & $byteCount & ", ptr %bytes_written, ptr null)\n"
            functionDef &= "    ret i32 0\n"
            functionDef &= "}"
            
            # Only declare Windows API functions once
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                if globalDecl != "":
                    globalDecl = "declare ptr @GetStdHandle(i32)\ndeclare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n" & globalDecl
                else:
                    globalDecl = "declare ptr @GetStdHandle(i32)\ndeclare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)"
        
        else:
            # Fallback to write syscall for other Unix-like systems
            functionDef &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
            functionDef &= "    ret i32 0\n"
            functionDef &= "}"
            
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                if globalDecl != "":
                    globalDecl = "declare i64 @write(i32, ptr, i64)\n" & globalDecl
                else:
                    globalDecl = "declare i64 @write(i32, ptr, i64)"

        return (globalDecl, functionDef, "", commandsCalled, commandNum + 1, vars)

    elif target == "batch":
        # In batch mode, just generate echo command
        var printStatement = args[0]
        
        if printStatement.len > 0 and printStatement[0] == '(':
            printStatement = printStatement[1 .. ^1]
        if printStatement.len > 0 and printStatement[^1] == ')':
            printStatement = printStatement[0 .. ^2]
        
        if printStatement in vars:
            let (varType, varValue, strLength, _) = vars[printStatement]
            printStatement = varValue
        else:
            if printStatement.len > 0 and (printStatement[0] == '"' or printStatement[0] == '\''):
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and (printStatement[^1] == '"' or printStatement[^1] == '\''):
                printStatement = printStatement[0 .. ^2]
        
        var batchCommand = "echo " & printStatement
        return ("", "", batchCommand, commandsCalled, commandNum, vars)

    elif target == "rust":
        var printStatement = args[0]
        
        if printStatement.len > 0 and printStatement[0] == '(':
            printStatement = printStatement[1 .. ^1]
        if printStatement.len > 0 and printStatement[^1] == ')':
            printStatement = printStatement[0 .. ^2]
        
        var rustCommand: string

        if printStatement in vars:
            rustCommand = "println!(\"{}\", " & printStatement & ");"
        else:
            if printStatement.len > 0 and (printStatement[0] == '"' or printStatement[0] == '\''):
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and (printStatement[^1] == '"' or printStatement[^1] == '\''):
                printStatement = printStatement[0 .. ^2]
            rustCommand = "println!(\"" & printStatement & "\");"

        return ("", "", rustCommand, commandsCalled, commandNum, vars)

    elif target == "python":
        var printStatement = args[0]
        var pythonCommand: string
        
        if printStatement.len >= 2 and printStatement[0] == '(' and printStatement[^1] == ')':
            printStatement = printStatement[1 .. ^2]

        if not (printStatement in vars):
            if printStatement.len >= 2 and ((printStatement[0] == '"' and printStatement[^1] == '"') or
                                            (printStatement[0] == '\'' and printStatement[^1] == '\'')):
                printStatement = printStatement[1 .. ^2]
            pythonCommand = "print(\"" & printStatement & "\")"
        else:
            pythonCommand = "print(" & printStatement & ")"

        return ("", "", pythonCommand, commandsCalled, commandNum, vars)