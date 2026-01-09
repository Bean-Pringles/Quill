import tables

type
    IRGenerator* = proc(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[system.string, (string, string, int)]): (string, seq[string], int, Table[system.string, (string, string, int)])

var irGenerators* = initTable[string, IRGenerator]()

proc registerIRGenerator*(name: string, generator: IRGenerator) =
    irGenerators[name] = generator
