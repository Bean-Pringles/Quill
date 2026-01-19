import std/os
import osproc
import strutils
import system
import tables
import parser
import cmds/commands
import fileWriter

# Targets
import targets/llvm
import targets/batch

# Initialize commands BEFORE processing any files
initCommands()

# This reads the current line, so that the compiler can process it
proc readNthLineLargeFile(filename: string, n: int): string =
    var currentLine = 0
    for line in lines(filename):
        if currentLine == n:
            return line
        inc currentLine
    raise newException(IndexDefect, "[!] Error in reading file.")

# Gets total lines in file so that the compiler does not try to read past the end of the file
proc countLinesInFile(filePath: string): int =
    var lineCount = 0
    try:
        for _ in lines(filePath):
            inc lineCount
    except OSError:
        echo "[!] Could not open or read file: ", filePath
        return -1
    return lineCount

# Moves the file back to the same dir as the src file
proc moveOutputFile(filename: string, target: string) =
    var filePath = ""

    case target
    of "exe":
        filePath = when defined(windows):
            absolutePath(splitFile(filename).name & ".exe")
        else:
            absolutePath(splitFile(filename).name)
        
        # Deletes the IR file
        try:
            removeFile(absolutePath(splitFile(filename).name & ".ll"))
        except OSError:
            echo "[!] Could not remove intermediate IR file."
            
    of "zip":
        filePath = splitFile(filename).name & ".zip"

        # Deletes exe and IR file
        try:
            removeFile(absolutePath(splitFile(filename).name & ".ll"))
        except OSError:
            echo "[!] Could not remove intermediate IR file."

        let exePath =
            when defined(windows):
                absolutePath(splitFile(filename).name & ".exe")
            else:
                absolutePath(splitFile(filename).name)

        try:
            removeFile(exePath)
        except OSError:
            echo "[!] Could not remove intermediate EXE file."

    of "ir":
        filePath = splitFile(filename).name & ".ll"
    of "batch":
        filePath = splitFile(filename).name & ".bat"
    else:
        return
    
    # Moves the file back to the same dir as the src file
    try:
        let dest = joinPath(splitFile(filename).dir, extractFilename(filePath))
        os.moveFile(filePath, dest)
    except OSError as e:
        echo "[!] Error moving ", target, " file: ", e.msg

# Runs LLVM on the src IR file with all optimizatons
proc runLLVMIR(filename: string, args: seq[string], target: string) =
    let irFile = splitFile(filename).name & ".ll"
    
    if target in ["exe", "ir", "zip"]:
        if not fileExists(irFile):
            echo "[!] IR file not found: ", irFile
            return
    
    if target in ["exe", "zip"]:
        let outName = when defined(windows):
                absolutePath(splitFile(filename).name & ".exe")
            else:
                absolutePath(splitFile(filename).name)
        
        try:
            # Generates the LLVM command and runs it
            let cmd = when defined(windows):
                    "clang " & irFile & " -O3 -Os -flto -fuse-ld=lld -Wno-override-module -ffunction-sections -fdata-sections -Wl,/SUBSYSTEM:CONSOLE,/DEBUG:NONE,/OPT:REF,/OPT:ICF,/ENTRY:_start -lkernel32 -o " & outName
                else:
                    "clang " & irFile & " -o " & outName & " -O3 -Os -Wno-override-module -flto -fuse-ld=lld -ffunction-sections -fdata-sections -Wl,--gc-sections -s -nostartfiles -e _start"
            
            let result = execProcess(
                cmd,
                options = {poUsePath, poEvalCommand, poStdErrToStdOut}
            )
            
            if result.strip() != "":
                echo "[*] Clang Output: ", result
            
            # Zips the file using tar on Windows and zip on MacOS/Linux
            if target == "zip":
                let rel = relativePath(outName, getCurrentDir())
                let zipCmd = when defined(windows):
                        "tar.exe -a -c -f " & splitFile(filename).name & ".zip " & rel
                    else:
                        "zip " & splitFile(filename).name & ".zip " & outName
                
                let zipResult = execProcess(zipCmd)
                if zipResult.strip() != "":
                    echo "[*] Zip Output: ", zipResult
        
        # Catches if LLVM is not installed
        except OSError as e:
            echo "[!] Error running clang. Make sure clang is installed and in PATH."
            echo "Exception message: ", e.msg
            return
    
    # Calls the file mover
    moveOutputFile(filename, target)

when isMainModule:
    let args = commandLineParams()
    
    # With no args tells about the compiler
    if args.len == 0:
        echo "[*] Compiler and Language Written by Bean_Pringles. https://github.com/Bean_Pringles"
        quit(1)
    
    # Gets the filename and checks if it exists as well as it being a Quill file
    let filename = args[0]
    
    if not fileExists(filename):
        echo "[!] File not found: ", filename
        quit(1)
    
    let ext = splitFile(filename).ext
    if ext != ".qil":
        echo "[!] The ", ext, " filetype is not supported."
        quit(1)
    
    # Makes sure the file is not empty
    let totalLines = countLinesInFile(filename)
    if totalLines < 0:
        quit(1)
    
    # Gets rid of past IR files
    try:
        removeFile(splitFile(filename).name & ".ll")
    except OSError:
        discard
    
    # Init Vars
    var commandsCalled = newSeq[string]()
    var commandNum = 0
    var funcCalls = newSeq[string]()
    var vars = initTable[string, (string, string, int)]()

    var target = "exe"

    # Gets the target
    # Finds wehre the target is
    for arg in args:
        if arg.startsWith("-target="):
            target = arg["-target=".len .. ^1]

    # Make sure its a valid target
    if target notin ["exe", "ir", "zip", "batch"]:
        echo "[!] Invalid target specified: ", target
        quit(1)
        
    # Runs the file prep for each type
    if (target == "exe") or (target == "ir") or (target == "zip"):
        llvmPre(filename)
    
    elif target == "batch":
        batchPre(filename)


    # Main compiler loop
    for lineNumber in 0 ..< totalLines:
        # Gets line
        let line = readNthLineLargeFile(filename, lineNumber)
        # Makes parser object
        var parser = initParser(line)
        # Gets ast
        let ast = parser.parse()
        # Passes the arguements of the command for processing
        let (irCode, newCommandsCalled, newCommandNum, newVars) = generateIR(
                ast, commandsCalled, commandNum, vars, target)
        
        # Gets any changes and assigns them to the variables
        commandsCalled = newCommandsCalled
        commandNum = newCommandNum
        vars = newVars
        
        if target != "batch":
            # Makes sure code is not empty
            if irCode != "":
                # Writes the code
                writeCode(irCode, splitFile(filename).name & ".ll")
                
                # If this is a print command, store the call for later
                if irCode.contains("define i32 @print"):
                    funcCalls.add("  call i32 @print" & $(commandNum - 1) & "()")
        else:
            if irCode != "":
                # Writes batch code
                writeCode(irCode, splitFile(filename).name & ".bat")

    if target in ["exe", "ir", "zip"]:
        # Runs the ending clause for LLVM targets
        llvmPost(filename, vars, funcCalls)

    # Compiles the LLVM
    runLLVMIR(filename, args, target)