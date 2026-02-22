import os
import subprocess

# ===== Config =====
startDir = os.getcwd()

files = [
    "types",
    "expressions_advanced",
    "expressions_basic",
    "expressions_edge_cases",
    "expressions"
]

pwd = os.path.dirname(os.path.abspath(__file__))
os.chdir(pwd)
# ==================


def normalize(s: str) -> str:
    """Normalize string: remove null bytes, unify line endings, strip trailing spaces."""
    s = s.replace("\x00", "")
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = s.strip()
    lines = [line.rstrip() for line in s.split("\n")]
    return "\n".join(lines)


def compare_outputs(name: str, command: list[str], label: str):
    """Run command and compare output to expected text file."""
    out_path = os.path.join(pwd, "outputs", f"{name}.txt")

    # Run the command
    result = subprocess.run(command, capture_output=True, text=True)

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

for name in files:
    # No-extension native binary
    exe_path = os.path.join(pwd, "build", name)
    compare_outputs(name, [exe_path], "native")

for name in files:
    # Python target
    py_path = os.path.join(pwd, "build", f"{name}.py")
    compare_outputs(name, ["python3", py_path], "python")

# Restore original directory
os.chdir(startDir)