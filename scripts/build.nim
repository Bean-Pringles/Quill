import os, strutils, sequtils

let scriptPath = currentSourcePath()
let (scriptDir, _) = splitPath(scriptPath)
let startingDir = getCurrentDir()

let srcDir    = os.joinPath(parentDir(scriptDir), "src")
let cmdsDir   = os.joinPath(srcDir, "cmds")
let stdlibDir = os.joinPath(cmdsDir, "stdlib")
let outFile   = os.joinPath(cmdsDir, "commands.nim")

type Entry = object
  includePath : string
  registerKey : string   # "clrscreen" or "os.clrscreen"
  procName    : string   # "clrscreenIRGenerator" or "osclrscreenIRGenerator"

var entries: seq[Entry]

for file in walkDir(cmdsDir):
  if file.kind == pcFile and
     not file.path.endsWith("commands.nim") and
     file.path.endsWith(".nim"):
    let modName = file.path.splitFile().name
    entries.add Entry(
      includePath: modName & ".nim",
      registerKey: modName,
      procName   : modName & "IRGenerator"
    )

if dirExists(stdlibDir):
  for libDir in walkDir(stdlibDir):
    if libDir.kind == pcDir:
      let libName = libDir.path.splitPath().tail   # "os"
      for file in walkDir(libDir.path):
        if file.kind == pcFile and file.path.endsWith(".nim"):
          let cmdName = file.path.splitFile().name  # "clrscreen"
          entries.add Entry(
            includePath: "stdlib/" & libName & "/" & cmdName & ".nim",
            registerKey: libName & "." & cmdName,   # "os.clrscreen"
            procName   : libName & cmdName & "IRGenerator" # "osclrscreenIRGenerator"
          )

var content = """# Auto-generated — do not edit manually
# Run:  nim e scripts/build_commands.nim

import system
import ../registry
import ../importstate
import tables
import strutils
import os

"""

for e in entries:
  content &= "include \"" & e.includePath & "\"\n"

content &= "\nproc initCommands*() =\n"
if entries.len == 0:
  content &= "  discard\n"
else:
  for e in entries:
    content &= "  registerIRGenerator(\"" & e.registerKey & "\", " & e.procName & ")\n"

writeFile(outFile, content)
os.setCurrentDir(startingDir)

echo "Generated cmds/commands.nim"
echo "  Top-level : ", entries.filterIt('.' notin it.registerKey).len
echo "  Stdlib    : ", entries.filterIt('.' in  it.registerKey).len