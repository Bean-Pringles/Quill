import tables
import strutils
import registry as reg # Import the shared registry with alias

type
    Node* = ref object
        case isCall*: bool
        of true:
            commandName*: string
            args*: seq[Node]
        of false:
            value*: string

    Parser = object
        text: string
        pos: int
        currentChar: char

proc initParser*(text: string): Parser =
    result.text = text
    result.pos = 0
    result.currentChar = if text.len > 0: text[0] else: '\0'

proc advance(p: var Parser) =
    p.pos += 1
    if p.pos < p.text.len:
        p.currentChar = p.text[p.pos]
    else:
        p.currentChar = '\0'

proc skipWhitespace(p: var Parser) =
    while p.currentChar != '\0' and p.currentChar in Whitespace:
        p.advance()

proc parseString(p: var Parser): string =
    let quoteChar = p.currentChar
    p.advance()
    result = ""
    while p.currentChar != '\0' and p.currentChar != quoteChar:
        result.add(p.currentChar)
        p.advance()
    if p.currentChar == quoteChar:
        p.advance()

proc parseIdentifier(p: var Parser): string =
    result = ""
    while p.currentChar != '\0' and (p.currentChar.isAlphaNumeric() or
            p.currentChar == '_'):
        result.add(p.currentChar)
        p.advance()

# Forward declaration
proc parseExpression(p: var Parser): Node

proc parseArgument(p: var Parser): Node =
    p.skipWhitespace()

    if p.currentChar == '\0':
        return Node(isCall: false, value: "")

    if p.currentChar in {'"', '\''}:
        # Include quotes in the value so let/print can handle them
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        return Node(isCall: false, value: quoteChar & stringContent & quoteChar)

    # Check if this is a command call (identifier followed by '(')
    if p.currentChar.isAlphaAscii() or p.currentChar == '_':
        let startPos = p.pos
        let identifier = p.parseIdentifier()
        p.skipWhitespace()
        
        # If followed by '(', it's a command call
        if p.currentChar == '(':
            # Reset and parse as expression/command
            p.pos = startPos
            p.currentChar = p.text[p.pos]
            return p.parseExpression()
        else:
            # Just an identifier/variable reference
            return Node(isCall: false, value: identifier)

    return Node(isCall: false, value: "")

proc parseLetStatement(p: var Parser, commandName: string): Node =
    ## Parses: let/const/var x: i32 = 4 OR let/const/var x: string = "Hello" OR let x: string = input("Hi")
    p.skipWhitespace()
    
    # Parse variable name
    let varName = p.parseIdentifier()
    p.skipWhitespace()
    
    # Expect ':'
    if p.currentChar != ':':
        echo "Expected ':' after variable name"
        return Node(isCall: false, value: "")
    p.advance()
    p.skipWhitespace()
    
    # Parse type
    let varType = p.parseIdentifier()
    p.skipWhitespace()
    
    # Expect '='
    if p.currentChar != '=':
        echo "Expected '=' after type"
        return Node(isCall: false, value: "")
    p.advance()
    p.skipWhitespace()
    
    # Parse value - can be a string, number, identifier, or command call
    var valueNode: Node
    if p.currentChar in {'"', '\''}:
        # Parse string literal with quotes
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        valueNode = Node(isCall: false, value: quoteChar & stringContent & quoteChar)
    elif p.currentChar.isAlphaAscii() or p.currentChar == '_':
        # Could be identifier or command call
        let startPos = p.pos
        let identifier = p.parseIdentifier()
        p.skipWhitespace()
        
        if p.currentChar == '(':
            # It's a command call - reset and parse it
            p.pos = startPos
            p.currentChar = p.text[p.pos]
            valueNode = p.parseExpression()
        else:
            # Just an identifier or number
            valueNode = Node(isCall: false, value: identifier)
    else:
        # Parse numeric value
        var value: string
        while p.currentChar != '\0' and not (p.currentChar in Whitespace):
            value.add(p.currentChar)
            p.advance()
        valueNode = Node(isCall: false, value: value)
    
    # Create a command node with the actual command name (let/const/var)
    result = Node(
        isCall: true,
        commandName: commandName,
        args: @[
            Node(isCall: false, value: varName),
            Node(isCall: false, value: varType),
            valueNode  # This can now be a command call node
        ]
    )

