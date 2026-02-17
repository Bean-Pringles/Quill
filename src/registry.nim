import tables
import importstate

type
    IRGenerator* = proc(
        args: seq[string],
        commandsCalled: var seq[string],
        commandNum: int,
        vars: var Table[string, (string, string, int, bool)],
        cmdVal: seq[string],
        target: string,
        lineNumber: int
    ): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string])

var irGenerators* = initTable[string, IRGenerator]()

proc registerIRGenerator*(name: string, generator: IRGenerator) =
    irGenerators[name] = generator

proc hasIRGenerator*(name: string): bool =
    irGenerators.hasKey(name)

proc resolveCommand*(name: string, lineNumber: int): string =
    ## Resolves a raw command name (plain or dotted) to a registry key,
    ## enforcing import rules. Calls quit(1) on any violation.
    if '.' in name:
        let dotPos = name.find('.')
        let libName = name[0 ..< dotPos]
        let cmdName = name[dotPos + 1 .. ^1]

        if not isImported(libName):
            echo "[!] Error on line " & $lineNumber & ": library '" & libName &
                 "' is not imported. Add 'import " & libName & "' to your script."
            quit(1)

        let key = libName & "." & cmdName
        if not irGenerators.hasKey(key):
            echo "[!] Error on line " & $lineNumber & ": library '" & libName &
                 "' has no command '" & cmdName & "'"
            quit(1)

        return key
    else:
        if not irGenerators.hasKey(name):
            echo "[!] Error on line " & $lineNumber & ": unknown command '" & name & "'"
            quit(1)
        return name