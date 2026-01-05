import os, strutils

# Generate the commands.nim file that includes all commands
var includeContent = "# Auto-generated - do not edit manually\n\n"

for file in walkDir("cmds"):
    if file.kind == pcFile and file.path.endsWith(".nim") and
            not file.path.endsWith("commands.nim"):
        let moduleName = file.path.splitFile().name
        includeContent.add("include \"" & moduleName & ".nim\"\n")

writeFile("cmds/commands.nim", includeContent)
echo "Generated cmds/commands.nim with all command imports"
