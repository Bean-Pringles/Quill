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

    if args.len == 0:
        return ("", "", "", commandsCalled, commandNum, vars, @[])

    let (evalResult, _, isRuntime) = evalExpression(args[0], vars, target, lineNumber)

    if target in ["exe", "ir", "zip"]:
        var globalStringRef: string
        var globalDecl: string
        var entryCode: string
        var functionDef: string
        var byteCount = 0

        when defined(windows):
            if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                commandsCalled.add("declare ptr @GetStdHandle(i32)")
                globalDecl = "declare ptr @GetStdHandle(i32)\n"

            if not ("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                commandsCalled.add("declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)")
                globalDecl &= "declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)\n\n"
        else:
            globalDecl = ""

        # Declare heap allocation functions once.
        # Windows: HeapAlloc/HeapFree/GetProcessHeap — always available, no CRT needed.
        # Linux:   mmap/munmap via inline asm syscalls — no CRT needed.
        if not ("declare_heap" in commandsCalled):
            commandsCalled.add("declare_heap")
            when defined(windows):
                globalDecl &= "declare ptr @GetProcessHeap()\n"
                globalDecl &= "declare ptr @HeapAlloc(ptr, i32, i64)\n"
                globalDecl &= "declare i32 @HeapFree(ptr, i32, ptr)\n\n"
            else:
                discard  # mmap/munmap are called via inline asm; no external declarations needed

        if not ("i32_to_string_func" in commandsCalled):
            commandsCalled.add("i32_to_string_func")

            # The only platform difference is the single heap-allocation
            # instruction inside `finalize`.  Build it conditionally, then
            # concatenate the rest of the function body as plain strings so
            # every line is explicit and easy to read / diff.
            when defined(windows):
                # HEAP_ZERO_MEMORY = 8 ensures no stale bytes are visible.
                let heapAllocLines =
                    "    %heap_handle = call ptr @GetProcessHeap()\n" &
                    "    %heap_ptr = call ptr @HeapAlloc(ptr %heap_handle, i32 8, i64 12)\n"
            else:
                # mmap(NULL, 16, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
                # syscall: rax=9, rdi=0, rsi=16, rdx=3, r10=34, r8=-1, r9=0
                let heapAllocLines =
                    "    %mmap_ret = call i64 asm sideeffect \"syscall\",\n" &
                    "        \"={rax},{rax},{rdi},{rsi},{rdx},{r10},{r8},{r9},~{rcx},~{r11}\"\n" &
                    "        (i64 9, i64 0, i64 16, i64 3, i64 34, i64 -1, i64 0)\n" &
                    "    %heap_ptr = inttoptr i64 %mmap_ret to ptr\n"

            globalDecl &= "; i32 -> string converter. Returns heap-allocated {ptr, length}.\n"
            globalDecl &= "define { ptr, i32 } @i32_to_string(i32 %num) {\n"
            globalDecl &= "entry:\n"
            globalDecl &= "    %buffer = alloca [13 x i8], align 1\n"
            globalDecl &= "    %is_negative = icmp slt i32 %num, 0\n"
            globalDecl &= "    %abs_num = select i1 %is_negative, i32 0, i32 %num\n"
            globalDecl &= "    %neg_num = sub i32 0, %num\n"
            globalDecl &= "    %abs_val = select i1 %is_negative, i32 %neg_num, i32 %abs_num\n"
            globalDecl &= "    %start_pos = alloca i32, align 4\n"
            globalDecl &= "    store i32 11, ptr %start_pos, align 4\n"
            globalDecl &= "    %is_zero = icmp eq i32 %num, 0\n"
            globalDecl &= "    br i1 %is_zero, label %zero_case, label %convert_loop_init\n"
            globalDecl &= "zero_case:\n"
            globalDecl &= "    %pos_zero = load i32, ptr %start_pos, align 4\n"
            globalDecl &= "    %ptr_zero = getelementptr [12 x i8], ptr %buffer, i32 0, i32 %pos_zero\n"
            globalDecl &= "    store i8 48, ptr %ptr_zero, align 1\n"
            globalDecl &= "    %pos_zero_dec = sub i32 %pos_zero, 1\n"
            globalDecl &= "    store i32 %pos_zero_dec, ptr %start_pos, align 4\n"
            globalDecl &= "    br label %add_sign\n"
            globalDecl &= "convert_loop_init:\n"
            globalDecl &= "    %temp = alloca i32, align 4\n"
            globalDecl &= "    store i32 %abs_val, ptr %temp, align 4\n"
            globalDecl &= "    br label %convert_loop\n"
            globalDecl &= "convert_loop:\n"
            globalDecl &= "    %current = load i32, ptr %temp, align 4\n"
            globalDecl &= "    %is_done = icmp eq i32 %current, 0\n"
            globalDecl &= "    br i1 %is_done, label %add_sign, label %convert_digit\n"
            globalDecl &= "convert_digit:\n"
            globalDecl &= "    %digit = urem i32 %current, 10\n"
            globalDecl &= "    %ascii = add i32 %digit, 48\n"
            globalDecl &= "    %ascii_byte = trunc i32 %ascii to i8\n"
            globalDecl &= "    %pos = load i32, ptr %start_pos, align 4\n"
            globalDecl &= "    %ptr = getelementptr [12 x i8], ptr %buffer, i32 0, i32 %pos\n"
            globalDecl &= "    store i8 %ascii_byte, ptr %ptr, align 1\n"
            globalDecl &= "    %pos_dec = sub i32 %pos, 1\n"
            globalDecl &= "    store i32 %pos_dec, ptr %start_pos, align 4\n"
            globalDecl &= "    %next = udiv i32 %current, 10\n"
            globalDecl &= "    store i32 %next, ptr %temp, align 4\n"
            globalDecl &= "    br label %convert_loop\n"
            globalDecl &= "add_sign:\n"
            globalDecl &= "    br i1 %is_negative, label %add_minus, label %finalize\n"
            globalDecl &= "add_minus:\n"
            globalDecl &= "    %pos_sign = load i32, ptr %start_pos, align 4\n"
            globalDecl &= "    %ptr_sign = getelementptr [12 x i8], ptr %buffer, i32 0, i32 %pos_sign\n"
            globalDecl &= "    store i8 45, ptr %ptr_sign, align 1\n"
            globalDecl &= "    %pos_sign_dec = sub i32 %pos_sign, 1\n"
            globalDecl &= "    store i32 %pos_sign_dec, ptr %start_pos, align 4\n"
            globalDecl &= "    br label %finalize\n"
            globalDecl &= "finalize:\n"
            globalDecl &= "    %final_pos = load i32, ptr %start_pos, align 4\n"
            globalDecl &= "    %start_idx = add i32 %final_pos, 1\n"
            globalDecl &= "    %length = sub i32 11, %final_pos\n"
            globalDecl &= "    %newline_pos = add i32 %start_idx, %length\n"
            globalDecl &= "    %ptr_newline = getelementptr [12 x i8], ptr %buffer, i32 0, i32 %newline_pos\n"
            globalDecl &= "    store i8 10, ptr %ptr_newline, align 1\n"
            globalDecl &= "    %final_length = add i32 %length, 1\n"
            globalDecl &= "    %result_ptr = getelementptr [12 x i8], ptr %buffer, i32 0, i32 %start_idx\n"
            globalDecl &= heapAllocLines
            # Manual byte-copy loop — avoids any dependency on the CRT memcpy symbol.
            # Copies %final_length bytes from %result_ptr (stack) into %heap_ptr.
            globalDecl &= "    br label %copy_loop\n"
            globalDecl &= "copy_loop:\n"
            globalDecl &= "    %copy_i = phi i32 [ 0, %finalize ], [ %copy_i_next, %copy_body ]\n"
            globalDecl &= "    %copy_done = icmp eq i32 %copy_i, %final_length\n"
            globalDecl &= "    br i1 %copy_done, label %copy_done_block, label %copy_body\n"
            globalDecl &= "copy_body:\n"
            globalDecl &= "    %src_ptr = getelementptr i8, ptr %result_ptr, i32 %copy_i\n"
            globalDecl &= "    %dst_ptr = getelementptr i8, ptr %heap_ptr, i32 %copy_i\n"
            globalDecl &= "    %byte = load i8, ptr %src_ptr, align 1\n"
            globalDecl &= "    store i8 %byte, ptr %dst_ptr, align 1\n"
            globalDecl &= "    %copy_i_next = add i32 %copy_i, 1\n"
            globalDecl &= "    br label %copy_loop\n"
            globalDecl &= "copy_done_block:\n"
            globalDecl &= "    %ret_val = insertvalue { ptr, i32 } undef, ptr %heap_ptr, 0\n"
            globalDecl &= "    %ret_val2 = insertvalue { ptr, i32 } %ret_val, i32 %final_length, 1\n"
            globalDecl &= "    ret { ptr, i32 } %ret_val2\n"
            globalDecl &= "}\n\n"

        # Emit the platform-appropriate free for a pointer register.
        proc emitFree(ptrReg: string, counter: int): string =
            when defined(windows):
                let hReg = "%free_heap_" & $counter
                result =  "  " & hReg & " = call ptr @GetProcessHeap()\n"
                result &= "  %free_result_" & $counter &
                    " = call i32 @HeapFree(ptr " & hReg & ", i32 0, ptr " & ptrReg & ")\n"
            else:
                # munmap(addr, 16) — length must match the mmap call above
                # syscall: rax=11, rdi=addr, rsi=16
                result  = "  %unmap_addr_" & $counter & " = ptrtoint ptr " & ptrReg & " to i64\n"
                result &= "  %_unmap_" & $counter & " = call i64 asm sideeffect \"syscall\",\n"
                result &= "      \"={rax},{rax},{rdi},{rsi},~{rcx},~{r11}\"\n"
                result &= "      (i64 11, i64 %unmap_addr_" & $counter & ", i64 16)\n"

        # ── runtime variable reference ────────────────────────────────────
        if isRuntime and evalResult in vars:
            let (varType, varValue, strLength, isCommandResult) = vars[evalResult]

            if varType == "ssa_i32":
                let convertReg = "%converted_ssa_" & $printGlobalCounter
                entryCode = "  " & convertReg &
                    " = call { ptr, i32 } @i32_to_string(i32 " & varValue & ")\n"

                let strPtr = "%str_ptr_ssa_" & $printGlobalCounter
                let strLen = "%str_len_ssa_" & $printGlobalCounter
                entryCode &= "  " & strPtr & " = extractvalue { ptr, i32 } " &
                    convertReg & ", 0\n"
                entryCode &= "  " & strLen & " = extractvalue { ptr, i32 } " &
                    convertReg & ", 1\n"

                when defined(windows):
                    entryCode &= "  %stdout_print" & $printGlobalCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteFile(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & strPtr & ", i32 " &
                        strLen & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
                else:
                    let strLen64 = "%str_len_64_ssa_" & $printGlobalCounter
                    entryCode &= "  " & strLen64 & " = zext i32 " & strLen & " to i64\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & strPtr &
                        ", i64 " & strLen64 & ")\n"

                entryCode &= emitFree(strPtr, printGlobalCounter)
                inc printGlobalCounter
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

            elif varType == "i32":
                let loadReg = "%loaded_int_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load i32, ptr %" &
                    evalResult & ", align 4\n"

                let convertReg = "%converted_" & $printGlobalCounter
                entryCode &= "  " & convertReg &
                    " = call { ptr, i32 } @i32_to_string(i32 " & loadReg & ")\n"

                let strPtr = "%str_ptr_" & $printGlobalCounter
                let strLen = "%str_len_" & $printGlobalCounter
                entryCode &= "  " & strPtr & " = extractvalue { ptr, i32 } " &
                    convertReg & ", 0\n"
                entryCode &= "  " & strLen & " = extractvalue { ptr, i32 } " &
                    convertReg & ", 1\n"

                when defined(windows):
                    entryCode &= "  %stdout_print" & $printGlobalCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteFile(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & strPtr & ", i32 " &
                        strLen & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
                else:
                    let strLen64 = "%str_len_64_" & $printGlobalCounter
                    entryCode &= "  " & strLen64 & " = zext i32 " & strLen & " to i64\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & strPtr &
                        ", i64 " & strLen64 & ")\n"

                entryCode &= emitFree(strPtr, printGlobalCounter)
                inc printGlobalCounter
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

            elif isCommandResult:
                let loadReg = "%loaded_" & evalResult & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" &
                    evalResult & ", align 8\n"

                var bytesReadGlobal = "@bytesRead0"
                if varValue.contains("bufPtr"):
                    let bufNum = varValue.replace("%bufPtr", "")
                    bytesReadGlobal = "@bytesRead" & bufNum

                when defined(windows):
                    let bytesReg = "%bytesRead_" & evalResult & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i32, ptr " &
                        bytesReadGlobal & ", align 4\n"
                    entryCode &= "  %stdout_print" & $printGlobalCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteFile(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & loadReg & ", i32 " &
                        bytesReg & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
                else:
                    let bytesReg = "%bytesRead_" & evalResult & "_" & $printGlobalCounter
                    entryCode &= "  " & bytesReg & " = load i64, ptr " &
                        bytesReadGlobal & ", align 8\n"
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg &
                        ", i64 " & bytesReg & ")\n"

                inc printGlobalCounter
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

            elif varType == "ptr" and varValue.startsWith("@.str"):
                let loadReg = "%loaded_" & evalResult & "_" & $printGlobalCounter
                entryCode = "  " & loadReg & " = load ptr, ptr %" &
                    evalResult & ", align 8\n"

                when defined(windows):
                    entryCode &= "  %stdout_print" & $printGlobalCounter &
                        " = call ptr @GetStdHandle(i32 -11)\n"
                    entryCode &= "  %bytes_written_print" & $printGlobalCounter &
                        " = alloca i32, align 4\n"
                    entryCode &= "  %result_print" & $printGlobalCounter &
                        " = call i32 @WriteFile(ptr %stdout_print" &
                        $printGlobalCounter & ", ptr " & loadReg & ", i32 " &
                        $strLength & ", ptr %bytes_written_print" &
                        $printGlobalCounter & ", ptr null)\n"
                else:
                    entryCode &= "  %writeResult_print" & $printGlobalCounter &
                        " = call i64 asm sideeffect \"syscall\",\n"
                    entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    entryCode &= "      (i64 1, i64 1, ptr " & loadReg &
                        ", i64 " & $strLength & ")\n"

                inc printGlobalCounter
                return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

            else:
                byteCount = varValue.len + 2
                globalStringRef = "@.strPrint" & $printGlobalCounter
                globalDecl.add(globalStringRef & " = private constant [" &
                    $byteCount & " x i8] c\"" & varValue & "\\0A\\00\"")

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
                    functionDef &= "  %writeResult = call i64 asm sideeffect \"syscall\",\n"
                    functionDef &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                    functionDef &= "      (i64 1, i64 1, ptr %str_ptr, i64 " & $byteCount & ")\n"

                functionDef &= "  ret i32 0\n"
                functionDef &= "}"

                inc printGlobalCounter
                return (globalDecl, functionDef, "", commandsCalled, commandNum + 1, vars, @[])

        # ── direct buffer pointer (e.g. %bufPtr0) ────────────────────────
        elif isRuntime and evalResult.startsWith("%bufPtr"):
            let bufferPtr = evalResult
            var bytesReadGlobal = "@bytesRead0"
            if bufferPtr.contains("bufPtr"):
                let bufNum = bufferPtr.replace("%bufPtr", "")
                bytesReadGlobal = "@bytesRead" & bufNum

            entryCode = ""

            when defined(windows):
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i32, ptr " &
                    bytesReadGlobal & ", align 4\n"
                entryCode &= "  %stdout_print" & $printGlobalCounter &
                    " = call ptr @GetStdHandle(i32 -11)\n"
                entryCode &= "  %bytes_written_print" & $printGlobalCounter &
                    " = alloca i32, align 4\n"
                entryCode &= "  %result_print" & $printGlobalCounter &
                    " = call i32 @WriteFile(ptr %stdout_print" &
                    $printGlobalCounter & ", ptr " & bufferPtr & ", i32 " &
                    bytesReg & ", ptr %bytes_written_print" &
                    $printGlobalCounter & ", ptr null)\n"
            else:
                let bytesReg = "%bytesRead_direct_" & $printGlobalCounter
                entryCode &= "  " & bytesReg & " = load i64, ptr " &
                    bytesReadGlobal & ", align 8\n"
                entryCode &= "  %writeResult_print" & $printGlobalCounter &
                    " = call i64 asm sideeffect \"syscall\",\n"
                entryCode &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                entryCode &= "      (i64 1, i64 1, ptr " & bufferPtr &
                    ", i64 " & bytesReg & ")\n"

            inc printGlobalCounter
            return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

        # ── compile-time constant string/number ───────────────────────────
        else:
            byteCount = evalResult.len + 2
            globalStringRef = "@.strPrint" & $printGlobalCounter
            globalDecl.add(globalStringRef & " = private constant [" &
                $byteCount & " x i8] c\"" & evalResult & "\\0A\\00\"")

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
                functionDef &= "  %writeResult = call i64 asm sideeffect \"syscall\",\n"
                functionDef &= "      \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
                functionDef &= "      (i64 1, i64 1, ptr %str_ptr, i64 " & $byteCount & ")\n"

            functionDef &= "  ret i32 0\n"
            functionDef &= "}"

            inc printGlobalCounter
            return (globalDecl, functionDef, "", commandsCalled, commandNum + 1, vars, @[])

    elif target == "batch":
        if isRuntime and evalResult in vars:
            let (_, _, _, varIsRuntime) = vars[evalResult]
            if varIsRuntime:
                return ("", "", "echo !" & evalResult & "!", commandsCalled, commandNum, vars, @[])
            else:
                return ("", "", "echo %" & evalResult & "%", commandsCalled, commandNum, vars, @[])
        elif isRuntime:
            # Runtime but not in vars table (e.g. direct input result)
            return ("", "", "echo !" & evalResult & "!", commandsCalled, commandNum, vars, @[])
        elif evalResult == "":
            # Empty string literal - print a blank line
            return ("", "", "echo.", commandsCalled, commandNum, vars, @[])
        else:
            # Compile-time constant - print the literal value directly, no var reference
            return ("", "", "echo " & evalResult, commandsCalled, commandNum, vars, @[])

    elif target == "rust":
        if isRuntime:
            return ("", "", "println!(\"{}\", " & evalResult & ");",
                commandsCalled, commandNum, vars, @[])
        else:
            return ("", "", "println!(\"" & evalResult & "\");",
                commandsCalled, commandNum, vars, @[])

    elif target == "python":
        if isRuntime:
            return ("", "", "print(" & evalResult & ")",
                commandsCalled, commandNum, vars, @[])
        else:
            return ("", "", "print(\"" & evalResult & "\")",
                commandsCalled, commandNum, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])