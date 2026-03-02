# os.sleep

## Syntax

The sleep command excepts one argument, amount of millisecounds to wait before finishing the line.4

Because it is part of the os library, you must have it imported.

```python
os.sleep(<number of millisecounds>)
```

## Examples

```python
import os

print("Waiting for 1 secound")
os.sleep(1000)
print("Done")
```

This program prints "Waiting for 1 secound," stops for a secound, and then prints "Done"

```python
import os
import rand

os.sleep(rand.randint(1000, 5000))
```

This program will wait a random amount of time between 1 and 5 secounds and then quit.