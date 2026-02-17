import tables
import strutils
import registry as reg

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
    ## Parses a plain identifier: letters, digits, underscores.
    ## Does NOT consume dots — dot-chaining is handled at call sites.
    result = ""
    while p.currentChar != '\0' and (p.currentChar.isAlphaNumeric() or p.currentChar == '_'):
        result.add(p.currentChar)
        p.advance()

proc parseDottedIdentifier(p: var Parser): string =
    ## Parses "identifier" or "lib.command" — consumes one optional dot segment.
    ## e.g. "os.clrscreen"  or just  "print"
    result = p.parseIdentifier()
    if p.currentChar == '.' and result.len > 0:
        p.advance()  # consume the '.'
        let rhs = p.parseIdentifier()
        if rhs.len == 0:
            echo "[!] Parse error: expected command name after '.'"
            quit(1)
        result = result & "." & rhs

# Forward declaration
proc parseExpression(p: var Parser): Node

proc parseArgument(p: var Parser): Node =
    p.skipWhitespace()

    if p.currentChar == '\0':
        return Node(isCall: false, value: "")

    if p.currentChar in {'"', '\''}:
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        return Node(isCall: false, value: quoteChar & stringContent & quoteChar)

    if p.currentChar.isAlphaAscii() or p.currentChar == '_':
        let startPos = p.pos
        let startChar = p.currentChar
        let identifier = p.parseDottedIdentifier()
        p.skipWhitespace()

        if p.currentChar == '(':
            # Reset and parse as a full expression
            p.pos = startPos
            p.currentChar = startChar
            return p.parseExpression()
        else:
            return Node(isCall: false, value: identifier)

    # Numeric or other literal
    var value: string
    while p.currentChar != '\0' and p.currentChar != ',' and
          p.currentChar != ')' and not (p.currentChar in Whitespace):
        value.add(p.currentChar)
        p.advance()
    return Node(isCall: false, value: value)

proc parseLetStatement(p: var Parser, commandName: string): Node =
    ## let/const x: type = value_or_call
    p.skipWhitespace()

    let varName = p.parseIdentifier()
    p.skipWhitespace()

    if p.currentChar != ':':
        echo "[!] Parse error: expected ':' after variable name in '" & commandName & "'"
        quit(1)
    p.advance()
    p.skipWhitespace()

    let varType = p.parseIdentifier()
    p.skipWhitespace()

    if p.currentChar != '=':
        echo "[!] Parse error: expected '=' after type in '" & commandName & "'"
        quit(1)
    p.advance()
    p.skipWhitespace()

    var valueNode: Node
    if p.currentChar in {'"', '\''}:
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        valueNode = Node(isCall: false, value: quoteChar & stringContent & quoteChar)
    elif p.currentChar.isAlphaAscii() or p.currentChar == '_':
        let startPos = p.pos
        let startChar = p.currentChar
        let identifier = p.parseDottedIdentifier()
        p.skipWhitespace()
        if p.currentChar == '(':
            p.pos = startPos
            p.currentChar = startChar
            valueNode = p.parseExpression()
        else:
            valueNode = Node(isCall: false, value: identifier)
    else:
        var value: string
        while p.currentChar != '\0' and not (p.currentChar in Whitespace):
            value.add(p.currentChar)
            p.advance()
        valueNode = Node(isCall: false, value: value)

    result = Node(
        isCall: true,
        commandName: commandName,
        args: @[
            Node(isCall: false, value: varName),
            Node(isCall: false, value: varType),
            valueNode
        ]
    )

proc parseAssignment(p: var Parser, varName: string): Node =
    ## varname = value_or_call
    p.skipWhitespace()

    if p.currentChar != '=':
        echo "[!] Parse error: expected '=' in assignment"
        quit(1)
    p.advance()
    p.skipWhitespace()

    var valueNode: Node
    if p.currentChar in {'"', '\''}:
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        valueNode = Node(isCall: false, value: quoteChar & stringContent & quoteChar)
    elif p.currentChar.isAlphaAscii() or p.currentChar == '_':
        let startPos = p.pos
        let startChar = p.currentChar
        let identifier = p.parseDottedIdentifier()
        p.skipWhitespace()
        if p.currentChar == '(':
            p.pos = startPos
            p.currentChar = startChar
            valueNode = p.parseExpression()
        else:
            valueNode = Node(isCall: false, value: identifier)
    else:
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
            valueNode
        ]
    )

proc parseImportStatement(p: var Parser): Node =
    ## import <libname>   — no parens, compile-time directive
    p.skipWhitespace()
    let libName = p.parseIdentifier()
    if libName.len == 0:
        echo "[!] Parse error: expected library name after 'import'"
        quit(1)
    result = Node(
        isCall: true,
        commandName: "import",
        args: @[Node(isCall: false, value: libName)]
    )

