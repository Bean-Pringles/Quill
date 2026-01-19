<div class="large-space-div" align="center">
  <img src="https://github.com/Bean-Pringles/Quill/blob/main/assets/images/logo.jpg" alt="Quill Logo" width="280" height="280">
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

## Why Use Quill

Quill is an extremely lightweight programming langauge with a compiler written in Nim. While a standard C "Hello, World!" is roughly ~170KB, the standard Quill "Hello, World!" is just 4KB, and when zipped, just 750 Bytes. That's over 40 times smaller! Quill also highly cross platform, compiling to langauges such as LLVM IR, Batch, and Web Assembly. That makes Quill and indeal pick for microcrontrollers lacking in space. While Quill is still in Alpha versions, it is extremley well built with a modular command system and extreme optimizations. You can read more at https://beanpringles.dev/quill.

## Setup

To setup this project you must move to and compile the 'setup/setupWizard' folder using the command:

```Shell
cargo build
```

 This will create an executable in (place filename here). Move this program back to the 'setup/setupWizard' folder and run it as an administrator. Select the checkboxs for the items you want to happen. (EX. Custom File Type, Launcher, CLI Command)

## Compiling the Compiler

To compile, run the following commands in the scripts directory:

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

This creates commands.nim with all of the commands loaded from the command directory. For example, if the directory contains print.nim, add.nim, and subtract.nim, then commands.nim will look like this:

```nim
include "add.nim"
include "print.nim"
include "subtract.nim"
```

Then, to compile the compiler, run:

```shell
nim c -d:release compiler.nim
```

This assembles all of the files and outputs a single executable (compiler.exe on Windows, or the appropriate binary for your OS).

## Making Your Own Changes

If you are like me and copy-paste code from the internet that doesn’t follow the 4-space indentation pattern used here, you can always run:

```shell
nimpretty --indent=4 ./foo.nim
```

This makes the spacing consistent across the entire file, although it is not 100% accuarate and sometimes you must touch it up yourself.