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

proc parseArgument(p: var Parser): Node =
    p.skipWhitespace()

    if p.currentChar == '\0':
        return Node(isCall: false, value: "")

    if p.currentChar in {'"', '\''}:
        # Include quotes in the value so let/print can handle them
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        return Node(isCall: false, value: quoteChar & stringContent & quoteChar)

    if p.currentChar.isAlphaAscii() or p.currentChar == '_':
        return Node(isCall: false, value: p.parseIdentifier())

    return Node(isCall: false, value: "")

proc parseLetStatement(p: var Parser): Node =
    ## Parses: let x: i32 = 4 OR let x: string = "Hello"
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
    
    # Parse value - handle strings specially
    var value = ""
    if p.currentChar in {'"', '\''}:
        # Parse string literal with quotes
        let quoteChar = p.currentChar
        let stringContent = p.parseString()
        value = quoteChar & stringContent & quoteChar
    else:
        # Parse numeric or identifier value
        while p.currentChar != '\0' and not (p.currentChar in Whitespace):
            value.add(p.currentChar)
            p.advance()
    
    # Create a let command node with args: [varName, varType, value]
    result = Node(
        isCall: true,
        commandName: "let",
        args: @[
            Node(isCall: false, value: varName),
            Node(isCall: false, value: varType),
            Node(isCall: false, value: value)
        ]
    )

proc parseCommandCall(p: var Parser): Node =
    p.skipWhitespace()

    let commandName = p.parseIdentifier()
    p.skipWhitespace()
    
    # Special handling for "let" statement
    if commandName == "let":
        return p.parseLetStatement()

    if p.currentChar != '(':
        return Node(isCall: false, value: commandName)

    p.advance()
    var args: seq[Node] = @[]

    while p.currentChar != '\0' and p.currentChar != ')':
        p.skipWhitespace()
        if p.currentChar == ')':
            break

        let arg = p.parseArgument()
        if arg.value != "":
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

proc generateIR*(node: Node, commandsCalled: var seq[string], commandNum: int, vars: var Table[string, (string, string, int)]): (
        string, seq[string], int, Table[string, (string, string, int)]) =
    ## Generates IR code from the parsed command AST
    ## Updated to use 3-tuple: (llvmType, value, stringLength)
    if node.isCall:
        if reg.irGenerators.hasKey(node.commandName):
            var argStrings: seq[string] = @[]
            for arg in node.args:
                argStrings.add(arg.value)
            return reg.irGenerators[node.commandName](argStrings,
                    commandsCalled, commandNum, vars)
        else:
            echo "Unknown command: ", node.commandName
            return ("", commandsCalled, commandNum, vars)
    else:
        return ("", commandsCalled, commandNum, vars)