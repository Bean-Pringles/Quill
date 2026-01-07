import tables

type
  IRGenerator* = proc(args: seq[string], commandsCalled: var seq[string], commandNum: int): (string, seq[string], int)

# IR generator registry - maps command names to IR generation procedures
var irGenerators* = initTable[string, IRGenerator]()

proc registerIRGenerator*(name: string, generator: IRGenerator) =
  irGenerators[name] = generator