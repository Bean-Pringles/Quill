# Running Tests

To run tests, you can use the automated test script by running the following script from the home directory.

### Windows

```shell
./scripts/test
```

### Linux

```shell
chmod +x ./scripts/test.sh
./scripts/test.sh
```

This will clean up the old test files, compile the new tests, move the tests, run the tests, and compare the outputs to what should show up. This happens for all of the targets, native (LLVM IR), Python, Batch (Only on Windows), and Rust.

Any tests that fail will look like the following

```code
Found 1 differences in <test name> (<language name>)
[<line number>] expected: <expected line> | actual: <actual line>
```

This will happen for each difference.

A 100% test will print the following to the console

```code
[*] Cleaning old test files
[*] Calling bash script, all errors after this point are compile time
[*] Compiling Tests
[*] Moving Tests
[*] Called Python File. All errors after this point are runtime.
[*] Tests Completed
```

This means all tests compiled and ran without error.

# Dependencies

Python (Windows)

- Python3 (Linux)
- Cargo-eval (Install through command: cargo install eval)
- Rust/Cargo/Rustup (All of Rust's toolchain)
- LLVM and Clang (Clang 16 on Linux)
- UPX And Strip
