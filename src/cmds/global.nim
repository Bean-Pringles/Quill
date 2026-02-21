import math
import tables
import strutils

proc isCommand*(arg: string, vars: Table[string, (string, string, int,
        bool)]): bool =
    # Determine if argument is a command call (not a variable or string literal)
    if arg.len == 0:
        return false

    var strippedArg = arg.strip()

    # Check if it's a quoted string literal
    if strippedArg.len >= 2:
        if (strippedArg[0] == '"' and strippedArg[^1] == '"') or
           (strippedArg[0] == '\'' and strippedArg[^1] == '\''):
            return false

    # Check if it's a known user variable
    if strippedArg in vars:
        return false

    # Check if it's a number
    try:
        discard parseFloat(strippedArg)
        return false
    except:
        discard

    # If it doesn't have quotes, isn't a user variable, and isn't a number, it's a command
    return true

# Compile-time Expression Evaluator
type
    TokenKind = enum
        tkString, tkNumber, tkIdent, tkOperator, tkLParen, tkRParen, tkEOF

    Token = object
        kind: TokenKind
        value: string

proc tokenize(expr: string): seq[Token] =
    result = @[]
    var i = 0

    while i < expr.len:
        # Skip whitespace
        while i < expr.len and expr[i] in {' ', '\t', '\n', '\r'}:
            inc i

        if i >= expr.len:
            break

        # String literals
        if expr[i] in {'"', '\''}:
            let quote = expr[i]
            var str = ""
            inc i
            while i < expr.len and expr[i] != quote:
                if expr[i] == '\\' and i + 1 < expr.len:
                    inc i
                    case expr[i]
                    of 'n': str.add('\n')
                    of 't': str.add('\t')
                    of '\\': str.add('\\')
                    of '"': str.add('"')
                    of '\'': str.add('\'')
                    else: str.add(expr[i])
                else:
                    str.add(expr[i])
                inc i
            if i < expr.len:
                inc i # Skip closing quote
            result.add(Token(kind: tkString, value: str))

        # Numbers (including negative)
        elif expr[i] in {'0'..'9'} or (expr[i] == '-' and i + 1 < expr.len and
                expr[i+1] in {'0'..'9'}):
            var num = ""
            if expr[i] == '-':
                num.add('-')
                inc i
            while i < expr.len and (expr[i] in {'0'..'9', '.'}):
                num.add(expr[i])
                inc i
            result.add(Token(kind: tkNumber, value: num))

        # Operators - CHECK BEFORE identifiers to handle % as modulo
        elif expr[i] in {'+', '-', '*', '/', '%'}:
            result.add(Token(kind: tkOperator, value: $expr[i]))
            inc i

        # LLVM register identifiers (start with % followed by alphanumeric)
        elif expr[i] == '%' and i + 1 < expr.len and (expr[i+1].isAlphaNumeric() or expr[i+1] == '_'):
            var ident = ""
            ident.add('%')
            inc i
            while i < expr.len and (expr[i] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
                ident.add(expr[i])
                inc i
            result.add(Token(kind: tkIdent, value: ident))

        # Identifiers and function calls
        elif expr[i] in {'a'..'z', 'A'..'Z', '_'}:
            var ident = ""
            while i < expr.len and (expr[i] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
                ident.add(expr[i])
                inc i
            result.add(Token(kind: tkIdent, value: ident))

        # Parentheses
        elif expr[i] == '(':
            result.add(Token(kind: tkLParen, value: "("))
            inc i
        elif expr[i] == ')':
            result.add(Token(kind: tkRParen, value: ")"))
            inc i

        else:
            inc i # Skip unknown characters

    result.add(Token(kind: tkEOF, value: ""))

proc evalExpression*(
    expr: string,
    vars: Table[string, (string, string, int, bool)],
    target: string,
    lineNumber: int
): (string, string, bool) =
    # Returns: (result_value, result_type, is_runtime_value)
    # is_runtime_value = true means it's a variable reference or command result

    let tokens = tokenize(expr.strip())
    if tokens.len == 0 or (tokens.len == 1 and tokens[0].kind == tkEOF):
        return ("", "", false)

    # Single token cases
    if tokens.len <= 2: # token + EOF
        let tok = tokens[0]
        case tok.kind
        of tkString:
            return (tok.value, "string", false)

        of tkNumber:
            if '.' in tok.value:
                return (tok.value, "f64", false)
            else:
                return (tok.value, "i32", false)

        of tkIdent:
            if tok.value in vars:
                let (varType, varValue, _, _) = vars[tok.value]
                return (tok.value, varType, true) # It's a variable reference
            else:
                echo "[!] Error on line " & $lineNumber &
                        ": Undefined variable '" & tok.value & "'"
                quit(1)

        else:
            return ("", "", false)

    # Handle parentheses - strip outer parens if they wrap entire expression
    if tokens[0].kind == tkLParen:
        var depth = 0
        var allWrapped = true
        for i, tok in tokens:
            if tok.kind == tkEOF:
                break
            if tok.kind == tkLParen:
                inc depth
            elif tok.kind == tkRParen:
                dec depth
                if depth == 0 and i < tokens.len - 2: # Closed before end
                    allWrapped = false
                    break

        if allWrapped and depth == 0:
            # Remove outer parentheses and re-evaluate
            var innerExpr = ""
            for i in 1 ..< tokens.len - 2: # Skip first '(' and last ')' and EOF
                if tokens[i].kind == tkString:
                    innerExpr.add("\"" & tokens[i].value & "\"")
                else:
                    innerExpr.add(tokens[i].value)
                if i + 1 < tokens.len - 2 and tokens[i+1].kind notin {tkRParen, tkEOF}:
                    innerExpr.add(" ")
            return evalExpression(innerExpr, vars, target, lineNumber)

    # Find operator with lowest precedence (process last)
    # Scan RIGHT-TO-LEFT to get rightmost operator of equal precedence
    var opIndex = -1
    var parenDepth = 0
    var minPrecedence = 999

    for i in countdown(tokens.len - 1, 0):  # Right-to-left scanning
        if tokens[i].kind == tkRParen:
            inc parenDepth
        elif tokens[i].kind == tkLParen:
            dec parenDepth
        elif parenDepth == 0 and tokens[i].kind == tkOperator:
            let precedence = case tokens[i].value
                of "+", "-": 1
                of "*", "/", "%": 2
                else: 999

            if precedence < minPrecedence:  # Use < (not <=) to get rightmost
                minPrecedence = precedence
                opIndex = i

    # Handle unary minus at the beginning
    if opIndex == 0 and tokens[0].kind == tkOperator and tokens[0].value == "-":
        if tokens.len > 2:  # Has operand after minus
            var rightExpr = ""
            for i in 1 ..< tokens.len:
                if tokens[i].kind == tkEOF:
                    break
                if tokens[i].kind == tkString:
                    rightExpr.add("\"" & tokens[i].value & "\"")
                else:
                    rightExpr.add(tokens[i].value)
                if i + 1 < tokens.len and tokens[i+1].kind notin {tkEOF, tkRParen}:
                    rightExpr.add(" ")
            
            let (rightVal, rightType, rightRuntime) = evalExpression(rightExpr, vars, target, lineNumber)
            if rightRuntime:
                return ("-" & rightVal, rightType, true)
            else:
                let num = parseFloat(rightVal)
                let isFloat = '.' in rightVal or rightType in ["f32", "f64"]
                if isFloat:
                    return ($(-num), "f64", false)
                else:
                    return ($(-num.int), "i32", false)

    if opIndex > 0 and opIndex < tokens.len - 1:
        # Build left and right expressions
        var leftExpr = ""
        for i in 0 ..< opIndex:
            if tokens[i].kind == tkEOF:
                break
            # Preserve string literals by re-adding quotes
            if tokens[i].kind == tkString:
                leftExpr.add("\"" & tokens[i].value & "\"")
            else:
                leftExpr.add(tokens[i].value)
            if i + 1 < opIndex and tokens[i+1].kind notin {tkRParen}:
                leftExpr.add(" ")

        var rightExpr = ""
        for i in opIndex + 1 ..< tokens.len:
            if tokens[i].kind == tkEOF:
                break
            # Preserve string literals by re-adding quotes
            if tokens[i].kind == tkString:
                rightExpr.add("\"" & tokens[i].value & "\"")
            else:
                rightExpr.add(tokens[i].value)
            if i + 1 < tokens.len and tokens[i+1].kind notin {tkEOF, tkRParen}:
                rightExpr.add(" ")

        let operator = tokens[opIndex].value

        # Recursively evaluate both sides
        let (leftVal, leftType, leftRuntime) = evalExpression(leftExpr, vars,
                target, lineNumber)
        let (rightVal, rightType, rightRuntime) = evalExpression(rightExpr,
                vars, target, lineNumber)

        # If either side is a runtime value (variable), we can't compute at compile time
        if leftRuntime or rightRuntime:
            return (leftVal & " " & operator & " " & rightVal, leftType, true)

        # Both are compile-time constants - compute now!
        if leftType in ["i32", "i64", "f32", "f64"] and rightType in ["i32",
                "i64", "f32", "f64"]:
            # Numeric operation
            let leftNum = parseFloat(leftVal)
            let rightNum = parseFloat(rightVal)

            let result = case operator
                of "+": leftNum + rightNum
                of "-": leftNum - rightNum
                of "*": leftNum * rightNum
                of "/":
                    if rightNum == 0:
                        echo "[!] Error on line " & $lineNumber & ": Division by zero"
                        quit(1)
                    leftNum / rightNum
                of "%":
                    if rightNum == 0:
                        echo "[!] Error on line " & $lineNumber & ": Modulo by zero"
                        quit(1)
                    # For modulo, if both are integers use int mod, otherwise use float remainder
                    if '.' notin leftVal and '.' notin rightVal:
                        float(leftNum.int mod rightNum.int)
                    else:
                        leftNum - (leftNum / rightNum).floor * rightNum
                else: 0.0

            # Determine result type
            let isFloat = '.' in leftVal or '.' in rightVal or leftType in [
                    "f32", "f64"] or rightType in ["f32", "f64"]
            if isFloat:
                return ($result, "f64", false)
            else:
                return ($result.int, "i32", false)

        elif leftType == "string" or rightType == "string":
            # String concatenation
            if operator != "+":
                echo "[!] Error on line " & $lineNumber &
                        ": Cannot use operator '" & operator & "' on strings"
                quit(1)
            return (leftVal & rightVal, "string", false)

        else:
            echo "[!] Error on line " & $lineNumber & ": Type mismatch in expression"
            quit(1)

    # If we get here, return as-is
    return (expr, "string", true)