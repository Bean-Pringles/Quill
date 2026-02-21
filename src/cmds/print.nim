var printGlobalCounter* = 0

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

    # Evaluate the expression at compile time
    let (evalResult, evalType, isRuntime) = evalExpression(args[0], vars, target, lineNumber)

    if target in ["exe", "ir", "zip"]:
        var globalStringRef: string
        var globalDecl: string
        var entryCode: string
        var functionDef: string
        var byteCount = 0

        # Detect OS at compile time
        when defined(windows):
            if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                commandsCalled.add("declare ptr @GetStdHandle(i32)")
                globalDecl = "declare ptr @GetStdHandle(i32)\n"
                
            if not ("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                commandsCalled.add("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)")
                globalDecl &= "declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n\n"
        else:
            globalDecl = ""

        # Check if it's a variable reference
        if isRuntime and evalResult in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[evalResult]
            
            # If the variable holds a command result
            if isCommandResult:
                let loadReg = "%loaded_" & evalResult & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" & evalResult & ", align 8\n"
                
                # Extract input buffer number
                var bytesReadGlobal = "@bytesRead0"
                if varValue.contains("bufPtr"):
                    let bufNum = varValue.replace("%bufPtr", "")
                    bytesReadGlobal = "@bytesRead" & bufNum
                
                when defined(windows):
                    let bytesReg = "%bytesRead_" & evalResult & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i32, ptr " & bytesReadGlobal & ", align 4\n"
                    
                    entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                            " = call i32 @WriteFile(ptr %stdout_print" &
                            $printGlobalCounter & ", ptr " & loadReg &
                            ", i32 " & bytesReg & ", ptr %bytes_written_print" &
                            $printGlobalCounter & ", ptr null)\n"
                else:
                    let bytesReg = "%bytesRead_" & evalResult & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i64, ptr " & bytesReadGlobal & ", align 8\n"
                    
                    entryCode &= "  ; Write to stdout (syscall 1)\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                            " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg & ", i64 " & bytesReg & ")\n"
                
                inc printGlobalCounter
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])
            
            # Regular string variable
            elif varType == "ptr" and varValue.startsWith("@.str"):
                let loadReg = "%loaded_" & evalResult & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" & evalResult & ", align 8\n"
                
                when defined(windows):
                    entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                            " = call i32 @WriteFile(ptr %stdout_print" &
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
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])
            
            # Non-string types
            else:
                byteCount = varValue.len + 2
                globalStringRef = "@.strPrint" & $printGlobalCounter
                globalDecl.add(globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & varValue & "\\0A\\00\"")
                
                functionDef = "define i32 @print" & $commandNum & "() {\n"
                functionDef &= "entry:\n"
                functionDef &= "  %str_ptr = getelementptr inbounds [" &
                        $byteCount & " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"
                
                when defined(windows):
                    functionDef &= "  %stdout = call ptr @GetStdHandle(i32 -11)\n"
                    functionDef &= "  %bytes_written = alloca i32, align 4\n"
                    functionDef &= "  %result = call i32 @WriteFile(ptr %stdout, ptr %str_ptr, i32 " &
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

        # Check if it's a direct command result (like %bufPtr0)
        elif evalResult.startsWith("%bufPtr"):
            let bufferPtr = evalResult
            
            var bytesReadGlobal = "@bytesRead0"
            if bufferPtr.contains("bufPtr"):
                let bufNum = bufferPtr.replace("%bufPtr", "")
                bytesReadGlobal = "@bytesRead" & bufNum
            
            entryCode = ""
            
            when defined(windows):
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i32, ptr " & bytesReadGlobal & ", align 4\n"
                
                entryCode &= "  %stdout_print" & $printGlobalCounter & " = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "  %bytes_written_print" & $printGlobalCounter & " = alloca i32, align 4\n"
                entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteFile(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & bufferPtr & ", i32 " &
                        bytesReg & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
            else:
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i64, ptr " & bytesReadGlobal & ", align 8\n"
                
                entryCode &= "  ; Write to stdout (syscall 1)\n"
                entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                entryCode &= "      (i64 1, i64 1, ptr " & bufferPtr & ", i64 " & bytesReg & ")\n"
            
            inc printGlobalCounter
            return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

        # It's a compile-time constant - create global string
        else:
            byteCount = evalResult.len + 2
            globalStringRef = "@.strPrint" & $printGlobalCounter
            globalDecl.add(globalStringRef & " = private constant [" & $byteCount & " x i8] c\"" & evalResult & "\\0A\\00\"")

            # Generate print function
            functionDef = "define i32 @print" & $commandNum & "() {\n"
            functionDef &= "entry:\n"
            functionDef &= "  %str_ptr = getelementptr inbounds [" & $byteCount &
                    " x i8], ptr " & globalStringRef & ", i32 0, i32 0\n"
            
            when defined(windows):
                functionDef &= "  %stdout = call ptr @GetStdHandle(i32 -11)\n"
                functionDef &= "  %bytes_written = alloca i32, align 4\n"
                functionDef &= "  %result = call i32 @WriteFile(ptr %stdout, ptr %str_ptr, i32 " &
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
        # Check if it's a variable or command result
        if isRuntime:
            var batchCommand = "echo !" & evalResult & "!"
            return ("", "", batchCommand, commandsCalled, commandNum, vars, @[])
        else:
            var batchCommand = "echo " & evalResult
            return ("", "", batchCommand, commandsCalled, commandNum, vars, @[])

    elif target == "rust":
        if isRuntime:
            var rustCommand = "println!(\"{}\", " & evalResult & ");"
            return ("", "", rustCommand, commandsCalled, commandNum, vars, @[])
        else:
            var rustCommand = "println!(\"" & evalResult & "\");"
            return ("", "", rustCommand, commandsCalled, commandNum, vars, @[])

    elif target == "python":
        if isRuntime:
            var pythonCommand = "print(" & evalResult & ")"
            return ("", "", pythonCommand, commandsCalled, commandNum, vars, @[])
        else:
            var pythonCommand = "print(\"" & evalResult & "\")"
            return ("", "", pythonCommand, commandsCalled, commandNum, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])