proc parseAssignment(p: var Parser, varName: string): Node =
    ## Parses: varname = value (where value can be a command call)
    p.skipWhitespace()
    
    # Expect '='
    if p.currentChar != '=':
        echo "Expected '=' in assignment"
        return Node(isCall: false, value: "")
    p.advance()
    p.skipWhitespace()
    
    # Parse value - can be a string, number, identifier, or command call
    var valueNode: Node
    if p.currentChar in {'"', '\''}:
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        valueNode = Node(isCall: false, value: quoteChar & stringContent & quoteChar)
    elif p.currentChar.isAlphaAscii() or p.currentChar == '_':
        # Could be identifier or command call
        let startPos = p.pos
        let identifier = p.parseIdentifier()
        p.skipWhitespace()
        
        if p.currentChar == '(':
            # It's a command call - reset and parse it
            p.pos = startPos
            p.currentChar = p.text[p.pos]
            valueNode = p.parseExpression()
        else:
            # Just an identifier
            valueNode = Node(isCall: false, value: identifier)
    else:
        # Parse numeric value
        var value: string
        while p.currentChar != '\0' and not (p.currentChar in Whitespace):
            value.add(p.currentChar)
            p.advance()
        valueNode = Node(isCall: false, value: value)
    
    result = Node(
        isCall: true,
        commandName: "assign",
        args: @[
            Node(isCall: false, value: varName),
            valueNode  # This can now be a command call node
        ]
    )

proc parseExpression(p: var Parser): Node =
    ## Parses a command call expression
    p.skipWhitespace()

    let commandName = p.parseIdentifier()
    p.skipWhitespace()

    if p.currentChar != '(':
        return Node(isCall: false, value: commandName)

    p.advance()
    var args: seq[Node] = @[]

    while p.currentChar != '\0' and p.currentChar != ')':
        p.skipWhitespace()
        if p.currentChar == ')':
            break

        let arg = p.parseArgument()  # This now supports nested calls
        if arg.isCall or arg.value != "":
            args.add(arg)

        p.skipWhitespace()
        if p.currentChar == ',':
            p.advance()
        elif p.currentChar != ')':
            break

    if p.currentChar == ')':
        p.advance()

    result = Node(isCall: true, commandName: commandName, args: args)

proc parseCommandCall(p: var Parser): Node =
    p.skipWhitespace()

    let commandName = p.parseIdentifier()
    p.skipWhitespace()

    # Special handling for "let", "const", statements
    if commandName in ["let", "const"]:
        return p.parseLetStatement(commandName)
    
    # Check if it's an assignment (varname = value)
    if p.currentChar == '=':
        return p.parseAssignment(commandName)

    if p.currentChar != '(':
        return Node(isCall: false, value: commandName)

    p.advance()
    var args: seq[Node] = @[]

    while p.currentChar != '\0' and p.currentChar != ')':
        p.skipWhitespace()
        if p.currentChar == ')':
            break

        let arg = p.parseArgument()  # This now supports nested calls
        if arg.isCall or arg.value != "":
            args.add(arg)

        p.skipWhitespace()
        if p.currentChar == ',':
            p.advance()
        elif p.currentChar != ')':
            break

    if p.currentChar == ')':
        p.advance()

    result = Node(isCall: true, commandName: commandName, args: args)

proc parse*(p: var Parser): Node =
    return p.parseCommandCall()

