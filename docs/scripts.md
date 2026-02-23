# Build

This builds build.nim and the compiler. It creates compiler.exe in the src directory.

# Release

This deletes all dev tests files, compiles the compiler, signs the compiler, renames the compiler, and run tests on it.

# Remove

This removes all old dev tests files. Used by developers who couldn't be bothered to type long paths.

# Sign

This signs, moves, renames, strips and upxs, and verifys the signature for the compiler.

# signSetup

This signs, renames, strips and upxs, and verifys both the setup script exe and the compiled setup wizard.

# Test

This deletes old tests, compiles new tests, moves the new tests, runs the tests, and then deletes them.