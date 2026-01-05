proc printCmd(args: seq[string]) =
    for arg in args:
        echo arg

registerCommand("print", printCmd)
