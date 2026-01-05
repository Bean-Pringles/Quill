proc printIRGenerator(args: seq[string]): string =
    if args.len == 0:
        return ""
    return "PRINT " & args[0]

registerIRGenerator("print", printIRGenerator)