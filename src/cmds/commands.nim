# Auto-generated - do not edit manually

import system
import ../registry
import tables
import strutils

include "assign.nim"
include "const.nim"
include "input.nim"
include "let.nim"
include "print.nim"

proc initCommands*() =
  registerIRGenerator("assign", assignIRGenerator)
  registerIRGenerator("const", constIRGenerator)
  registerIRGenerator("input", inputIRGenerator)
  registerIRGenerator("let", letIRGenerator)
  registerIRGenerator("print", printIRGenerator)
