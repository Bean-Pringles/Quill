# Syntax

Randint accepts two arguements, smaller number and larger number, respectively. It will take this numbers and generate a number between them, inclusive. This number is based of the date and time and is XOR shifted to try to make it as random as possible.

It is a part of the rand libray, so you must import it.

NOTE: Because of the randomness, I cannot run test on it, so please keep in mind it make break more often than most other commands.

# Examples

```python
import rand

print(rand.randint(1, 10))
```

This will generate a random number, 1 through 10, and print it to the screen.

```python
print(rand.randint(1, 100))
```

This will error, because the rand library is not yet imported.