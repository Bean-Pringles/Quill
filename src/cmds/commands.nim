# Auto-generated - do not edit manually

import system
import ../registry

include "let.nim"
include "print.nim"

proc initCommands*() =
  registerIRGenerator("let", letIRGenerator)
  registerIRGenerator("print", printIRGenerator)
