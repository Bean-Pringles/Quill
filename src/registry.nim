import tables

type
    IRGenerator* = proc(
        args: seq[string],
        commandsCalled: var seq[string],
        commandNum: int,
        vars: var Table[string, (string, string, int, bool)],
        target: string
    ): (string, seq[string], int, Table[string, (string, string, int, bool)])
var irGenerators* = initTable[string, IRGenerator]()

proc registerIRGenerator*(name: string, generator: IRGenerator) =
    irGenerators[name] = generator
