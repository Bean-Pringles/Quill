#!/bin/bash
# Move to scripts dir
startDir=$(pwd)
cd "$(dirname "$0")" || { echo "[ERROR] Failed to cd to script directory."; exit 1; }

# Checks if setup exists
if [ ! -f "../build/setup/wizard/linux/setup" ]; then
    echo "[!] setup doesn't exist"
    exit
fi

# Deletes old files
echo "[*] Deleting Old Files"

if [ -f "../build/setup/wizard/linux/quill-setup-linux-x86_64.sig" ]; then
    rm "../build/setup/wizard/linux/quill-setup-linux-x86_64.sig"
fi

if [ -f "../build/setup/script/linux/quill-setup-linux-x86_64.sig" ]; then
    rm "../build/setup/script/linux/quill-setup-linux-x86_64.sig"
fi

# Rename file
mv ../build/setup/wizard/linux/setup ../build/setup/wizard/linux/quill-setup-linux-x86_64

x86_64-w64-mingw32-strip ../build/setup/wizard/linux/quill-setup-linux-x86_64
upx --best --lzma ../build/setup/wizard/linux/quill-setup-linux-x86_64
x86_64-w64-mingw32-strip ../build/setup/script/linux/quill-setup-linux-x86_64
upx --best --lzma ../build/setup/script/linux/quill-setup-linux-x86_64

# Sign and verify the program
gpg --detach-sign ../build/setup/wizard/linux/quill-setup-linux-x86_64
gpg --verify ../build/setup/wizard/linux/quill-setup-linux-x86_64.sig ../build/setup/wizard/linux/quill-setup-linux-x86_64
gpg --detach-sign ../build/setup/script/linux/quill-setup-linux-x86_64
gpg --verify ../build/setup/script/linux/quill-setup-linux-x86_64.sig ../build/setup/script/linux/quill-setup-linux-x86_64

# Return to starting dir
cd "$startDir" || exit 1

echo "[*] Completed Signing"