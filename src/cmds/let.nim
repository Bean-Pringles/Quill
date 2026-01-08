import tables
import strutils

proc letIRGenerator*(args: seq[string], commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string)]): (
        string, seq[string], int, Table[string, (string, string)]) =
    ## Generates IR for let statement: let x: i32 = 4
    ## args[0] = variable name (x)
    ## args[1] = type (i32)
    ## args[2] = value (4)
    
    if args.len != 3:
        echo "Error: let command requires 3 arguments (name, type, value)"
        return ("", commandsCalled, commandNum, vars)
    
    let varName = args[0]
    let varType = args[1]
    let value = args[2]
    
    # Store variable in the vars table with its type and value
    vars[varName] = (varType, value)
    
    # Return empty string - let statements don't generate function definitions
    # They will be inserted into _start function by the compiler
    return ("", commandsCalled, commandNum, vars)