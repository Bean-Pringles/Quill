proc printIRGenerator(args: seq[string]): string =
    if args.len == 0:
        return ""
    
    let byteCount = args[0].len + 2
    let irString = """
; Declare printf
declare i32 @printf(i8*, ...)

; Define string
@.str = private constant [""" & $byteCount & """ x i8] c"""" & $args[0] & """\0A\00"

; Main function
define i32 @main() {
entry:
    %0 = getelementptr inbounds [""" & $byteCount & """ x i8], [""" & $byteCount & """ x i8]* @.str, i32 0, i32 0
    %1 = call i32 (i8*, ...) @printf(i8* %0)
    ret i32 0
}
"""
    return irString

registerIRGenerator("print", printIRGenerator)
