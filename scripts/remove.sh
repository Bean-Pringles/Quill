#!/bin/bash
# Remove Old Compiled Files

clear

# Save the starting directory
startDir=$(pwd)

# Change to the script's directory
cd "$(dirname "$0")" || { echo "[ERROR] Failed to cd to script directory."; exit 1; }

echo [*] Removing Past Compiled Artifacts...

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

# Return to the original directory
cd "$startDir" || exit 1

echo [*] Completed