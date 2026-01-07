import std/os
import osproc

import parser
import registry 
import cmds/commands
import irWriter

# Initialize commands BEFORE processing any files
initCommands()

proc readNthLineLargeFile(filename: string, n: int): string =
    var currentLine = 0
    for line in lines(filename):
        if currentLine == n:
            return line
        inc currentLine
    raise newException(IndexDefect, "[!] Error in reading file.")

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
        discard  # File doesn't exist, which is fine

    var commandsCalled = newSeq[string]()
    var commandNum = 0
    var printCalls = newSeq[string]()  # Store the calls to print functions

    # Write global declarations first
    for lineNumber in 0 ..< totalLines:
        let line = readNthLineLargeFile(filename, lineNumber)
        
        var parser = initParser(line)
        let ast = parser.parse()

        let (irCode, newCommandsCalled, newCommandNum) = generateIR(ast, commandsCalled, commandNum)
        commandsCalled = newCommandsCalled
        commandNum = newCommandNum
        
        if irCode != "":
            writeIR(irCode, splitFile(filename).name & ".ll")
            # Store the call for later
            printCalls.add("  call i32 @print" & $(commandNum - 1) & "()")

    # Now write the main function
    writeIR("", splitFile(filename).name & ".ll")  # Empty line for readability
    writeIR("define i32 @main() {", splitFile(filename).name & ".ll")
    writeIR("entry:", splitFile(filename).name & ".ll")
    
    # Add all the print calls
    for call in printCalls:
        writeIR(call, splitFile(filename).name & ".ll")
    
    # Close the main function
    writeIR("  ret i32 0", splitFile(filename).name & ".ll")
    writeIR("}", splitFile(filename).name & ".ll")

    runLLVMIR(filename, args)