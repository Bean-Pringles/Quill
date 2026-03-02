#!/bin/bash

# Save starting directory
startDir="$(pwd)"

# Change to the directory where this script is located
cd "$(dirname "$0")" || exit 1
echo "[*] Running EXE update script..."

# First argument = script to run
scriptPath="$1"

# Remove first argument so the rest can be forwarded cleanly
shift

# Run target script with ALL remaining arguments
/bin/bash "$scriptPath" "$@"

# Return to original directory
cd "$startDir" || exit 1

exit 0