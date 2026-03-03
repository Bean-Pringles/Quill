var ossleepnum: int = 0

proc ossleepIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =

    if args.len != 1:
        echo "[!] os.sleep() takes exactly one argument: the number of milliseconds to sleep for."
        quit(1)

    var (milliseconds, _, isRuntime) = evalExpression(args[0], vars, target, lineNumber)
    var globalDecl: string
    var funcDef: string

    if target in ["exe", "ir", "zip"]:
        var code: string
        var sleepValue: string  # The actual register/value to use
        
        # Resolve the runtime value to an actual register
        if isRuntime:
            if milliseconds in vars:
                let (varType, varValue, _, _) = vars[milliseconds]
                
                # SSA values are already registers - use directly
                if varType.startsWith("ssa_"):
                    sleepValue = varValue  # Already has % prefix like "%randint_0"
                else:
                    # It's a pointer variable - need to load it
                    let loadReg = "%sleep_val_" & $ossleepnum
                    code &= "    " & loadReg & " = load i32, ptr %" & milliseconds & ", align 4\n"
                    sleepValue = loadReg
                    inc ossleepnum
            else:
                # Raw register or expression - use as-is
                sleepValue = milliseconds
        else:
            # Compile-time constant - use as literal
            sleepValue = milliseconds
        
        if defined(windows):
            if "declare void @Sleep(i32)" notin commandsCalled:
                commandsCalled.add("declare void @Sleep(i32)")
                globalDecl = "declare void @Sleep(i32)\n\n"
            
            code &= "    call void @Sleep(i32 " & sleepValue & ")\n"
            return (globalDecl, funcDef, code, commandsCalled, commandNum + 1, vars, @[])

        else:
            # Linux - sleep_ms takes i64
            if "declare i64 @syscall(i64, ...)" notin commandsCalled:
                commandsCalled.add("declare i64 @syscall(i64, ...)")
                globalDecl = "declare i64 @syscall(i64, ...)\n\n"
            
            if "define void @sleep_ms(i64 %ms)" notin commandsCalled:
                commandsCalled.add("define void @sleep_ms(i64 %ms)")
                funcDef = "define void @sleep_ms(i64 %ms) {\nentry:\n    %ts = alloca { i64, i64 }\n\n    %sec = udiv i64 %ms, 1000\n    %tv_sec_ptr = getelementptr { i64, i64 }, { i64, i64 }* %ts, i32 0, i32 0\n    store i64 %sec, i64* %tv_sec_ptr\n\n    %rem = urem i64 %ms, 1000\n    %nsec = mul i64 %rem, 1000000\n    %tv_nsec_ptr = getelementptr { i64, i64 }, { i64, i64 }* %ts, i32 0, i32 1\n    store i64 %nsec, i64* %tv_nsec_ptr\n\n    %ts_addr = ptrtoint { i64, i64 }* %ts to i64\n    call i64 @syscall(i64 35, i64 %ts_addr, i64 0)\n    ret void\n}\n\n"
                
            # Need to extend i32 to i64 for sleep_ms parameter
            if isRuntime:
                let sleepVal64 = "%sleep_ms_val_" & $ossleepnum
                code &= "    " & sleepVal64 & " = sext i32 " & sleepValue & " to i64\n"
                code &= "    call void @sleep_ms(i64 " & sleepVal64 & ")\n"
                inc ossleepnum
            else:
                code &= "    call void @sleep_ms(i64 " & sleepValue & ")\n"

            return (globalDecl, funcDef, code, commandsCalled, commandNum + 1, vars, @[])
            

    elif target == "batch":
        var code: string
        
        # Creates delay var and calls sleep function for that long
        if isRuntime:
            # Runtime variable - reference it with %varname%
            code = "SET delay_ms" & $ossleepnum & "=%" & milliseconds & "%\n"
        else: 
            # Literal value
            code = "SET delay_ms" & $ossleepnum & "=" & milliseconds & "\n"
        
        code &= "powershell.exe -Command \"Start-Sleep -Milliseconds %delay_ms" & $ossleepnum & "%\"\n"

        inc ossleepnum
        return ("", "", code, commandsCalled, commandNum + 1, vars, @[])

    elif target == "rust":
        var libImport: string
        var code: string

        if "use std::thread;\nuse std::time::Duration;" notin commandsCalled:
            commandsCalled.add("use std::thread;\nuse std::time::Duration;")
            libImport = "use std::thread;\nuse std::time::Duration;\n"
        
        if isRuntime:
            # Runtime variable - use variable name directly, cast to u64
            code = "    thread::sleep(Duration::from_millis(" & milliseconds & " as u64));\n"
        else:
            # Literal value
            code = "    thread::sleep(Duration::from_millis(" & milliseconds & "));\n"
        
        return ("", libImport, code, commandsCalled, commandNum + 1, vars, @[])
    
    elif target == "python":
        var code: string
        var libImport: string
        
        if not ("import time" in commandsCalled):
            commandsCalled.add("import time")
            libImport = "import time\n"

        if isRuntime:
            # Runtime variable - use variable name directly, divide by 1000
            code = "time.sleep(" & milliseconds & " / 1000.0)\n"
        else:
            # Literal value - convert at compile time
            code = "time.sleep(" & $(parseFloat(milliseconds) / 1000.0) & ")\n"

        return ("", libImport, code, commandsCalled, commandNum + 1, vars, @[])