import std/os
import strutils
import tables
import std/files
import osproc

include "parser.nim"
include "cmds/commands.nim"
include "irWriter.nim"

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

proc cleanup(filename: string, args: seq[string]) =
    let irFile = splitFile(filename).name & ".ll"
    let exeFile = splitFile(filename).name & ".exe"

    if fileExists(irFile):
        try:
            removeFile(irFile)
        except OSError:
            echo "[!] Error removing IR file: ", cast[ptr OSError](getCurrentException()).msg

    if fileExists(exeFile):
        try:
            moveFile(exeFile, joinPath(splitFile(filename).dir, exeFile))
        except OSError:
            echo "[!] Error moving executable file: ", cast[ptr OSError](getCurrentException()).msg


proc runLLVMIR(filename: string, args: seq[string]) =
    let irFile = splitFile(filename).name & ".ll"
    
    if not fileExists(irFile):
        echo "[!] IR file not found: ", irFile
        return

    if not ("-ir" in args):
        let command = "clang " & irFile & " -o " & splitFile(filename).name & ".exe"
        let result = execProcess(command)
        echo result
        cleanup(filename, args)
    else:
        try:
            moveFile(irFile, joinPath(splitFile(filename).dir, irFile))
        except OSError:
            echo "[!] Error moving IR file: ", cast[ptr OSError](getCurrentException()).msg

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

    try:
        removeFile(splitFile(filename).name & ".ll")
    except OSError:
        echo "[!] Error removing file: ", cast[ptr OSError](getCurrentException()).msg

    for lineNumber in 0 ..< totalLines:
        let line = readNthLineLargeFile(filename, lineNumber)
        
        var parser = initParser(line)
        let ast = parser.parse()

        let irCode = generateIR(ast)
        
        if irCode != "":
            writeIR(irCode, splitFile(filename).name & ".ll")

    runLLVMIR(filename, args)