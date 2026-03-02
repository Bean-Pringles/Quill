#!/bin/bash
# Full Build Script

# Save starting directory
startingDir=$(pwd)

# Change to script directory
cd "$(dirname "$0")" || exit 1

# Initialize flag
found=false

# Check for -nt flag
for arg in "$@"; do
    if [[ "$arg" == "-nt" ]]; then
        found=true
        break
    fi
done

# Run the other scripts
./remove.sh
./build.sh
./sign.sh

# Only run test.sh if -nt was NOT passed
if ! $found; then
    ./test.sh
fi

# Return to starting directory
cd "$startingDir" || exit 1

echo "[*] Full build, test, and sign process completed successfully!"