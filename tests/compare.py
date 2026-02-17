import os
import subprocess
import difflib

# ===== Config =====
startDir = os.getcwd()
files = ["clear", "types"]
pwd = os.path.dirname(os.path.abspath(__file__))
os.chdir(pwd)
# ==================

def normalize(s: str) -> str:
    # Remove null bytes
    s = s.replace("\x00", "")
    # Normalize line endings
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    # Strip all leading/trailing whitespace (including final newlines)
    s = s.strip()
    # Split lines and strip trailing spaces from each line
    lines = [line.rstrip() for line in s.split("\n")]
    return "\n".join(lines)

for name in files:
    exe_path = os.path.join(pwd, "build", f"{name}.exe")
    out_path = os.path.join(pwd, "outputs", f"{name}.txt")

    # Run the executable
    result = subprocess.run([exe_path], capture_output=True, text=True)

    # Read expected output
    with open(out_path, "r", encoding="utf-8") as f:
        expected = f.read()

    # Normalize both outputs
    actual = normalize(result.stdout)
    expected = normalize(expected)

    # Compare
    if actual != expected:
        print(f"[!] {name} check failed")
        print("[*] Expected:")
        print(expected)
        print("[*] Got:")
        print(actual)

os.chdir(startDir)