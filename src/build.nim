import os, strutils

# Auto-generate the commands.nim file
var includeContent = """
# Auto-generated - do not edit manually

import std/os
import strutils
import tables
"""

for file in walkDir("cmds"):
  if file.kind == pcFile and
     not file.path.endsWith("commands.nim") and
     file.path.endsWith(".nim"):
    let moduleName = file.path.splitFile().name
    includeContent &= "include \"" & moduleName & ".nim\"\n"

writeFile("cmds/commands.nim", includeContent)
echo "Generated cmds/commands.nim with all command imports"