proc parseExpression(p: var Parser): Node =
    ## Parses a command call: name(...) or lib.cmd(...)
    p.skipWhitespace()

    let commandName = p.parseDottedIdentifier()
    p.skipWhitespace()

    if p.currentChar != '(':
        return Node(isCall: false, value: commandName)

    p.advance()  # consume '('
    var args: seq[Node] = @[]

    while p.currentChar != '\0' and p.currentChar != ')':
        p.skipWhitespace()
        if p.currentChar == ')': break

        let arg = p.parseArgument()
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

    let commandName = p.parseDottedIdentifier()
    p.skipWhitespace()

    # Compile-time keywords — no parens
    if commandName == "import":
        return p.parseImportStatement()

    # Declaration keywords
    if commandName in ["let", "const"]:
        return p.parseLetStatement(commandName)

    # Assignment: plain identifier followed immediately by '='
    # (dotted names can't be assigned to)
    if p.currentChar == '=' and '.' notin commandName:
        return p.parseAssignment(commandName)

    # Regular command call with parens
    if p.currentChar != '(':
        return Node(isCall: false, value: commandName)

    p.advance()  # consume '('
    var args: seq[Node] = @[]

    while p.currentChar != '\0' and p.currentChar != ')':
        p.skipWhitespace()
        if p.currentChar == ')': break

        let arg = p.parseArgument()
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

proc generateIR*(
    node: Node,
    commandsCalled: var seq[string],
    commandNum: var int,
    vars: var Table[string, (string, string, int, bool)],
    cmdVal: var seq[string],
    target: string,
    lineNumber: int
): (string, string, string, seq[string], int, Table[string, (string, string, int, bool)], seq[string]) =

    if not node.isCall:
        return ("", "", "", commandsCalled, commandNum, vars, @[])

    # Resolve the command — enforces import rules, quits on unknown commands
    let resolvedKey = reg.resolveCommand(node.commandName, lineNumber)

    var argStrings: seq[string] = @[]
    var argCmdVals: seq[string] = @[]
    var accumulatedGlobals: seq[string] = @[]
    var accumulatedFunctions: seq[string] = @[]
    var accumulatedEntry: seq[string] = @[]

    for arg in node.args:
        if arg.isCall:
            var nestedCmdVal: seq[string] = @[]
            let (nestedGlobal, nestedFunc, nestedEntry, nestedCalls, nestedNum, nestedVars, returnedCmdVal) =
                generateIR(arg, commandsCalled, commandNum, vars, nestedCmdVal, target, lineNumber)

            commandsCalled = nestedCalls
            commandNum = nestedNum
            vars = nestedVars

            if nestedGlobal != "": accumulatedGlobals.add(nestedGlobal)
            if nestedFunc   != "": accumulatedFunctions.add(nestedFunc)
            if nestedEntry  != "": accumulatedEntry.add(nestedEntry)

            if returnedCmdVal.len > 0:
                argStrings.add(returnedCmdVal[0])
                argCmdVals.add(returnedCmdVal[0])
            else:
                argStrings.add("")
                argCmdVals.add("")
        else:
            argStrings.add(arg.value)
            argCmdVals.add("")

    let (globalDecl, functionDef, entryCode, newCommandsCalled, newCommandNum, newVars, returnedCmdVal) =
        reg.irGenerators[resolvedKey](argStrings, commandsCalled, commandNum, vars, argCmdVals, target, lineNumber)

    cmdVal = returnedCmdVal

    # Combine nested + parent IR
    var finalGlobal   = accumulatedGlobals.join("\n")
    var finalFunction = accumulatedFunctions.join("\n")
    var finalEntry    = accumulatedEntry.join("\n")

    if globalDecl  != "": finalGlobal   = (if finalGlobal   != "": finalGlobal   & "\n" else: "") & globalDecl
    if functionDef != "": finalFunction = (if finalFunction != "": finalFunction & "\n" else: "") & functionDef
    if entryCode   != "": finalEntry    = (if finalEntry    != "": finalEntry    & "\n" else: "") & entryCode

    # Handle runtime store for let/const whose value came from a command call
    if node.commandName in ["let", "const"] and returnedCmdVal.len == 0 and target in ["exe", "ir", "zip"]:
        let varName = argStrings[0]
        if varName in newVars:
            let (varType, value, _, isCommandResult) = newVars[varName]
            if isCommandResult and varType == "ptr":
                let storeCode = "  store ptr " & value & ", ptr %" & varName & ", align 8"
                finalEntry = (if finalEntry != "": finalEntry & "\n" else: "") & storeCode

    return (finalGlobal, finalFunction, finalEntry, newCommandsCalled, newCommandNum, newVars, returnedCmdVal)