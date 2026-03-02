# Targets

There are a couple of target flags.

- Native
- Rust
- Python
- LLVM IR
- Batch
- Zip

### Native

This is the default path. Your code is first compiled to LLVM IR, then to an executabe. While this is default, it can be called with the following commands

```shell
quill foo.qil -target=exe
quill foo.qil
```

### Rust

This must be specified to compile to it. It creates a single .rs file. You can call it with the flag

```shell
quill foo.qil -target=rust
```

### Python

This must be specified to compile to it. It creates a single .py file. You can call it with the flag

```shell
quill foo.qil -target=python
```

### LLVM IR

This must be specified to compile to it. Normally, when compiling to native code, it is route through here, to stop here, you would pass the flag

```shell
quill foo.qil -target=ir
```

### Batch

This must be specified to compile to it. It creates a single .bat file. You call it with the flag

```shell
quill foo.qil -target=batch
```

### Zip

This must be specified to compile to it. It follows the native/LLVM IR pipeline, exceot after comptimplation, it is then zipped up. OUtput will then be a single .zip file with an executable inside of it.

```shell
quill foo.qil -target=zip
```
