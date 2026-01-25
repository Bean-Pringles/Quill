#!/bin/bash
# Nim Build & Compile Script for Linux/macOS

# Save the starting directory
startDir=$(pwd)

# Change to the script's directory
cd "$(dirname "$0")" || { echo "[ERROR] Failed to cd to script directory."; exit 1; }

echo "[*] Running build script..."

# Run build.nim and exit if it fails
nim r build.nim
if [ $? -ne 0 ]; then
    echo "[ERROR] build.nim failed. Aborting."
    exit 1
fi

echo "[*] Compiling compiler.nim in release mode..."

# Delete old compiler executable if it exists
if [ -f "../src/compiler" ]; then
    rm "../src/compiler"
fi

# Compile in release mode and exit if it fails
nim c -d:release ../src/compiler.nim
if [ $? -ne 0 ]; then
    echo "[ERROR] compiler.nim compilation failed. Aborting."
    exit 1
fi

echo [*] Removing old compiled test files...
# Remove old test.exe, test.zip, and test.ll if they exist
if [ -f "../src/test" ]; then
    rm "../src/test"
fi

if [ -f "../src/test.ll" ]; then
    rm "../src/test.ll"
fi

if [ -f "../src/test.zip" ]; then
    rm "../src/test.zip"
fi

if [ -f "../src/test.bat" ]; then
    rm "../src/test.bat"
fi

if [ -f "../src/test.rs" ]; then
    rm "../src/test.rs"
fi

if [ -f "../src/test.py" ]; then
    rm "../src/test.py"
fi

# Return to the original directory
cd "$startDir" || exit 1

echo "[*] Build and compilation completed successfully!"
