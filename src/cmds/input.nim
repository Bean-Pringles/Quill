var inputBufferCounter: int

proc inputIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)

    if args.len == 0:
        echo "[!] Error on line " & $lineNumber & ": input command requires a prompt"
        quit(1)

    let prompt = args[0]

    if target in ["exe", "ir", "zip"]:
        var globalDecl = ""
        var entryCode = ""
        
        # Create unique buffer for THIS input only
        let bufferName = "inputBuf" & $inputBufferCounter
        let bufferGlobal = "@" & bufferName
        let bytesReadName = "bytesRead" & $inputBufferCounter  # Track bytes read per input
        
        # Detect OS at compile time
        when defined(windows):
            # Only generate these on FIRST input call
            if inputBufferCounter == 0:
                globalDecl &= "@STD_INPUT_HANDLE  = constant i32 -10\n"
                globalDecl &= "@STD_OUTPUT_HANDLE = constant i32 -11\n\n"
                
                if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                    commandsCalled.add("declare ptr @GetStdHandle(i32)")
                    globalDecl &= "declare ptr @GetStdHandle(i32)\n\n"
                
                if not ("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                    commandsCalled.add("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)")
                    globalDecl &= "declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)\n\n"
                
                globalDecl &= "declare i32 @ReadConsoleA(\n"
                globalDecl &= "   ptr, ptr, i32, ptr, ptr\n"
                globalDecl &= ")\n\n"
                
                # Generate handle retrieval ONCE in entry code
                entryCode &= "    %hstdout = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "    %hstdin = call ptr @GetStdHandle(i32 -10)\n\n"
            
            # Remove quotes from prompt
            var cleanPrompt = prompt
            if cleanPrompt.len >= 2 and (cleanPrompt[0] == '"' or cleanPrompt[0] == '\''):
                cleanPrompt = cleanPrompt[1..^2]
            
            let promptLen = cleanPrompt.len + 2
            
            # Generate prompt string, UNIQUE buffer, and bytes read tracker for this input
            globalDecl &= "@inputPrompt" & $inputBufferCounter & " = global [" & $promptLen & " x i8] c\"" & cleanPrompt & "\\0A\\00\"\n"
            globalDecl &= bufferGlobal & " = global [64 x i8] zeroinitializer\n"
            globalDecl &= "@" & bytesReadName & " = global i32 0\n"  # Per-input bytes read
            
            # Generate input code
            entryCode &= "    %inputPrompt" & $inputBufferCounter & "Ptr = getelementptr [" & $promptLen & " x i8], ptr @inputPrompt" & $inputBufferCounter & ", i64 0, i64 0\n"
            entryCode &= "    call i32 @WriteConsoleA(\n"
            entryCode &= "        ptr %hstdout,\n"
            entryCode &= "        ptr %inputPrompt" & $inputBufferCounter & "Ptr,\n"
            entryCode &= "        i32 " & $promptLen & ",\n"
            entryCode &= "        ptr @" & bytesReadName & ",\n"
            entryCode &= "        ptr null\n"
            entryCode &= "    )\n\n"
            
            # Use the UNIQUE buffer for this specific input
            entryCode &= "    %bufPtr" & $inputBufferCounter & " = getelementptr [64 x i8], ptr " & bufferGlobal & ", i64 0, i64 0\n"
            entryCode &= "    call i32 @ReadConsoleA(\n"
            entryCode &= "        ptr %hstdin,\n"
            entryCode &= "        ptr %bufPtr" & $inputBufferCounter & ",\n"
            entryCode &= "        i32 63,\n"
            entryCode &= "        ptr @" & bytesReadName & ",\n"
            entryCode &= "        ptr null\n"
            entryCode &= "    )\n"
            
        else:            
            # Remove quotes from prompt
            var cleanPrompt = prompt
            if cleanPrompt.len >= 2 and (cleanPrompt[0] == '"' or cleanPrompt[0] == '\''):
                cleanPrompt = cleanPrompt[1..^2]
            
            let promptLen = cleanPrompt.len + 1  # +1 for newline
            
            # Generate prompt string, UNIQUE buffer, and bytes read global for this input
            globalDecl &= "@inputPrompt" & $inputBufferCounter & " = private unnamed_addr constant [" & $promptLen & " x i8] c\"" & cleanPrompt & "\\0A\"\n"
            globalDecl &= bufferGlobal & " = global [64 x i8] zeroinitializer\n"
            globalDecl &= "@" & bytesReadName & " = global i64 0\n"  # Store actual bytes read (i64 for syscall return)
            
            # Write prompt to stdout using syscall
            entryCode &= "    ; Write prompt to stdout (syscall 1)\n"
            entryCode &= "    %promptPtr" & $inputBufferCounter & " = getelementptr [" & $promptLen & " x i8], ptr @inputPrompt" & $inputBufferCounter & ", i64 0, i64 0\n"
            entryCode &= "    %writeResult" & $inputBufferCounter & " = call i64 asm sideeffect \"syscall\",\n"
            entryCode &= "        \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
            entryCode &= "        (i64 1, i64 1, ptr %promptPtr" & $inputBufferCounter & ", i64 " & $promptLen & ")\n\n"
            
            # Read from stdin using syscall and SAVE the result
            entryCode &= "    ; Read from stdin (syscall 0)\n"
            entryCode &= "    %bufPtr" & $inputBufferCounter & " = getelementptr [64 x i8], ptr " & bufferGlobal & ", i64 0, i64 0\n"
            entryCode &= "    %readResult" & $inputBufferCounter & " = call i64 asm sideeffect \"syscall\",\n"
            entryCode &= "        \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
            entryCode &= "        (i64 0, i64 0, ptr %bufPtr" & $inputBufferCounter & ", i64 64)\n"
            # SAVE the bytes read count!
            entryCode &= "    store i64 %readResult" & $inputBufferCounter & ", ptr @" & bytesReadName & ", align 8\n\n"
        
        # Return the buffer pointer AND bytes read global as cmdVal
        let bufferPtr = "%bufPtr" & $inputBufferCounter
        let bytesReadGlobal = "@" & bytesReadName
        inc inputBufferCounter  # Increment after using the current value
        return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[bufferPtr, bytesReadGlobal])

    elif target == "batch":
        let inputVarName = "input_var" & $inputBufferCounter
        var cleanPrompt = prompt
        if cleanPrompt.len >= 2:
            cleanPrompt = cleanPrompt[1..^2]
        var batchCode = "set /p " & inputVarName & "=" & cleanPrompt
        inc inputBufferCounter  # Increment after using the current value
        return ("", "", batchCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    elif target == "rust":
        var functionsDef: string
        var cleanPrompt = prompt
        var rustCode: string
        
        if cleanPrompt.len >= 2:
            cleanPrompt = cleanPrompt[1..^2]
        
        if not ("use std::io;" in commandsCalled):
            functionsDef = "use std::io;\n"
            commandsCalled.add("use std::io;")
        
        if not ("use std::io::Write;" in commandsCalled):
            functionsDef.add("use std::io::Write;\n")
            commandsCalled.add("use std::io::Write;")

        rustCode &= "print!(\"" & cleanPrompt & "\");\n"
        rustCode &= "let mut __stdout = io::stdout();\n"
        rustCode &= "__stdout.flush().unwrap();\n"

        let inputVarName = "input_string" & $inputBufferCounter
        rustCode &= "let mut " & inputVarName & " = String::new();\n"
        rustCode &= "io::stdin().read_line(&mut " & inputVarName & ").unwrap();\n"

        inc inputBufferCounter
        return ("", functionsDef, rustCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    elif target == "python":
        let inputVarName = "input_var" & $inputBufferCounter
        var cleanPrompt = prompt
        if cleanPrompt.len >= 2:
            cleanPrompt = cleanPrompt[1..^2]
        var pythonCode = inputVarName & " = input(\"" & cleanPrompt & "\")"
        inc inputBufferCounter  # Increment after using the current value
        return ("", "", pythonCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    return ("", "", "", commandsCalled, commandNum, vars, @[])