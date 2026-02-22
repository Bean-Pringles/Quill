var inputBufferCounter*: int = 0

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

    var inputType = "string"  # Default type

    # Check if type is specified (e.g., input("Enter number", int))
    if args.len >= 2:
        inputType = args[1].toLowerAscii()

    if target in ["exe", "ir", "zip"]:
        var globalDecl = ""
        var entryCode = ""

        # Resolve the prompt argument exactly like print resolves its argument.
        let (evalResult, _, isRuntime) = evalExpression(args[0], vars, target, lineNumber)

        # Create unique buffer / bytes-read globals for THIS input call.
        let bufferName    = "inputBuf"  & $inputBufferCounter
        let bufferGlobal  = "@" & bufferName
        let bytesReadName = "bytesRead" & $inputBufferCounter

        # ── string-to-integer helper (emitted once) ───────────────────────
        if inputType == "int" and not ("string_to_i32_func" in commandsCalled):
            commandsCalled.add("string_to_i32_func")
            globalDecl &= """
; Convert string to i32
define i32 @string_to_i32(ptr %str, i32 %len) {
entry:
    %result = alloca i32, align 4
    store i32 0, ptr %result, align 4
    %is_negative = alloca i1, align 1
    store i1 false, ptr %is_negative, align 1
    %index = alloca i32, align 4
    store i32 0, ptr %index, align 4

    ; Check for negative sign
    %first_char = load i8, ptr %str, align 1
    %is_minus = icmp eq i8 %first_char, 45
    br i1 %is_minus, label %set_negative, label %parse_loop

set_negative:
    store i1 true, ptr %is_negative, align 1
    store i32 1, ptr %index, align 4
    br label %parse_loop

parse_loop:
    %idx = load i32, ptr %index, align 4
    %continue = icmp slt i32 %idx, %len
    br i1 %continue, label %check_digit, label %finalize_result

check_digit:
    %char_ptr = getelementptr i8, ptr %str, i32 %idx
    %char = load i8, ptr %char_ptr, align 1

    ; Check if it's a digit (ASCII 48-57)
    %is_digit = icmp uge i8 %char, 48
    %is_digit2 = icmp ule i8 %char, 57
    %valid_digit = and i1 %is_digit, %is_digit2
    br i1 %valid_digit, label %process_digit, label %finalize_result

process_digit:
    %digit_val = sub i8 %char, 48
    %digit = zext i8 %digit_val to i32

    %current = load i32, ptr %result, align 4
    %mul_result = mul i32 %current, 10
    %new_result = add i32 %mul_result, %digit
    store i32 %new_result, ptr %result, align 4

    %next_idx = add i32 %idx, 1
    store i32 %next_idx, ptr %index, align 4
    br label %parse_loop

finalize_result:
    %final = load i32, ptr %result, align 4
    %neg = load i1, ptr %is_negative, align 1
    %negated = sub i32 0, %final
    %output = select i1 %neg, i32 %negated, i32 %final
    ret i32 %output
}

"""

        # ── platform-level declarations (mirrors print's guards) ──────────
        when defined(windows):
            if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                commandsCalled.add("declare ptr @GetStdHandle(i32)")
                globalDecl &= "declare ptr @GetStdHandle(i32)\n"

            if not ("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                commandsCalled.add("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)")
                globalDecl &= "declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n\n"

            if not ("declare_ReadConsoleA" in commandsCalled):
                commandsCalled.add("declare_ReadConsoleA")
                globalDecl &= "declare i32 @ReadConsoleA(\n"
                globalDecl &= "   ptr, ptr, i32, ptr, ptr\n"
                globalDecl &= ")\n\n"

        # ── stdin buffer + bytes-read global (always needed) ──────────────
        globalDecl &= bufferGlobal & " = global [64 x i8] zeroinitializer\n"
        when defined(windows):
            globalDecl &= "@" & bytesReadName & " = global i32 0\n"
        else:
            globalDecl &= "@" & bytesReadName & " = global i64 0\n"

        # ════════════════════════════════════════════════════════════════════
        # PROMPT EMISSION — mirrors print's variable/constant branching
        # ════════════════════════════════════════════════════════════════════

        if isRuntime and evalResult in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[evalResult]

            # ── ptr variable pointing to a known string literal ───────────
            if varType == "ptr" and varValue.startsWith("@.str"):
                let loadReg = "%prompt_ptr_" & $inputBufferCounter
                entryCode &= "  " & loadReg & " = load ptr, ptr %" &
                    evalResult & ", align 8\n"

                when defined(windows):
                    entryCode &= "  %stdout_input" & $inputBufferCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_input" & $inputBufferCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_input" & $inputBufferCounter &
                        " = call i32 @WriteFile(ptr %stdout_input" &
                        $inputBufferCounter & ", ptr " & loadReg & ", i32 " &
                        $strLength & ", ptr %bytes_written_input" &
                        $inputBufferCounter & ", ptr null)\n\n"
                else:
                    entryCode &= "  %writeResult_input" & $inputBufferCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg &
                        ", i64 " & $strLength & ")\n\n"

            # ── command result / dynamic buffer ───────────────────────────
            elif isCommandResult:
                let loadReg = "%prompt_ptr_" & $inputBufferCounter
                entryCode &= "  " & loadReg & " = load ptr, ptr %" &
                    evalResult & ", align 8\n"

                var bytesReadGlobal = "@bytesRead0"
                if varValue.contains("bufPtr"):
                    let bufNum = varValue.replace("%bufPtr", "")
                    bytesReadGlobal = "@bytesRead" & bufNum

                when defined(windows):
                    let bytesReg = "%prompt_bytes_" & $inputBufferCounter
                    entryCode &= "  " & bytesReg & " = load i32, ptr " &
                        bytesReadGlobal & ", align 4\n"
                    entryCode &= "  %stdout_input" & $inputBufferCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_input" & $inputBufferCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_input" & $inputBufferCounter &
                        " = call i32 @WriteFile(ptr %stdout_input" &
                        $inputBufferCounter & ", ptr " & loadReg & ", i32 " &
                        bytesReg & ", ptr %bytes_written_input" &
                        $inputBufferCounter & ", ptr null)\n\n"
                else:
                    let bytesReg = "%prompt_bytes_" & $inputBufferCounter
                    entryCode &= "  " & bytesReg & " = load i64, ptr " &
                        bytesReadGlobal & ", align 8\n"
                    entryCode &= "  %writeResult_input" & $inputBufferCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg &
                        ", i64 " & bytesReg & ")\n\n"

            # ── fallback: var's known compile-time value used as prompt ───
            else:
                let promptLen = varValue.len + 2  # \0A + \00
                let promptRef = "@inputPrompt" & $inputBufferCounter
                globalDecl &= promptRef & " = private constant [" & $promptLen &
                    " x i8] c\"" & varValue & "\\0A\\00\"\n"

                when defined(windows):
                    entryCode &= "  %stdout_input" & $inputBufferCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %str_ptr_input" & $inputBufferCounter &
                        " = getelementptr inbounds [" & $promptLen & " x i8], ptr " &
                        promptRef & ", i32 0, i32 0\n"
                    entryCode &= "  %bytes_written_input" & $inputBufferCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_input" & $inputBufferCounter &
                        " = call i32 @WriteFile(ptr %stdout_input" &
                        $inputBufferCounter & ", ptr %str_ptr_input" &
                        $inputBufferCounter & ", i32 " & $promptLen &
                        ", ptr %bytes_written_input" & $inputBufferCounter &
                        ", ptr null)\n\n"
                else:
                    entryCode &= "  %str_ptr_input" & $inputBufferCounter &
                        " = getelementptr inbounds [" & $promptLen & " x i8], ptr " &
                        promptRef & ", i32 0, i32 0\n"
                    entryCode &= "  %writeResult_input" & $inputBufferCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr %str_ptr_input" &
                        $inputBufferCounter & ", i64 " & $promptLen & ")\n\n"

        # ── direct buffer pointer (e.g. %bufPtr0 passed as prompt) ────────
        elif isRuntime and evalResult.startsWith("%bufPtr"):
            var bytesReadGlobal = "@bytesRead0"
            if evalResult.contains("bufPtr"):
                let bufNum = evalResult.replace("%bufPtr", "")
                bytesReadGlobal = "@bytesRead" & bufNum

            when defined(windows):
                let bytesReg = "%prompt_bytes_" & $inputBufferCounter
                entryCode &= "  " & bytesReg & " = load i32, ptr " &
                    bytesReadGlobal & ", align 4\n"
                entryCode &= "  %stdout_input" & $inputBufferCounter &
                    " = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "  %bytes_written_input" & $inputBufferCounter &
                    " = alloca i32, align 4\n"
                entryCode &= "  %result_input" & $inputBufferCounter &
                    " = call i32 @WriteFile(ptr %stdout_input" &
                    $inputBufferCounter & ", ptr " & evalResult & ", i32 " &
                    bytesReg & ", ptr %bytes_written_input" &
                    $inputBufferCounter & ", ptr null)\n\n"
            else:
                let bytesReg = "%prompt_bytes_" & $inputBufferCounter
                entryCode &= "  " & bytesReg & " = load i64, ptr " &
                    bytesReadGlobal & ", align 8\n"
                entryCode &= "  %writeResult_input" & $inputBufferCounter &
                    " = call i64 asm sideeffect \"syscall\",\n"
                entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                entryCode &= "      (i64 1, i64 1, ptr " & evalResult &
                    ", i64 " & bytesReg & ")\n\n"

        # ── compile-time constant string ───────────────────────────────────
        else:
            let promptLen = evalResult.len + 2   # \0A + \00
            let promptRef = "@inputPrompt" & $inputBufferCounter
            globalDecl &= promptRef & " = private constant [" & $promptLen &
                " x i8] c\"" & evalResult & "\\0A\\00\"\n"

            when defined(windows):
                entryCode &= "  %stdout_input" & $inputBufferCounter &
                    " = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "  %str_ptr_input" & $inputBufferCounter &
                    " = getelementptr inbounds [" & $promptLen & " x i8], ptr " &
                    promptRef & ", i32 0, i32 0\n"
                entryCode &= "  %bytes_written_input" & $inputBufferCounter &
                    " = alloca i32, align 4\n"
                entryCode &= "  %result_input" & $inputBufferCounter &
                    " = call i32 @WriteFile(ptr %stdout_input" &
                    $inputBufferCounter & ", ptr %str_ptr_input" &
                    $inputBufferCounter & ", i32 " & $promptLen &
                    ", ptr %bytes_written_input" & $inputBufferCounter &
                    ", ptr null)\n\n"
            else:
                entryCode &= "  %str_ptr_input" & $inputBufferCounter &
                    " = getelementptr inbounds [" & $promptLen & " x i8], ptr " &
                    promptRef & ", i32 0, i32 0\n"
                entryCode &= "  %writeResult_input" & $inputBufferCounter &
                    " = call i64 asm sideeffect \"syscall\",\n"
                entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                entryCode &= "      (i64 1, i64 1, ptr %str_ptr_input" &
                    $inputBufferCounter & ", i64 " & $promptLen & ")\n\n"

        # ════════════════════════════════════════════════════════════════════
        # STDIN READ — same regardless of prompt source
        # ════════════════════════════════════════════════════════════════════

        when defined(windows):
            entryCode &= "  %hstdin_input" & $inputBufferCounter &
                " = call ptr @GetStdHandle(i32 -10)\n"
            entryCode &= "  %bufPtr" & $inputBufferCounter &
                " = getelementptr [64 x i8], ptr " & bufferGlobal & ", i32 0, i32 0\n"
            entryCode &= "  call i32 @ReadConsoleA(\n"
            entryCode &= "      ptr %hstdin_input" & $inputBufferCounter & ",\n"
            entryCode &= "      ptr %bufPtr" & $inputBufferCounter & ",\n"
            entryCode &= "      i32 63,\n"
            entryCode &= "      ptr @" & bytesReadName & ",\n"
            entryCode &= "      ptr null\n"
            entryCode &= "  )\n"
        else:
            entryCode &= "  %bufPtr" & $inputBufferCounter &
                " = getelementptr [64 x i8], ptr " & bufferGlobal & ", i32 0, i32 0\n"
            entryCode &= "  %readResult" & $inputBufferCounter &
                " = call i64 asm sideeffect \"syscall\",\n"
            entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
            entryCode &= "      (i64 0, i64 0, ptr %bufPtr" &
                $inputBufferCounter & ", i64 64)\n"
            entryCode &= "  store i64 %readResult" & $inputBufferCounter &
                ", ptr @" & bytesReadName & ", align 8\n\n"

        # ── optional int conversion ───────────────────────────────────────
        if inputType == "int":
            let intVarName = "inputInt" & $inputBufferCounter
            let bytesRead  = "%bytes_read_conv_" & $inputBufferCounter
            when defined(windows):
                entryCode &= "  " & bytesRead & " = load i32, ptr @" &
                    bytesReadName & ", align 4\n"
                entryCode &= "  %" & intVarName &
                    " = call i32 @string_to_i32(ptr %bufPtr" &
                    $inputBufferCounter & ", i32 " & bytesRead & ")\n"
            else:
                let bytesRead64 = "%bytes_read_conv_64_" & $inputBufferCounter
                entryCode &= "  " & bytesRead64 & " = load i64, ptr @" &
                    bytesReadName & ", align 8\n"
                let bytesRead32 = "%bytes_read_conv_32_" & $inputBufferCounter
                entryCode &= "  " & bytesRead32 & " = trunc i64 " & bytesRead64 & " to i32\n"
                entryCode &= "  %" & intVarName &
                    " = call i32 @string_to_i32(ptr %bufPtr" &
                    $inputBufferCounter & ", i32 " & bytesRead32 & ")\n"

            vars[intVarName] = ("ssa_i32", "%" & intVarName, 0, false)

            inc inputBufferCounter
            return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

        let bufferPtr       = "%bufPtr"  & $inputBufferCounter
        let bytesReadGlobal = "@" & bytesReadName
        inc inputBufferCounter
        return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars,
            @[bufferPtr, bytesReadGlobal])

    # ══════════════════════════════════════════════════════════════════════
    # Non-IR targets — prompt resolved via evalExpression so vars expand
    # ══════════════════════════════════════════════════════════════════════

    let (promptStr, _, _) = evalExpression(args[0], vars, target, lineNumber)

    if target == "batch":
        let inputVarName = "input_var" & $inputBufferCounter
        var batchCode = "set /p " & inputVarName & "=" & promptStr
        inc inputBufferCounter
        return ("", "", batchCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    elif target == "rust":
        var functionsDef: string
        var rustCode: string

        if not ("use std::io;" in commandsCalled):
            functionsDef = "use std::io;\n"
            commandsCalled.add("use std::io;")

        if not ("use std::io::Write;" in commandsCalled):
            functionsDef.add("use std::io::Write;\n")
            commandsCalled.add("use std::io::Write;")

        rustCode &= "print!(\"" & promptStr & "\");\n"

        if not ("let mut _stdout" in commandsCalled):
            rustCode &= "let mut _stdout = io::stdout();\n"
            commandsCalled.add("let mut _stdout")

        rustCode &= "_stdout.flush().unwrap();\n"

        let inputVarName = "input_string" & $inputBufferCounter

        if inputType == "int":
            rustCode &= "let mut " & inputVarName & " = String::new();\n"
            rustCode &= "io::stdin().read_line(&mut " & inputVarName & ").unwrap();\n"
            rustCode &= "let " & inputVarName & ": i32 = " & inputVarName &
                ".trim().parse().unwrap();\n"
        else:
            rustCode &= "let mut " & inputVarName & " = String::new();\n"
            rustCode &= "io::stdin().read_line(&mut " & inputVarName & ").unwrap();\n"

        inc inputBufferCounter
        return ("", functionsDef, rustCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    elif target == "python":
        let inputVarName = "input_var" & $inputBufferCounter
        var pythonCode: string
        if inputType == "int":
            pythonCode = inputVarName & " = int(input(\"" & promptStr & "\"))"
        else:
            pythonCode = inputVarName & " = input(\"" & promptStr & "\")"
        inc inputBufferCounter
        return ("", "", pythonCode, commandsCalled, commandNum + 1, vars, @[inputVarName])

    return ("", "", "", commandsCalled, commandNum, vars, @[])