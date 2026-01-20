# Auto-generated - do not edit manually

import system
import ../registry
import tables
import strutils

include "const.nim"
include "let.nim"
include "print.nim"

proc initCommands*() =
  registerIRGenerator("const", constIRGenerator)
  registerIRGenerator("let", letIRGenerator)
  registerIRGenerator("print", printIRGenerator)
