<div class="large-space-div" align="center">
  <img src="https://github.com/Bean-Pringles/Quill/blob/main/assets/images/logo.jpg" alt="Quill Logo" width="280" height="280">
  <h3>As Light as a Feather</h3>
  <!-- The functional badge code -->
  <img alt="Static Badge" src="https://img.shields.io/github/stars/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/badge/Language-Nim-orange">
  <img alt="Static Badge" src="https://img.shields.io/badge/OS-Windows,%20Linux,%20MacOS-green">
  <img alt="Static Badge" src="https://img.shields.io/badge/Version-v0.1.1-purple">
  <img alt="Static Badge" src="https://img.shields.io/badge/CPU-x86-yellow">
  <img alt="Static Badge" src="https://img.shields.io/github/downloads/Bean-Pringles/Quill/total.svg">
  <img alt="Static Badge" src="https://img.shields.io/github/repo-size/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/github/last-commit/Bean-Pringles/Quill">
  <img alt="Static Badge" src="https://img.shields.io/badge/404-Not%20Found-lightgrey">
  <h1></h1>
</div>

## Why Use Quill

Quill is an extremely lightweight programming language with a compiler written in Nim. While a standard C "Hello, World!" is roughly ~170KB, the standard Quill "Hello, World!" is just 4KB, and when zipped, just 750 Bytes. That's over 40 times smaller! Quill also is highly cross platform, compiling to languages such as LLVM IR, Batch, and Web Assembly. That makes Quill an ideal pick for microcontrollers lacking in space. While Quill is still in Alpha versions, it is extremly well built with a modular command system and extreme optimizations. You can read more at https://beanpringles.dev/quill.

## Hello, World! and Variables

To make a Hello, World! program in Quill, you can use the print command:

<!---Uses python because it has the same print syntax-->

```python
print("Hello, World!")
```

This program will print "Hello, World!" to the console and quit.

To declare variables in Quill, you use the let or const keyword. Let declares a mutable variable, while const declares an immutable variable. Let and const have the same syntax, besides the keyword, as show below:

<!--- Uses rust for syntax highlighting -->
```Rust
<let or const> <variable name>: <variable type> = <value>
```

The variable types are as follows: string, i32, i64, f32, f64, and bool.

For example, to declare an immutable string variable, x, with the value "foo", you would do the following command:

```Rust
const x: string = "foo"
```

Or to declare a mutable variable, y, with the value of 4, you would do:

```Rust
let y: i32 = 4
```

## Setup

The compiler and setup is already compiled in the ./build/compiler/<os platform> and ./build/setup/<os platform>. You can run the setup script as an administrator (If you want to register the file types) and choose the setup options you want. This will setup everything with no extra work required.

## Project Status

Quill is currently in **Alpha**. The core language and compiler are stable,
but syntax and features may change rapidly.

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

This executes the built in build script that compiles the compiler as well as generating commands.nim.

## Making Your Own Changes

If you are like me and copy-paste code from the internet that doesn’t follow the 4-space indentation pattern used here, you can always run:

```shell
nimpretty --indent=4 ./foo.nim
```

This makes the spacing consistent across the entire file, although it is not 100% accurate and sometimes you must touch it up yourself.