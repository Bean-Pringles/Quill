## Compiling the Compiler

To compile, run:

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