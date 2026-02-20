# Expressions

Expressions can be made of commands, numbers, and strings. For example, the following is valid code.

```rust
let x: string = input("Hello") + 4 + "What"
```

For numbers, you can use the *, /, +, -, and % operators. For strings you use +, as with commands. Following order of operations, the parser will attempt to solve it at compile time, unless it uses an unknown command result from something like an input. 

It is pretty much the same as expressions in other lanaguages, so anything that works there will most likely work here.
