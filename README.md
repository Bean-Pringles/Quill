<div class="large-space-div" align="center">
  <img src="https://github.com/Bean-Pringles/Quill/blob/main/images/logo/logo.jpg" alt="Quill Logo" width="280" height="280">
  <h3>As Light as a Feather</h3>
  <!-- The functional badge code -->
  <img alt="Static Badge" src="https://img.shields.io/github/stars/Bean-Pringles/Quill"> <img alt="Static Badge" src="https://img.shields.io/badge/Language-Nim-orange"> <img alt="Static Badge" src="https://img.shields.io/badge/OS-Windows, Linux, MacOS-green"> <img alt="Static Badge" src="https://img.shields.io/badge/Version-v0.1.0-purple"> <img alt="Static Badge" src="https://img.shields.io/badge/CPU-x86-yellow"> <img alt="Static Badge" src=https://img.shields.io/github/downloads/Bean-Pringles/Quill/total.svg"> <img alt="Static Badge" src="https://img.shields.io/github/repo-size/Bean-Pringles/Quill"> <img alt="Static Badge" src="https://img.shields.io/github/last-commit/Bean-Pringles/Quill"> <img alt="Static Badge"src="https://img.shields.io/badge/404-Not%20Found-lightgrey">
  <h1> </h1>
</div>

## Setup

To setup this project, make sure python and the python library pillow are installed. Then, from the setup directory, run:

Windows:

```shell
python setup.py
```

MacOS/Linux:

```shell
python3 setup.py
```

Please make sure you run this command with elavated privilages so that it can register the file type and file icon.

## Compiling the Compiler

To compile, run the following commands in the src directory:

```shell
nim r build.nim
```

This creates commands.nim with all of the cmds loaded into the command directory. For example, if commands.nim has the files print.nim, add.nim, and subtract.nim, then commands.nim will look like this:

```Nim
include "add.nim"
include "print.nim"
include "subtract.nim"
```

Then to compile the compiler, run:

```Shell
nim c -d:release compiler.nim
```

This assembles all of the files, adds them up, and outputs a single .exe (or other file type depending on your OS) called compiler.exe.

If you are like me, and copy paste code from the internet that doesn't follow the 4 space indentation I use here, you can always run:

```Shell
nimpretty --indent=4 .\<filename>
```

This makes the spacing consistent across the entire file.