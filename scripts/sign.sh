#!/bin/bash

# Move to scripts dir
startDir=$(pwd)
cd "$(dirname "$0")" || { echo "[ERROR] Failed to cd to script directory."; exit 1; }

# Checks if compiler exists
if [ ! -f "../src/compiler" ]; then
    echo "[!] Compiler doesn't exist"
    exit
fi

# Deletes old files
echo "[*] Deleting Old Files"

if [ -f "../build/compiler/linux/quill-compiler-linux-x86_64" ]; then
    rm "../build/compiler/linux/quill-compiler-linux-x86_64"
fi

if [ -f "../build/compiler/linux/quill-compiler-linux-x86_64.sig" ]; then
    rm "../build/compiler/linux/quill-compiler-linux-x86_64.sig"
fi

# Moves the compiler file
echo "[*] Moving File"
mv ../src/compiler ../build/compiler/linux/

# Renames compiler
mv ../build/compiler/linux/compiler ../build/compiler/linux/quill-compiler-linux-x86_64

x86_64-w64-mingw32-strip ../build/compiler/linux/quill-compiler-linux-x86_64
upx --best --lzma ../build/compiler/linux/quill-compiler-linux-x86_64

# Sign and verify the program
gpg --detach-sign ../build/compiler/linux/quill-compiler-linux-x86_64
gpg --verify ../build/compiler/linux/quill-compiler-linux-x86_64.sig ../build/compiler/linux/quill-compiler-linux-x86_64

# Return to starting dir
cd "$startDir" || exit 1

echo "[*] Completed Signing"