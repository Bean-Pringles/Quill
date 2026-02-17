proc osclrscrIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =

    if target in ["exe", "ir", "zip"]:
        var globalDecl = ""
        var entryCode  = ""

        when defined(windows):
            # \033[H  = cursor home
            # \033[2J = erase entire display
            # 7 bytes: 0x1B 0x5B 0x48 0x1B 0x5B 0x32 0x4A
            if not ("@clrseqW" in commandsCalled):
                commandsCalled.add("@clrseqW")
                globalDecl &= "@clrseqW = private unnamed_addr constant [7 x i8] c\"\\1B[H\\1B[2J\"\n"

            # GetStdHandle / WriteConsoleA are already declared by print/input —
            # only add them if this command runs before any of those.
            if not ("declare ptr @GetStdHandle(i32)" in commandsCalled):
                commandsCalled.add("declare ptr @GetStdHandle(i32)")
                globalDecl &= "declare ptr @GetStdHandle(i32)\n\n"

            if not ("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)" in commandsCalled):
                commandsCalled.add("declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)")
                globalDecl &= "declare i32 @WriteConsoleA(ptr, ptr, i32, ptr, ptr)\n\n"

            let n = $commandNum
            entryCode &= "    ; os.clrscr() — clear screen (Windows ANSI)\n"
            entryCode &= "    %clrHstdout"  & n & " = call ptr @GetStdHandle(i32 -11)\n"
            entryCode &= "    %clrSeqPtr"   & n & " = getelementptr [7 x i8], ptr @clrseqW, i64 0, i64 0\n"
            entryCode &= "    %clrWritten"  & n & " = alloca i32, align 4\n"
            entryCode &= "    call i32 @WriteConsoleA(ptr %clrHstdout" & n &
                         ", ptr %clrSeqPtr" & n & ", i32 7, ptr %clrWritten" & n & ", ptr null)\n"

        else:
            if not ("@clrseq" in commandsCalled):
                commandsCalled.add("@clrseq")
                globalDecl &= "@clrseq = private unnamed_addr constant [7 x i8] c\"\\1B[H\\1B[2J\"\n"

            let n = $commandNum
            entryCode &= "    ; os.clrscr() — clear screen (Linux/macOS ANSI syscall)\n"
            entryCode &= "    %clrSeqPtr" & n & " = getelementptr [7 x i8], ptr @clrseq, i64 0, i64 0\n"
            entryCode &= "    call i64 asm sideeffect \"syscall\",\n"
            entryCode &= "        \"={rax},{rax},{rdi},{rsi},{rdx},~{rcx},~{r11}\"\n"
            entryCode &= "        (i64 1, i64 1, ptr %clrSeqPtr" & n & ", i64 7)\n"

        return (globalDecl, "", entryCode, commandsCalled, commandNum + 1, vars, @[])

    elif target == "batch":
        return ("", "", "cls", commandsCalled, commandNum + 1, vars, @[])

    elif target == "rust":
        var functionsDef = ""

        if not ("use std::process::Command;" in commandsCalled):
            commandsCalled.add("use std::process::Command;")
            functionsDef &= "use std::process::Command;\n"

        let rustCode = "Command::new(if cfg!(target_os = \"windows\") { \"cmd\" } else { \"clear\" })\n" &
                       "    .args(if cfg!(target_os = \"windows\") { &[\"/C\", \"cls\"] } else { &[] as &[&str] })\n" &
                       "    .status().unwrap();\n"

        return ("", functionsDef, rustCode, commandsCalled, commandNum + 1, vars, @[])

    elif target == "python":
        var functionsDef = ""

        if not ("import os as _os" in commandsCalled):
            commandsCalled.add("import os as _os")
            functionsDef &= "import os as _os\n"

        let pythonCode = "_os.system('cls' if _os.name == 'nt' else 'clear')"

        return ("", functionsDef, pythonCode, commandsCalled, commandNum + 1, vars, @[])

    return ("", "", "", commandsCalled, commandNum, vars, @[])