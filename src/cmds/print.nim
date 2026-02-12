var printGlobalCounter = 0

proc printIRGenerator*(
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

    if args.len == 0:
        return ("", "", "", commandsCalled, commandNum, vars, @[])

    if target in ["exe", "ir", "zip"]:
        var globalStringRef: string
        var globalDecl: string
        var entryCode: string
        var functionDef: string
        var byteCount = 0
        var needsNewGlobal = true

        # Detect OS at compile time
        when defined(windows):
            if printGlobalCounter == 0:
                if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                    commandsCalled.add("declare ptr @GetStdHandle(i32)")
                    globalDecl = "declare ptr @GetStdHandle(i32)\n"
                
                if not ("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                    commandsCalled.add("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)")
                    globalDecl &= "declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)\n\n"
        
        else:
            # Linux doesn't need declarations for inline syscalls
            globalDecl = ""

        # First check if it's a variable
        if args[0] in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[args[0]]
            # If the variable holds a command result, load from it and print
            if isCommandResult:
                # Need to load from the variable to get the buffer pointer
                let loadReg = "%loaded_" & args[0] & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" & args[0] & ", align 8\n"
                
                # Extract input buffer number to find corresponding bytesRead
                # If varValue is "%bufPtr0", we need "@bytesRead0"
                var bytesReadGlobal = "@bytesRead0"  # default
                if varValue.contains("bufPtr"):
                    let bufNum = varValue.replace("%bufPtr", "")
                    bytesReadGlobal = "@bytesRead" & bufNum
                
                when defined(windows):
                    # Load the actual bytes read
                    let bytesReg = "%bytesRead_" & args[0] & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i32, ptr " & bytesReadGlobal & ", align 4\n"
                    
                    entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                            " = call i32 @WriteConsoleA(ptr %stdout_print" &
                            $printGlobalCounter & ", ptr " & loadReg &
                            ", i32 " & bytesReg & ", ptr %bytes_written_print" &
                            $printGlobalCounter & ", ptr null)\n"
                else:
                    # Load the actual bytes read (i64 for Linux)
                    let bytesReg = "%bytesRead_" & args[0] & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i64, ptr " & bytesReadGlobal & ", align 8\n"
                    
                    entryCode &= "  ; Write to stdout (syscall 1)\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                            " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg & ", i64 " & bytesReg & ")\n"
                
                inc printGlobalCounter
                return ("", "", entryCode, commandsCalled, commandNum + 1, vars, @[])
                
            # If it's a regular string variable, generate inline code to load and print
            elif varType == "ptr" and varValue.startsWith("@.str"):
                # Generate inline code similar to command results
                let loadReg = "%loaded_" & args[0] & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" & args[0] & ", align 8\n"
                
                when defined(windows):
                    entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                            " = call i32 @WriteConsoleA(ptr %stdout_print" &
                            $printGlobalCounter & ", ptr " & loadReg & ", i32 " &
                            $strLength & ", ptr %bytes_written_print" &
                            $printGlobalCounter & ", ptr null)\n"
                else:
                    entryCode &= "  ; Write to stdout (syscall 1)\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                            " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg & ", i64 " & $strLength & ")\n"
                
                inc printGlobalCounter
                return ("", "", entryCode, commandsCalled, commandNum + 1, vars, @[])
            else:
                # For non-string types, convert to string
                var strValue = varValue
                byteCount = strValue.len + 2
                globalStringRef = "@.strPrint" & $printGlobalCounter
                globalDecl.add(globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\"")
                
                # Generate function here
                functionDef = "define i32 @print" & $commandNum & "() {\n"
                functionDef &= "entry:\n"
                functionDef &= "  %str_ptr = getelementptr inbounds [" &
                        $byteCount & " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"
                
                when defined(windows):
                    functionDef &= "  %stdout = call ptr @GetStdHandle(i32 -11)\n"
                    functionDef &= "  %bytes_written = alloca i32, align 4\n"
                    functionDef &= "  %result = call i32 @WriteConsoleA(ptr %stdout, ptr %str_ptr, i32 " &
                            $byteCount & ", ptr %bytes_written, ptr null)\n"
                else:
                    functionDef &= "  ; Write to stdout (syscall 1)\n"
                    functionDef &= "  %writeResult = call i64 asm sideeffect \"syscall\",\n"
                    functionDef &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    functionDef &= "      (i64 1, i64 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
                
                functionDef &= "  ret i32 0\n"
                functionDef &= "}"
                
                inc printGlobalCounter
                return (globalDecl, functionDef, "", commandsCalled, commandNum + 1, vars, @[])

        # Check if argument is a command (not a variable)
        elif isCommand(args[0], vars):
            let bufferPtr = args[0]
            
            # Extract buffer number to find bytesRead
            var bytesReadGlobal = "@bytesRead0"
            if bufferPtr.contains("bufPtr"):
                let bufNum = bufferPtr.replace("%bufPtr", "")
                bytesReadGlobal = "@bytesRead" & bufNum
            
            entryCode = ""
            
            when defined(windows):
                # Load actual bytes read
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i32, ptr " & bytesReadGlobal & ", align 4\n"
                
                entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteConsoleA(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & bufferPtr & ", i32 " &
                        bytesReg & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
            else:
                # Load actual bytes read (i64 for Linux)
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i64, ptr " & bytesReadGlobal & ", align 8\n"
                
                entryCode &= "  ; Write to stdout (syscall 1)\n"
                entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                entryCode &= "      (i64 1, i64 1, ptr " & bufferPtr & ", i64 " & bytesReg & ")\n"
            
            inc printGlobalCounter
            return ("", "", entryCode, commandsCalled, commandNum + 1, vars, @[])

        # If it's not a command or variable, it must be a literal string
        else:
            var strValue = args[0]
            if strValue.len >= 2 and strValue[0] == '(' and strValue[^1] == ')':
                strValue = strValue[1 .. ^2]

            let hasQuotes = (strValue.len >= 2 and
                            ((strValue[0] == '"' and strValue[^1] == '"') or
                             (strValue[0] == '\'' and strValue[^1] == '\'')))

            if not hasQuotes:
                echo "[!] Error on line " & $lineNumber & ": Print statement requires quotes"
                return ("", "", "", commandsCalled, commandNum, vars, @[])

            strValue = strValue[1 .. ^2]
            byteCount = strValue.len + 2
            globalStringRef = "@.strPrint" & $printGlobalCounter
            globalDecl.add(globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & strValue & "\\0A\\00\"")

        # Generate print function for non-command values
        functionDef = "define i32 @print" & $commandNum & "() {\n"
        functionDef &= "entry:\n"
        functionDef &= "  %str_ptr = getelementptr inbounds [" & $byteCount &
                " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"
        
        when defined(windows):
            functionDef &= "  %stdout = call ptr @GetStdHandle(i32 -11)\n"
            functionDef &= "  %bytes_written = alloca i32, align 4\n"
            functionDef &= "  %result = call i32 @WriteConsoleA(ptr %stdout, ptr %str_ptr, i32 " &
                    $byteCount & ", ptr %bytes_written, ptr null)\n"
        else:
            functionDef &= "  ; Write to stdout (syscall 1)\n"
            functionDef &= "  %writeResult = call i64 asm sideeffect \"syscall\",\n"
            functionDef &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
            functionDef &= "      (i64 1, i64 1, ptr %str_ptr, i64 " & $byteCount & ")\n"
        
        functionDef &= "  ret i32 0\n"
        functionDef &= "}"

        inc printGlobalCounter
        return (globalDecl, functionDef, "", commandsCalled, commandNum + 1, vars, @[])

    elif target == "batch":
        # Check if it's a variable first
        if args[0] in vars:
            var batchCommand = "echo !" & args[0] & "!"
            return ("", "", batchCommand, commandsCalled, commandNum, vars, @[])

        elif isCommand(args[0], vars):
            let varName = args[0]
            var batchCommand = "echo !" & varName & "!"
            return ("", "", batchCommand, commandsCalled, commandNum, vars, @[])

        else:
            var printStatement = args[0]
            if printStatement.len > 0 and printStatement[0] == '(':
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and printStatement[^1] == ')':
                printStatement = printStatement[0 .. ^2]

            let hasQuotes = (printStatement.len >= 2 and
                            ((printStatement[0] == '"' and printStatement[^1] == '"') or
                             (printStatement[0] == '\'' and printStatement[^1] == '\'')))

            if not hasQuotes:
                echo "[!] Error on line " & $lineNumber & ": Print statement requires quotes"
                return ("", "", "", commandsCalled, commandNum, vars, @[])

            printStatement = printStatement[1 .. ^2]
            var batchCommand = "echo " & printStatement
            return ("", "", batchCommand, commandsCalled, commandNum, vars, @[])

    elif target == "rust":
        if args[0] in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[args[0]]
            var rustCommand = "println!(\"{}\", " & args[0] & ");"
            return ("", "", rustCommand, commandsCalled, commandNum, vars, @[])

        elif isCommand(args[0], vars):
            let varName = args[0]
            var rustCommand = "println!(\"{}\", " & varName & ");"
            return ("", "", rustCommand, commandsCalled, commandNum, vars, @[])

        else:
            var printStatement = args[0]
            if printStatement.len > 0 and printStatement[0] == '(':
                printStatement = printStatement[1 .. ^1]
            if printStatement.len > 0 and printStatement[^1] == ')':
                printStatement = printStatement[0 .. ^2]

            let hasQuotes = (printStatement.len >= 2 and
                            ((printStatement[0] == '"' and printStatement[^1] == '"') or
                             (printStatement[0] == '\'' and printStatement[^1] == '\'')))

            if not hasQuotes:
                echo "[!] Error on line " & $lineNumber & ": Print statement requires quotes"
                return ("", "", "", commandsCalled, commandNum, vars, @[])

            printStatement = printStatement[1 .. ^2]
            var rustCommand = "println!(\"" & printStatement & "\");"
            return ("", "", rustCommand, commandsCalled, commandNum, vars, @[])

    elif target == "python":
        if args[0] in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[args[0]]
            var pythonCommand = "print(" & args[0] & ")"
            return ("", "", pythonCommand, commandsCalled, commandNum, vars, @[])

        elif isCommand(args[0], vars):
            let varName = args[0]
            var pythonCommand = "print(" & varName & ")"
            return ("", "", pythonCommand, commandsCalled, commandNum, vars, @[])

        else:
            var printStatement = args[0]
            if printStatement.len >= 2 and printStatement[0] == '(' and printStatement[^1] == ')':
                printStatement = printStatement[1 .. ^2]

            let hasQuotes = (printStatement.len >= 2 and
                            ((printStatement[0] == '"' and printStatement[^1] == '"') or
                             (printStatement[0] == '\'' and printStatement[^1] == '\'')))

            if not hasQuotes:
                echo "[!] Error on line " & $lineNumber & ": Print statement requires quotes"
                return ("", "", "", commandsCalled, commandNum, vars, @[])

            printStatement = printStatement[1 .. ^2]
            var pythonCommand = "print(\"" & printStatement & "\")"
            return ("", "", pythonCommand, commandsCalled, commandNum, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])