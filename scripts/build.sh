#!/bin/bash
# Nim Build & Compile Script for Linux/macOS
# Clears the screen for readability
clear

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

# Return to the original directory
cd "$startDir" || exit 1

echo "[*] Build and compilation completed successfully!"
