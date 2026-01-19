var printGlobalCounter = 0

proc printIRGenerator(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int)],
    target: string
): (string, seq[string], int, Table[string, (string, string, int)]) =

    if args.len == 0:
        return ("", commandsCalled, commandNum, vars)

    if target in ["exe", "ir", "zip"]:
        var globalStringRef = ""
        var byteCount = 0
        var needsNewGlobal = true
        
        # Check if argument is a variable
        if args[0] in vars:
            let (varType, varValue, strLength) = vars[args[0]]
            
            # If it's a string variable, use the existing global constant
            if varType == "ptr" and varValue.startsWith("@.str"):
                globalStringRef = varValue
                byteCount = strLength
                needsNewGlobal = false
            else:
                # For non-string types, we need to convert to string
                # This is a limitation - LLVM IR printing of integers requires more complex code
                # For now, treat the value as a string to print
                var strValue = varValue
                byteCount = strValue.len + 2
                globalStringRef = "@.strPrint" & $printGlobalCounter
                inc printGlobalCounter
                
                var irString = globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\"\n\n"
                needsNewGlobal = false
                
                # Generate print function
                irString &= "define i32 @print" & $commandNum & "() {\n"
                irString &= "entry:\n"
                irString &= "    %str_ptr = getelementptr inbounds [" & $byteCount & " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"

                when defined(linux):
                    irString &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
                    irString &= "    ret i32 0\n"
                    irString &= "}\n"
                    
                    if "print" notin commandsCalled:
                        commandsCalled.add("print")
                        irString = "declare i64 @write(i32, ptr, i64)\n\n" & irString
                
                elif defined(windows):
                    irString &= "    %stdout = call ptr @GetStdHandle(i32 -11)\n"
                    irString &= "    %bytes_written = alloca i32, align 4\n"
                    irString &= "    %result = call i32 @WriteFile(ptr %stdout, ptr %str_ptr, i32 " & $byteCount & ", ptr %bytes_written, ptr null)\n"
                    irString &= "    ret i32 0\n"
                    irString &= "}\n"
                    
                    if "print" notin commandsCalled:
                        commandsCalled.add("print")
                        irString = "declare ptr @GetStdHandle(i32)\ndeclare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n\n" & irString
                
                else:
                    irString &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
                    irString &= "    ret i32 0\n"
                    irString &= "}\n"
                    
                    if "print" notin commandsCalled:
                        commandsCalled.add("print")
                        irString = "declare i64 @write(i32, ptr, i64)\n\n" & irString

                return (irString, commandsCalled, commandNum + 1, vars)
        
        # Create new global string constant if needed (for literal strings)
        var irString = ""
        
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
            
            irString = globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\"\n\n"
        
        # Generate print function
        irString &= "define i32 @print" & $commandNum & "() {\n"
        irString &= "entry:\n"
        irString &= "    %str_ptr = getelementptr inbounds [" & $byteCount & " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"

        # Platform-specific syscall
        when defined(linux):
            irString &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
            irString &= "    ret i32 0\n"
            irString &= "}\n"
            
            # Only declare write syscall once
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                irString = "declare i64 @write(i32, ptr, i64)\n\n" & irString
        
        elif defined(windows):
            irString &= "    %stdout = call ptr @GetStdHandle(i32 -11)\n"
            irString &= "    %bytes_written = alloca i32, align 4\n"
            irString &= "    %result = call i32 @WriteFile(ptr %stdout, ptr %str_ptr, i32 " & $byteCount & ", ptr %bytes_written, ptr null)\n"
            irString &= "    ret i32 0\n"
            irString &= "}\n"
            
            # Only declare Windows API functions once
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                irString = "declare ptr @GetStdHandle(i32)\ndeclare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n\n" & irString
        
        else:
            # Fallback to write syscall for other Unix-like systems
            irString &= "    %result = call i64 @write(i32 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
            irString &= "    ret i32 0\n"
            irString &= "}\n"
            
            if "print" notin commandsCalled:
                commandsCalled.add("print")
                irString = "declare i64 @write(i32, ptr, i64)\n\n" & irString

        return (irString, commandsCalled, commandNum + 1, vars)

    elif target == "batch":
        # In batch mode, just generate echo command
        var printStatement = args[0]  # Default to the argument itself
        
        # Strip parentheses if present
        if printStatement.len > 0 and printStatement[0] == '(':
            printStatement = printStatement[1 .. ^1]
        if printStatement.len > 0 and printStatement[^1] == ')':
            printStatement = printStatement[0 .. ^2]
        
        if printStatement in vars:
            let (varType, varValue, strLength) = vars[printStatement]

            printStatement = varValue
        else:
            # Remove quotes if it's a string literal
            if printStatement.len > 0 and (printStatement[0] == '"' or printStatement[0] == '\''):
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and (printStatement[^1] == '"' or printStatement[^1] == '\''):
                printStatement = printStatement[0 .. ^2]
        
        var batchCommand = "echo " & printStatement
        return (batchCommand, commandsCalled, commandNum, vars)

    elif target == "rust":
        # In rust mode, just generate echo command
        var printStatement = args[0]  # Default to the argument itself
        
        # Strip parentheses if present
        if printStatement.len > 0 and printStatement[0] == '(':
            printStatement = printStatement[1 .. ^1]
        if printStatement.len > 0 and printStatement[^1] == ')':
            printStatement = printStatement[0 .. ^2]
        
        var rustCommand: string

        if printStatement in vars:
            # It's a variable — print it directly without quotes
            rustCommand = "println!(\"{}\", " & printStatement & ");"
        else:
            # It's a literal — remove surrounding quotes if present
            if printStatement.len > 0 and (printStatement[0] == '"' or printStatement[0] == '\''):
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and (printStatement[^1] == '"' or printStatement[^1] == '\''):
                printStatement = printStatement[0 .. ^2]
            
            rustCommand = "println!(" & printStatement & ");"

        return (rustCommand, commandsCalled, commandNum, vars)