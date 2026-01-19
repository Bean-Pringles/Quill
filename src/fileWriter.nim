# Centrallized File Writes

proc writeCode*(irCode: string, filename: string) =
    try:
        # Open file in append mode
        let f = open(filename, fmAppend)
        f.writeLine(irCode)  # automatically adds newline
        f.close()
    except OSError as e:
        echo "[!] Error writing IR for line: ", irCode, " | OS Error: ", e.msg
    except Exception as e:
        echo "[!] Unexpected error writing IR for line: ", irCode, " | Exception: ", e.msg
