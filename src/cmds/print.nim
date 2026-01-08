proc printIRGenerator(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string)]
): (string, seq[string], int, Table[string, (string, string)]) =

    if args.len == 0:
        return ("", commandsCalled, commandNum, vars)
    
    var mutArgs = args 
    
    if mutArgs[0] in vars:
        mutArgs[0] = vars[mutArgs[0]][1]  # Get the value of the variable if it's a variable name 

    let byteCount = mutArgs[0].len + 1  # +1 for newline, no null terminator needed

    var irString = """
@.str""" & $commandNum & """ = private constant [""" & $byteCount & """ x i8] c"""" & mutArgs[0] & """\0A"

define i32 @print""" & $commandNum & """() {
entry:
    %str_ptr = getelementptr inbounds [""" & $byteCount & """ x i8], [""" & $byteCount & """ x i8]* @.str""" & $commandNum & """, i32 0, i32 0
"""

    # Platform-specific syscall
    when defined(linux):
        irString &= """    %result = call i64 @write(i32 1, i8* %str_ptr, i64 """ & $byteCount & """)
    ret i32 0
}
"""
        # Only declare write syscall once
        if "print" notin commandsCalled:
            commandsCalled.add("print")
            irString = "declare i64 @write(i32, i8*, i64)\n" & irString
    
    elif defined(windows):
        irString &= """    %stdout = call i8* @GetStdHandle(i32 -11)
    %bytes_written = alloca i32
    %result = call i32 @WriteFile(i8* %stdout, i8* %str_ptr, i32 """ & $byteCount & """, i32* %bytes_written, i8* null)
    ret i32 0
}
"""
        # Only declare Windows API functions once
        if "print" notin commandsCalled:
            commandsCalled.add("print")
            irString = "declare i8* @GetStdHandle(i32)\ndeclare i32 @WriteFile(i8*, i8*, i32, i32*, i8*)\n" & irString
    
    else:
        # Fallback to write syscall for other Unix-like systems
        irString &= """    %result = call i64 @write(i32 1, i8* %str_ptr, i64 """ & $byteCount & """)
    ret i32 0
}
"""
        if "print" notin commandsCalled:
            commandsCalled.add("print")
            irString = "declare i64 @write(i32, i8*, i64)\n" & irString

    return (irString, commandsCalled, commandNum + 1, vars)