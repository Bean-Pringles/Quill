# os.exit

## Syntax

The exit command accepts one arguemnet, the exit code. If that arg is empty, it will automatically exit with the code of 0

Because it is part of the os library, you must have it imported.

```python
os.exit(<exit code>)
```

## Examples

```python
import os

print("Print 1")
os.exit()
print("Print 2")
```

The console will show `Print 1` and then exit.

```python
import os
import rand

os.exit(rand.randint(0, 1))
```

This will exit with a random code (0 or 1)