# Syntax

Like the let command, const declares a variable with the arguments of name, type, and value respectively. The difference between it and the let command is the keyword and that the variable can not be changed later.

```rust
const <var name>: <var type> = <value>
```

Available types are i32, i64, f32, f64, bool, and string.

# Examples

The following program will error at compile time:

```rust
const x: i32 = 15
x = 16
```

This happens because x was declared with const, so it is immutable.