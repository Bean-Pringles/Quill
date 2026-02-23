import os
import subprocess

# ===== Config =====
startDir = os.getcwd()

files = [
    "clear",
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
    s = s.replace("\x00", "")
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = s.strip()
    lines = [line.rstrip() for line in s.split("\n")]
    return "\n".join(lines)


def compare_outputs(name: str, command: list[str], label: str):
    out_path = os.path.join(pwd, "outputs", f"{name}.txt")

    result = subprocess.run(command, capture_output=True, text=True)

    with open(out_path, "r", encoding="utf-8") as f:
        expected_raw = f.read()

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
    exe_path = os.path.join(pwd, "build", f"{name}.exe")
    compare_outputs(name, [exe_path], "exe")

for name in files:
    py_path = os.path.join(pwd, "build", f"{name}.py")
    compare_outputs(name, ["python", py_path], "python")

for name in files:
    bat_path = os.path.join(pwd, "build", f"{name}.bat")
    compare_outputs(name, ["cmd", "/c", bat_path], "batch")

for name in files:
    rs_path = os.path.join(pwd, "build", f"{name}.rs")
    compare_outputs(name, ["cargo", "eval", rs_path], "rust")

os.chdir(startDir)