proc generateIR*(node: Node, commandsCalled: var seq[string], commandNum: var int, vars: var Table[string, (string, string, int, bool)], cmdVal: var seq[string], target: string, lineNumber: int): (
        string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =
    # Returns: (globalDecl, functionDef, entryCode, commandsCalled, commandNum, vars, cmdVal)
    # Generates IR code from the parsed command AST
    if node.isCall:
        if reg.irGenerators.hasKey(node.commandName):
            var argStrings: seq[string] = @[]
            var argCmdVals: seq[string] = @[]  # Track cmdVal for each arg
            
            # Accumulate nested IR code
            var accumulatedGlobals: seq[string] = @[]
            var accumulatedFunctions: seq[string] = @[]
            var accumulatedEntry: seq[string] = @[]
            
            for arg in node.args:
                # Handle nested command calls
                if arg.isCall:
                    # Recursively generate IR for nested command
                    var nestedCmdVal: seq[string] = @[]
                    let (nestedGlobal, nestedFunc, nestedEntry, nestedCalls, nestedNum, nestedVars, returnedCmdVal) = 
                        generateIR(arg, commandsCalled, commandNum, vars, nestedCmdVal, target, lineNumber)
                    
                    # Update state from nested call
                    commandsCalled = nestedCalls
                    commandNum = nestedNum
                    vars = nestedVars
                    
                    # Accumulate the nested IR code
                    if nestedGlobal != "":
                        accumulatedGlobals.add(nestedGlobal)
                    if nestedFunc != "":
                        accumulatedFunctions.add(nestedFunc)
                    if nestedEntry != "":
                        accumulatedEntry.add(nestedEntry)
                    
                    # Pass the cmdVal from the nested call as the argument
                    if returnedCmdVal.len > 0:
                        argStrings.add(returnedCmdVal[0])
                        argCmdVals.add(returnedCmdVal[0])
                    else:
                        argStrings.add("")
                        argCmdVals.add("")
                else:
                    argStrings.add(arg.value)
                    argCmdVals.add("")  # No cmdVal for literal values
            
            let (globalDecl, functionDef, entryCode, newCommandsCalled, newCommandNum, newVars, returnedCmdVal) = 
                reg.irGenerators[node.commandName](argStrings, commandsCalled, commandNum, vars, argCmdVals, target, lineNumber)
            
            cmdVal = returnedCmdVal  # Update the output cmdVal
            
            # Combine accumulated nested IR with parent IR
            var finalGlobal: string
            var finalFunction: string
            var finalEntry: string
            
            # Add accumulated nested code first
            if accumulatedGlobals.len > 0:
                finalGlobal = accumulatedGlobals.join("\n")
            if accumulatedFunctions.len > 0:
                finalFunction = accumulatedFunctions.join("\n")
            if accumulatedEntry.len > 0:
                finalEntry = accumulatedEntry.join("\n")
            
            # Then add parent code
            if globalDecl != "":
                if finalGlobal != "":
                    finalGlobal = finalGlobal & "\n" & globalDecl
                else:
                    finalGlobal = globalDecl
            
            if functionDef != "":
                if finalFunction != "":
                    finalFunction = finalFunction & "\n" & functionDef
                else:
                    finalFunction = functionDef
            
            if entryCode != "":
                if finalEntry != "":
                    finalEntry = finalEntry & "\n" & entryCode
                else:
                    finalEntry = entryCode
            
            # CRITICAL FIX: Handle runtime values for let/const commands
            # Generate the store AFTER nested commands have executed
            if node.commandName in ["let", "const"] and returnedCmdVal.len == 0 and target in ["exe", "ir", "zip"]:
                # Check if the variable was marked as a command result
                let varName = argStrings[0]
                if varName in newVars:
                    let (varType, value, strLen, isCommandResult) = newVars[varName]
                    if isCommandResult and varType == "ptr":
                        # Generate the store NOW, after nested commands have run
                        let storeCode = "  store ptr " & value & ", ptr %" & varName & ", align 8"
                        
                        # Add it to finalEntry AFTER accumulated nested code
                        if finalEntry != "":
                            finalEntry = finalEntry & "\n" & storeCode
                        else:
                            finalEntry = storeCode
            
            return (finalGlobal, finalFunction, finalEntry, newCommandsCalled, newCommandNum, newVars, returnedCmdVal)
        else:
            echo "Unknown command: ", node.commandName
            return ("", "", "", commandsCalled, commandNum, vars, @[])
    else:
        return ("", "", "", commandsCalled, commandNum, vars, @[])