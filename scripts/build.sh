#!/bin/bash
# Nim Build & Compile Script for MacOS/Linux

# Clear the screen
clear

echo "[*] Running build script..."

# Run build.nim and exit if it fails
nim r "$(dirname "$0")/build.nim"
if [ $? -ne 0 ]; then
    echo "[ERROR] build.nim failed. Aborting."
    exit 1
fi

echo "[*] Compiling compiler.nim in release mode..."

# Remove existing compiler executable if it exists
if [ -f "../src/compiler" ]; then
    rm "../src/compiler"
fi

# Compile in release mode and exit if it fails
nim c -d:release "../src/compiler.nim"
if [ $? -ne 0 ]; then
    echo "[ERROR] compiler.nim compilation failed. Aborting."
    exit 1
fi

echo "[*] Build and compilation completed successfully!"