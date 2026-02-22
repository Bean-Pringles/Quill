import math
import tables
import strutils

proc isCommand*(arg: string, vars: Table[string, (string, string, int,
        bool)]): bool =
    if arg.len == 0:
        return false

    var strippedArg = arg.strip()

    if strippedArg.len >= 2:
        if (strippedArg[0] == '"' and strippedArg[^1] == '"') or
           (strippedArg[0] == '\'' and strippedArg[^1] == '\''):
            return false

    if strippedArg in vars:
        return false

    try:
        discard parseFloat(strippedArg)
        return false
    except:
        discard

    return true

type
    TokenKind = enum
        tkString, tkNumber, tkIdent, tkOperator, tkLParen, tkRParen, tkEOF

    Token = object
        kind: TokenKind
        value: string

proc tokenize(expr: string): seq[Token] =
    var tokResult: seq[Token] = @[]
    var i = 0

    while i < expr.len:
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
                inc i
            tokResult.add(Token(kind: tkString, value: str))

        # Numbers. A leading '-' is only part of the number literal when it
        # appears at the very start of the token stream OR immediately after
        # another operator or a left-paren — i.e. when it is unambiguously
        # unary.  In every other position (after a number, identifier, or
        # right-paren) '-' is a binary subtraction operator and must be
        # emitted as tkOperator so that the expression splitter can find it.
        elif expr[i] in {'0'..'9'} or
             (expr[i] == '-' and
              i + 1 < expr.len and
              expr[i + 1] in {'0'..'9'} and
              (tokResult.len == 0 or
               tokResult[^1].kind in {tkOperator, tkLParen})):
            var num = ""
            if expr[i] == '-':
                num.add('-')
                inc i
            while i < expr.len and (expr[i] in {'0'..'9', '.'}):
                num.add(expr[i])
                inc i
            tokResult.add(Token(kind: tkNumber, value: num))

        # Operators (checked after the number branch so '%' is caught here
        # only when it is not starting a LLVM register name)
        elif expr[i] in {'+', '-', '*', '/', '%'}:
            tokResult.add(Token(kind: tkOperator, value: $expr[i]))
            inc i

        # LLVM register identifiers (%name)
        elif expr[i] == '%' and i + 1 < expr.len and
             (expr[i + 1].isAlphaNumeric() or expr[i + 1] == '_'):
            var ident = ""
            ident.add('%')
            inc i
            while i < expr.len and
                  (expr[i] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
                ident.add(expr[i])
                inc i
            tokResult.add(Token(kind: tkIdent, value: ident))

        # Plain identifiers
        elif expr[i] in {'a'..'z', 'A'..'Z', '_'}:
            var ident = ""
            while i < expr.len and
                  (expr[i] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
                ident.add(expr[i])
                inc i
            tokResult.add(Token(kind: tkIdent, value: ident))

        elif expr[i] == '(':
            tokResult.add(Token(kind: tkLParen, value: "("))
            inc i
        elif expr[i] == ')':
            tokResult.add(Token(kind: tkRParen, value: ")"))
            inc i

        else:
            inc i

    tokResult.add(Token(kind: tkEOF, value: ""))
    return tokResult

proc evalExpression*(
    expr: string,
    vars: Table[string, (string, string, int, bool)],
    target: string,
    lineNumber: int
): (string, string, bool) =
    # Returns: (value, type, is_runtime)

    let tokens = tokenize(expr.strip())
    if tokens.len == 0 or (tokens.len == 1 and tokens[0].kind == tkEOF):
        return ("", "", false)

    # Single token
    if tokens.len <= 2:
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
                let (varType, _, _, _) = vars[tok.value]
                return (tok.value, varType, true)
            else:
                echo "[!] Error on line " & $lineNumber &
                        ": Undefined variable '" & tok.value & "'"
                quit(1)
        else:
            return ("", "", false)

    # Strip wrapping parentheses
    if tokens[0].kind == tkLParen:
        var depth = 0
        var allWrapped = true
        for i, tok in tokens:
            if tok.kind == tkEOF: break
            if tok.kind == tkLParen: inc depth
            elif tok.kind == tkRParen:
                dec depth
                if depth == 0 and i < tokens.len - 2:
                    allWrapped = false
                    break

        if allWrapped and depth == 0:
            var innerExpr = ""
            for i in 1 ..< tokens.len - 2:
                if tokens[i].kind == tkString:
                    innerExpr.add("\"" & tokens[i].value & "\"")
                else:
                    innerExpr.add(tokens[i].value)
                if i + 1 < tokens.len - 2 and
                   tokens[i + 1].kind notin {tkRParen, tkEOF}:
                    innerExpr.add(" ")
            return evalExpression(innerExpr, vars, target, lineNumber)

    # Find the lowest-precedence operator (right-to-left scan gives left
    # associativity when we use strict <)
    var opIndex = -1
    var parenDepth = 0
    var minPrecedence = 999

    for i in countdown(tokens.len - 1, 0):
        if tokens[i].kind == tkRParen: inc parenDepth
        elif tokens[i].kind == tkLParen: dec parenDepth
        elif parenDepth == 0 and tokens[i].kind == tkOperator:
            let precedence = case tokens[i].value
                of "+", "-": 1
                of "*", "/", "%": 2
                else: 999

            if precedence < minPrecedence:
                minPrecedence = precedence
                opIndex = i

    # Unary minus at position 0
    if opIndex == 0 and tokens[0].kind == tkOperator and tokens[0].value == "-":
        if tokens.len > 2:
            var rightExpr = ""
            for i in 1 ..< tokens.len:
                if tokens[i].kind == tkEOF: break
                if tokens[i].kind == tkString:
                    rightExpr.add("\"" & tokens[i].value & "\"")
                else:
                    rightExpr.add(tokens[i].value)
                if i + 1 < tokens.len and
                   tokens[i + 1].kind notin {tkEOF, tkRParen}:
                    rightExpr.add(" ")

            let (rightVal, rightType, rightRuntime) =
                evalExpression(rightExpr, vars, target, lineNumber)
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
        var leftExpr = ""
        for i in 0 ..< opIndex:
            if tokens[i].kind == tkEOF: break
            if tokens[i].kind == tkString:
                leftExpr.add("\"" & tokens[i].value & "\"")
            else:
                leftExpr.add(tokens[i].value)
            if i + 1 < opIndex and tokens[i + 1].kind notin {tkRParen}:
                leftExpr.add(" ")

        var rightExpr = ""
        for i in opIndex + 1 ..< tokens.len:
            if tokens[i].kind == tkEOF: break
            if tokens[i].kind == tkString:
                rightExpr.add("\"" & tokens[i].value & "\"")
            else:
                rightExpr.add(tokens[i].value)
            if i + 1 < tokens.len and
               tokens[i + 1].kind notin {tkEOF, tkRParen}:
                rightExpr.add(" ")

        let operator = tokens[opIndex].value

        let (leftVal, leftType, leftRuntime) =
            evalExpression(leftExpr, vars, target, lineNumber)
        let (rightVal, rightType, rightRuntime) =
            evalExpression(rightExpr, vars, target, lineNumber)

        if leftRuntime or rightRuntime:
            return (leftVal & " " & operator & " " & rightVal, leftType, true)

        if leftType in ["i32", "i64", "f32", "f64"] and
           rightType in ["i32", "i64", "f32", "f64"]:
            let leftNum = parseFloat(leftVal)
            let rightNum = parseFloat(rightVal)

            let exprResult = case operator
                of "+": leftNum + rightNum
                of "-": leftNum - rightNum
                of "*": leftNum * rightNum
                of "/":
                    if rightNum == 0:
                        echo "[!] Error on line " & $lineNumber &
                                ": Division by zero"
                        quit(1)
                    leftNum / rightNum
                of "%":
                    if rightNum == 0:
                        echo "[!] Error on line " & $lineNumber &
                                ": Modulo by zero"
                        quit(1)
                    if '.' notin leftVal and '.' notin rightVal:
                        float(leftNum.int mod rightNum.int)
                    else:
                        leftNum - (leftNum / rightNum).floor * rightNum
                else: 0.0

            let isFloat = '.' in leftVal or '.' in rightVal or
                          leftType in ["f32", "f64"] or
                          rightType in ["f32", "f64"]
            if isFloat:
                return ($exprResult, "f64", false)
            else:
                return ($exprResult.int, "i32", false)

        elif leftType == "string" or rightType == "string":
            if operator != "+":
                echo "[!] Error on line " & $lineNumber &
                        ": Cannot use operator '" & operator & "' on strings"
                quit(1)
            return (leftVal & rightVal, "string", false)

        else:
            echo "[!] Error on line " & $lineNumber &
                    ": Type mismatch in expression"
            quit(1)

    return (expr, "string", true)