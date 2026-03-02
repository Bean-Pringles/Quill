# Auto-generated — do not edit manually
# Run:  nim e scripts/build_commands.nim

import global
import system
import ../registry
import ../importstate
import tables
import strutils
import os

include "assign.nim"
include "const.nim"
include "import.nim"
include "input.nim"
include "let.nim"
include "print.nim"
include "stdlib/os/clrscr.nim"
include "stdlib/os/sleep.nim"
include "stdlib/rand/randint.nim"

proc initCommands*() =
  registerIRGenerator("assign", assignIRGenerator)
  registerIRGenerator("const", constIRGenerator)
  registerIRGenerator("import", importIRGenerator)
  registerIRGenerator("input", inputIRGenerator)
  registerIRGenerator("let", letIRGenerator)
  registerIRGenerator("print", printIRGenerator)
  registerIRGenerator("os.clrscr", osclrscrIRGenerator)
  registerIRGenerator("os.sleep", ossleepIRGenerator)
  registerIRGenerator("rand.randint", randrandintIRGenerator)
