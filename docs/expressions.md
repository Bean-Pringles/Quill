# Expressions

Expressions can be made of commands, numbers, and strings. For example, the following is valid code.

```rust
let x: string = input("Hello") + 4 + "What"
```

For numbers, you can use the *, /, +, -, and % operators. For strings you use +, as with commands. Following order of operations, the parser will attempt to solve it at compile time, unless it uses an unknown command result from something like an input. 

When combining numbers and strings, the number is automaticly converted to a string, so the following code will yield 44, not 8. However, if the "4" was an integer, it would give 8.

```rust
let x: string = "4" + 4
```

It is pretty much the same as expressions in other lanaguages, so anything that works there will most likely work here.
