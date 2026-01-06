<div class="large-space-div" align="center">
  <img src="https://github.com/Bean-Pringles/Quill/blob/main/images/logo/logo.jpg" alt="Quill Logo" width="280" height="280">
  <h3>As Light as a Feather</h3>
  <!-- The functional badge code -->
  <img alt="Static Badge" src="https://img.shields.io/github/stars/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/badge/Language-Nim-orange">
  <img alt="Static Badge" src="https://img.shields.io/badge/OS-Windows,%20Linux,%20MacOS-green">
  <img alt="Static Badge" src="https://img.shields.io/badge/Version-v0.1.0-purple">
  <img alt="Static Badge" src="https://img.shields.io/badge/CPU-x86-yellow">
  <img alt="Static Badge" src="https://img.shields.io/github/downloads/Bean-Pringles/Quill/total.svg">
  <img alt="Static Badge" src="https://img.shields.io/github/repo-size/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/github/last-commit/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/badge/404-Not%20Found-lightgrey">
  <h1></h1>
</div>

## Setup

To set up this project, make sure Python and the Python library **Pillow** are installed. Then, from the setup directory, run:

### Windows

```shell
python setup.py
```

### macOS / Linux

```shell
python3 setup.py
```

Please make sure you run this command with **elevated privileges** so that it can register the file type and file icon.

## Compiling the Compiler

To compile, run the following commands in the `scripts` directory:

### Windows

```shell
./build
```

### MacOS/Linux

```shell
chmod +x build.sh
./build.sh
```

This executes the built in build script that generates the commands.nim and compiles it. If you want to do it manually, you can also run the following steps:

```shell
nim r build.nim
```

This creates `commands.nim` with all of the commands loaded from the `command` directory. For example, if the directory contains `print.nim`, `add.nim`, and `subtract.nim`, then `commands.nim` will look like this:

```nim
include "add.nim"
include "print.nim"
include "subtract.nim"
```

Then, to compile the compiler, run:

```shell
nim c -d:release compiler.nim
```

This assembles all of the files and outputs a single executable (`compiler.exe` on Windows, or the appropriate binary for your OS).

If you are like me and copy-paste code from the internet that doesn’t follow the 4-space indentation used here, you can always run:

```shell
nimpretty --indent=4 ./<filename>
```

This makes the spacing consistent across the entire file.
