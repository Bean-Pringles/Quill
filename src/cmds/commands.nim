# Auto-generated - do not edit manually

import system
import ../registry

include "print.nim"

proc initCommands*() =
  registerIRGenerator("print", printIRGenerator)
