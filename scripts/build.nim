import os, strutils

# Get the directory where this script lives
let scriptPath = currentSourcePath()
let (scriptDir, _) = splitPath(scriptPath)
let startingDir = getCurrentDir()

# Paths
let cmdsDir = os.joinPath(parentDir(scriptDir), "src", "cmds")
let outFile = os.joinPath(cmdsDir, "commands.nim")

# Auto-generate content
var includeContent = """# Auto-generated - do not edit manually

import system
import ../registry
import tables
import strutils

"""

var commandNames: seq[string] = @[]

for file in walkDir(cmdsDir):
  if file.kind == pcFile and
     not file.path.endsWith("commands.nim") and
     file.path.endsWith(".nim"):
    let moduleName = file.path.splitFile().name
    includeContent &= "include \"" & moduleName & ".nim\"\n"
    commandNames.add(moduleName)

# Add the initCommands procedure
includeContent &= "\nproc initCommands*() =\n"
for cmdName in commandNames:
  includeContent &= "  registerIRGenerator(\"" & cmdName & "\", " & cmdName & "IRGenerator)\n"

# Write the file
writeFile(outFile, includeContent)

# Restore original dir
os.setCurrentDir(startingDir)

echo "Generated cmds/commands.nim with all command imports"