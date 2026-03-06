#!/bin/bash

# Save starting directory
startDir=$(pwd)
cd "$(dirname "$0")"

echo "[*] Cleaning old test files"

# -------------------------
# Define tests
# -------------------------
tests=(types clear expressions_advanced expressions_basic expressions_edge_cases expressions sleep exit exitRuntime)

# -------------------------
# Clean build outputs
# -------------------------
for test in "${tests[@]}"; do
    rm -f "../tests/build/${test}" >/dev/null 2>&1
    rm -f "../tests/build/${test}.py" >/dev/null 2>&1
    rm -f "../tests/build/${test}.rs" >/dev/null 2>&1
done

echo "[*] Calling bash script, all errors after this point are compile time"
echo "[*] Compiling Tests"

# -------------------------
# Compile native (no extension)
# -------------------------
for test in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${test}.qil" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] Compilation FAILED for ${test} on native"
    fi
done

# -------------------------
# Compile python target
# -------------------------
for test in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${test}.qil" -target=python >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] Compilation FAILED for ${test} on python"
    fi
done

# -------------------------
# Compile rust target
# -------------------------
for test in "${tests[@]}"; do
    "../build/compiler/linux/quill-compiler-linux-x86_64" "../tests/src/${test}.qil" -target=rust >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] Compilation FAILED for ${test} on rust"
    fi
done

echo "[*] Moving Tests"

# -------------------------
# Move generated files
# -------------------------
for test in "${tests[@]}"; do
    # Loop over each extension (no extension for native binary)
    for ext in "" py rs; do
        # Check source folder first
        if [ "$ext" = "" ]; then
            SRC_FILE="../tests/src/${test}"
        else
            SRC_FILE="../tests/src/${test}.${ext}"
        fi
        
        if [ -f "$SRC_FILE" ]; then
            mv -f "$SRC_FILE" "../tests/build/" >/dev/null 2>&1
        fi

        # Check current folder
        if [ "$ext" = "" ]; then
            CUR_FILE="${test}"
        else
            CUR_FILE="${test}.${ext}"
        fi
        
        if [ -f "$CUR_FILE" ]; then
            mv -f "$CUR_FILE" "../tests/build/" >/dev/null 2>&1
        fi
    done
done

# -------------------------
# Run comparison
# -------------------------
python3 ../tests/compare_linux.py

# -------------------------
# Clean build outputs
# -------------------------
for test in "${tests[@]}"; do
    rm -f "../tests/build/${test}" >/dev/null 2>&1
    rm -f "../tests/build/${test}.py" >/dev/null 2>&1
    rm -f "../tests/build/${test}.rs" >/dev/null 2>&1
done

# Restore directory
cd "$startDir"

echo "[*] Tests Completed"