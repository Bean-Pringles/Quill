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
        
        if isRuntime:
            milliseconds = "%" & milliseconds
        
        if defined(windows):
            if "declare void @Sleep(i32)" notin commandsCalled:
                commandsCalled.add("declare void @Sleep(i32)")
                globalDecl = "declare void @Sleep(i32)\n\n"
            
            if isRuntime:
                code = "    call void @Sleep(i32 " & milliseconds & ")\n"
            else:
                code = "    call void @Sleep(i32 " & $milliseconds & ")\n"
        
            return (globalDecl, funcDef, code, commandsCalled, commandNum + 1, vars, @[])

        else:
            if "declare i64 @syscall(i64, ...)" notin commandsCalled:
                commandsCalled.add("declare i64 @syscall(i64, ...)")
                globalDecl = "declare i64 @syscall(i64, ...)\n\n"
            
            if "define void @sleep_ms(i64 %ms)" notin commandsCalled:
                commandsCalled.add("define void @sleep_ms(i64 %ms)")
                funcDef = "define void @sleep_ms(i64 %ms) {\nentry:\n    %ts = alloca { i64, i64 }\n\n    %sec = udiv i64 %ms, 1000\n    %tv_sec_ptr = getelementptr { i64, i64 }, { i64, i64 }* %ts, i32 0, i32 0\n    store i64 %sec, i64* %tv_sec_ptr\n\n    %rem = urem i64 %ms, 1000\n    %nsec = mul i64 %rem, 1000000\n    %tv_nsec_ptr = getelementptr { i64, i64 }, { i64, i64 }* %ts, i32 0, i32 1\n    store i64 %nsec, i64* %tv_nsec_ptr\n\n    %ts_addr = bitcast { i64, i64 }* %ts to i64\n    call i64 @syscall(i64 35, i64 %ts_addr, i64 0)\n}\n"
            
            if isRuntime:
                code = "    call void @sleep_ms(i64 " & milliseconds & ")\n"
            else:
                code = "    call void @sleep_ms(i64 " & $milliseconds & ")\n"

            return (globalDecl, funcDef, code, commandsCalled, commandNum + 1, vars, @[])
            

    elif target == "batch":
        var code: string
        
        # Creates delay var and calls sleep function for that long
        if isRuntime:
            code = "SET delay_ms" & $ossleepnum & "=%" & milliseconds & "\n"
        else: 
            code = "SET delay_ms" & $ossleepnum & "=%" & $milliseconds & "\n"
        
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
            code = "thread::sleep(Duration::from_millis(" & milliseconds & "));\n"
        else:
            code = "thread::sleep(Duration::from_millis(" & $milliseconds & "));\n"
        
        return ("", libImport, code, commandsCalled, commandNum + 1, vars, @[])
    
    elif target == "python":
        var code: string
        var libImport: string
        
        if not ("import time" in commandsCalled):
            commandsCalled.add("import time")
            libImport = "import time\n"

        if isRuntime:
             code = "time.sleep(" & milliseconds & " / 1000.0)\n"
        else:
            code = "time.sleep(" & $(parseFloat(milliseconds) / 1000.0) & ")\n"

        return ("", libImport, code, commandsCalled, commandNum + 1, vars, @[])

        