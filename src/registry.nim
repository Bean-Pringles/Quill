import tables

type
    IRGenerator* = proc(
        args: seq[string],
        commandsCalled: var seq[string],
        commandNum: int,
        vars: var Table[string, (string, string, int, bool)],
        cmdVal: seq[string],
        target: string, 
        lineNumber: int
    ): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string])
var irGenerators* = initTable[string, IRGenerator]()

proc registerIRGenerator*(name: string, generator: IRGenerator) =
    irGenerators[name] = generator
