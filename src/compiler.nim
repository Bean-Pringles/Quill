import std/os
import osproc
import strutils

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
    let irFile = splitFile(absolutePath(filename)).name & ".ll"
    let exeFile = splitFile(absolutePath(filename)).name & ".exe"

    if fileExists(irFile):
        try:
            removeFile(irFile)
        except OSError:
            echo "[!] Error removing IR file: ", cast[ptr OSError](
                    getCurrentException()).msg

    if fileExists(exeFile):
        if "-zip" notin args:
            try:
                moveFile(exeFile, joinPath(splitFile(filename).dir, exeFile))
            except OSError:
                echo "[!] Error moving executable file: ", cast[ptr OSError](
                        getCurrentException()).msg
        else:
            let zipFile = splitFile(absolutePath(filename)).name & ".zip"
            
            try:
                # Remove the .exe file after zipping and Move the .zip file instead
                removeFile(exeFile)
                moveFile(zipFile, joinPath(splitFile(filename).dir, zipFile))
            except OSError:
                echo "[!] Error removing executable file: ", cast[ptr OSError](
                        getCurrentException()).msg

proc runLLVMIR(filename: string, args: seq[string]) =
    let irFile = splitFile(filename).name & ".ll"

    if not fileExists(irFile):
        echo "[!] IR file not found: ", irFile
        return

    if not ("-ir" in args):
        # Determine output binary name
        let outName =
            when defined(windows):
            absolutePath(splitFile(filename).name & ".exe")
        else:
            absolutePath(splitFile(filename).name)

        # Compile LLVM IR to binary with maximum size optimization
        try:
            let cmd =
                when defined(windows):
                    "clang " & irFile & " -O3 -Os -flto -fuse-ld=lld -ffunction-sections -fdata-sections -Wl,/SUBSYSTEM:CONSOLE,/DEBUG:NONE,/OPT:REF,/OPT:ICF,/ENTRY:_start -lkernel32 -o " & outName
                else:
                    "clang " & irFile & " -o " & outName & " -O3 -Os -flto -fuse-ld=lld -ffunction-sections -fdata-sections -Wl,--gc-sections -s -nostartfiles -e _start"

            let result = execProcess(
                cmd,
                options = {poUsePath, poEvalCommand, poStdErrToStdOut}
            )

            if result.strip() != "":
                echo "[*] Clang Output: ", result

                if "-zip" in args:
                    let zipCmd =
                        when defined(windows):
                            "tar.exe -a -c -f" & splitFile(filename).name &
                                    ".zip " & outName
                        else:
                            "zip " & splitFile(filename).name & ".zip " & outName

                    let result = execProcess(
                        zipCmd
                    )

                    if result.strip() != "":
                        echo "[*] Zip Output: ", result

        except OSError as e:
            echo "[!] Error running clang. Make sure clang is installed and in PATH."
            echo "Exception message: ", e.msg
            return

        cleanup(filename, args)

    else:
        # Just move IR file if -ir flag is passed
        try:
            moveFile(irFile, joinPath(splitFile(filename).dir, irFile))
        except OSError as e:
            echo "[!] Error moving IR file: ", e.msg

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
        discard # File doesn't exist, which is fine

    var commandsCalled = newSeq[string]()
    var commandNum = 0
    var printCalls = newSeq[string]() # Store the calls to print functions

    # Write global declarations first
    for lineNumber in 0 ..< totalLines:
        let line = readNthLineLargeFile(filename, lineNumber)

        var parser = initParser(line)
        let ast = parser.parse()

        let (irCode, newCommandsCalled, newCommandNum) = generateIR(ast,
                commandsCalled, commandNum)
        commandsCalled = newCommandsCalled
        commandNum = newCommandNum

        if irCode != "":
            writeIR(irCode, splitFile(filename).name & ".ll")
            # Store the call for later
            printCalls.add("  call i32 @print" & $(commandNum - 1) & "()")

    # Now write the _start function (custom entry point)
    writeIR("", splitFile(filename).name & ".ll") # Empty line for readability
    writeIR("define i32 @_start() {", splitFile(filename).name & ".ll")
    writeIR("entry:", splitFile(filename).name & ".ll")

    # Add all the print calls
    for call in printCalls:
        writeIR(call, splitFile(filename).name & ".ll")

    # Exit syscall for smallest binary (no libc exit)
    when defined(windows):
        writeIR("  ret i32 0", splitFile(filename).name & ".ll")
    else:
        # Linux syscall exit(0) - smallest possible exit
        writeIR("  call void asm sideeffect \"movl $$60, %eax; xorl %edi, %edi; syscall\", \"~{dirflag},~{fpsr},~{flags}\"()",
                splitFile(filename).name & ".ll")
        writeIR("  unreachable", splitFile(filename).name & ".ll")

    writeIR("}", splitFile(filename).name & ".ll")

    runLLVMIR(filename, args)
