#!/bin/bash
# Move to scripts dir
startDir=$(pwd)
cd "$(dirname "$0")" || { echo "[ERROR] Failed to cd to script directory."; exit 1; }

# Checks if setup exists
if [ ! -f "../build/setup/linux/setup" ]; then
    echo "[!] setup doesn't exist"
    exit
fi

# Deletes old files
echo "[*] Deleting Old Files"

if [ -f "../build/setup/linux/quill-setup-linux-x86_64.sig" ]; then
    rm "../build/setup/linux/quill-setup-linux-x86_64.sig"
fi

# Rename file
mv ../build/setup/linux/setup ../build/setup/linux/quill-setup-linux-x86_64

# Sign and verify the program
gpg --detach-sign ../build/setup/linux/quill-setup-linux-x86_64
gpg --verify ../build/setup/linux/quill-setup-linux-x86_64.sig ../build/setup/linux/quill-setup-linux-x86_64

# Return to starting dir
cd "$startDir" || exit 1

echo "[*] Completed Signing"