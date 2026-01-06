import os

proc writeIR(line: string, filename: string) =
    try:
        # Open file in append mode
        let f = open(filename, fmAppend)
        f.writeLine(line)  # automatically adds newline
        f.close()
    except OSError as e:
        echo "[!] Error writing IR for line: ", line, " | OS Error: ", e.msg
    except Exception as e:
        echo "[!] Unexpected error writing IR for line: ", line, " | Exception: ", e.msg
