#!/usr/bin/env bash
set -e
shopt -s nullglob

echo "[*] Cleaning old test files"

# -------------------------
# Define tests
# -------------------------
tests=("types" "expressions_advanced" "expressions_basic" "expressions_edge_cases" "expressions")

# -------------------------
# Save starting directory and move to script directory
# -------------------------
pushd "$(dirname "$0")" > /dev/null

# -------------------------
# Clean build outputs (no extension and .py files only)
# -------------------------
for t in "${tests[@]}"; do
    rm -f "../tests/build/${t}" "../tests/build/${t}.py" "../tests/build/${t}.rs" 2>/dev/null || true
done

echo "[*] Compiling Tests"

# -------------------------
# Compile native (no extension)
# -------------------------
for t in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${t}.qil" >/dev/null 2>&1
done

# -------------------------
# Compile python target (.py)
# -------------------------
for t in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${t}.qil" -target=python >/dev/null 2>&1
done

# -------------------------
# Compile rust target (.rs)
# -------------------------
for t in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${t}.qil" -target=rust >/dev/null 2>&1
done

echo "[*] Moving Tests"

# -------------------------
# Move generated files (no extension and .py and .rs files)
# -------------------------
for t in "${tests[@]}"; do
    for ext in "" "py" "rs"; do
        src_file="../tests/src/${t}${ext:+.$ext}"
        if [[ -f "$src_file" ]]; then
            mv "$src_file" "../tests/build/"
        elif [[ -f "${t}${ext:+.$ext}" ]]; then
            mv "${t}${ext:+.$ext}" "../tests/build/"
        fi
    done
done

# -------------------------
# Run comparison
# -------------------------
python3 ../tests/compare_linux.py

# Restore directory
popd > /dev/null

echo "[*] Tests Completed"