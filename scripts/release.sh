#!/bin/bash
# Full Build Script

# Save starting directory
startingDir=$(pwd)

# Change to script directory
cd "$(dirname "$0")" || exit 1

# Run the other scripts
./remove.sh
./build.sh
./sign.sh
./test.sh

# Return to starting directory
cd "$startingDir" || exit 1

echo "[*] Full build, test, and sign process completed successfully!"