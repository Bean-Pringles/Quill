proc printIRGenerator(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int
): (string, seq[string], int) =

    if args.len == 0:
        return ("", commandsCalled, commandNum)

    let byteCount = args[0].len + 2

    var irString = """
; Define string
@.str""" & $commandNum & """ = private constant [""" & $byteCount & """ x i8] c"""" & args[0] & """\0A\00"

; Main function
define i32 @print""" & $commandNum & """() {
entry:
    %0 = getelementptr inbounds [""" & $byteCount & """ x i8], [""" & $byteCount & """ x i8]* @.str""" & $commandNum & """, i32 0, i32 0
    %1 = call i32 (i8*, ...) @printf(i8* %0)
    ret i32 0
}
"""

    # Only declare printf once
    if "print" notin commandsCalled:
        commandsCalled.add("print")
        irString = """
; Declare printf
declare i32 @printf(i8*, ...)
""" & irString

    return (irString, commandsCalled, commandNum + 1)
