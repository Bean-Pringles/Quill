# Dev Flags

To call a dev flag, you pass the -dev= arguement with the option following it. For example, this builds the compiler:

```shell
quill -dev=b
```

# All Flags

- __c, compile, b, build__: Builds the compiler and build.nim

- __s, sign__: Signs, strips, upxs, moves, and renames the compiler

- __t, test__: Compiles, runs, and moves tests

- __r, release__: Removes past artifacts, compiles, signs, and tests the compiler

- __ss, sign-setup__: Signs the setup artifacts