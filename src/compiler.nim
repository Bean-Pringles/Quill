import std/os
import strutils
import tables

include "parser.nim"
include "cmds/commands.nim"

proc readNthLineLargeFile(filename: string, n: int): string =
    var currentLine = 0
    for line in lines(filename):
        if currentLine == n:
            return line
        inc currentLine
    raise newException(IndexError, "[!] Error in reading file.")

proc countLinesInFile(filePath: string): int =
    var lineCount = 0
    try:
        for _ in lines(filePath):
            inc lineCount
    except OSError:
        echo "[!] Could not open or read file: ", filePath
        return -1
    return lineCount

when isMainModule:
    let args = commandLineParams()

    if args.len == 0:
        echo "[*] Compiler and Language Written by Bean_Pringles. https://github.com/Bean_Pringles"
        quit(1)

    let filename = args[0]

    if not fileExists(filename):
        echo "[!] File not found: ", filename
        quit(1)

    let ext = splitFile(filename).ext

    if ext != ".qil":
        echo "[!] The ", ext, " filetype is not supported."
        quit(1)

    let totalLines = countLinesInFile(filename)

    if totalLines < 0:
        quit(1)

    for lineNumber in 0 ..< totalLines:
        let line = readNthLineLargeFile(filename, lineNumber)
        let parser = initParser(line)