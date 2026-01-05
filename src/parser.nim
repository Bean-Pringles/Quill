type
    Node = ref object
        case isCall: bool
        of true:
            commandName: string
            args: seq[Node]
        of false:
            value: string

    Parser = object
        text: string
        pos: int
        currentChar: char

    CommandProc = proc(args: seq[string])

# Command registry - this will be populated by each command module
var commandRegistry* = initTable[string, CommandProc]()

proc registerCommand*(name: string, cmdProc: CommandProc) =
    commandRegistry[name] = cmdProc

proc initParser(text: string): Parser =
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
        return Node(isCall: false, value: p.parseString())

    if p.currentChar.isAlphaAscii() or p.currentChar == '_':
        return Node(isCall: false, value: p.parseIdentifier())

    return Node(isCall: false, value: "")

proc parseCommandCall(p: var Parser): Node =
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

proc parse(p: var Parser): Node =
    return p.parseCommandCall()

proc executeCommand(node: Node) =
    if node.isCall:
        if commandRegistry.hasKey(node.commandName):
            var argStrings: seq[string] = @[]
            for arg in node.args:
                argStrings.add(arg.value)
            commandRegistry[node.commandName](argStrings)
        else:
            echo "Unknown command: ", node.commandName