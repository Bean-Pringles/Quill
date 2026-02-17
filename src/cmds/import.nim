# cmds/import.nim

import os, strutils, tables
import ../importstate

proc importIRGenerator*(
    args: seq[string],
    commandsCalled: var seq[string],
    commandNum: int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =

    if args.len == 0:
        echo "[!] Error on line " & $lineNumber & ": import requires a library name"
        quit(1)

    let libName = args[0].strip()

    const stdlibBase = currentSourcePath().parentDir() / "stdlib"
    let libPath = stdlibBase / libName

    if not dirExists(libPath):
        echo "[!] Error on line " & $lineNumber & ": unknown library '" & libName & "'"
        quit(1)

    importLib(libName)

    # No IR output — import is compile-time only
    return ("", "", "", commandsCalled, commandNum, vars, @[])