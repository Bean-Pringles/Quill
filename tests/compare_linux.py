import os
import subprocess
import re

# ===== Config =====
startDir = os.getcwd()

files = [
    "clear",
    "types",
    "expressions_advanced",
    "expressions_basic",
    "expressions_edge_cases",
    "expressions",
    "sleep",
    "exit",
    "exitRuntime"
]

pwd = os.path.dirname(os.path.abspath(__file__))
os.chdir(pwd)
# ==================


def strip_ansi(s: str) -> str:
    """Remove ANSI escape sequences from string."""
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', s)


def normalize(s: str) -> str:
    """Normalize string: remove null bytes, unify line endings, strip trailing spaces."""
    s = s.replace("\x00", "")
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = strip_ansi(s)  # Remove ANSI escape codes
    s = s.strip()
    lines = [line.rstrip() for line in s.split("\n")]
    return "\n".join(lines)


def compare_outputs(name: str, command: list[str], label: str):
    """Run command and compare output to expected text file."""
    # Check if the executable/script exists
    exec_path = command[0] if command[0] not in ["python3", "cargo"] else command[-1]
    if not os.path.exists(exec_path):
        print(f"[!] {name} ({label}): file not found at {exec_path}")
        return
    
    out_path = os.path.join(pwd, "outputs", f"{name}.txt")
    
    # Check if expected output file exists
    if not os.path.exists(out_path):
        print(f"[!] {name} ({label}): expected output not found at {out_path}")
        return

    # Run the command
    result = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL)

    # Read expected output
    with open(out_path, "r", encoding="utf-8") as f:
        expected_raw = f.read()

    # Normalize both expected and actual
    expected = normalize(expected_raw).split("\n")
    actual = normalize(result.stdout).split("\n")

    max_len = max(len(expected), len(actual))
    differences = []

    for i in range(max_len):
        exp_line = expected[i] if i < len(expected) else "<missing>"
        act_line = actual[i] if i < len(actual) else "<missing>"

        if exp_line != act_line:
            differences.append((i + 1, exp_line, act_line))

    if differences:
        print(f"Found {len(differences)} differences in {name} ({label})")
        for line_no, exp_line, act_line in differences:
            print(f"[{line_no}] expected: {exp_line} | actual: {act_line}")


# ===== Run tests =====

print("[*] Called Python File. All errors after this point are runtime.")

for name in files:
    # No-extension native binary
    binary_path = os.path.join(pwd, "build", name)
    compare_outputs(name, [binary_path], "native")

for name in files:
    # Python target
    py_path = os.path.join(pwd, "build", f"{name}.py")
    compare_outputs(name, ["python3", py_path], "python")

for name in files:
    # Rust target
    rs_path = os.path.join(pwd, "build", f"{name}.rs")
    compare_outputs(name, ["cargo", "eval", rs_path], "rust")

# Restore original directory
os.chdir(startDir)