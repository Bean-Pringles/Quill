<<<<<<< Updated upstream
# Compile Time

Anything that can be evaluated at compile time is. This means while the source code looks like this

```code
print((4 + 3) * 7 / (6 + 4))
```

The output from the compiler (in Pytohn) would look like

```python
print("4.9")
```

If there is an unknown variable (such as something deriving from an input or random integer) it will compile down as much as possible, but not all the way. Source code like this

```code
import rand

print(rand.randint(1, 10) + 2 - 6)
```

Will compile down to

```python
import random

print(random.randint(1, 10) - 4)
```

=======
# Compile Time

Anything that can be evaluated at compile time is. This means while the source code looks like this

```code
print((4 + 3) * 7 / (6 + 4))
```

The output from the compiler (in Pytohn) would look like

```python
print("4.9")
```

If there is an unknown variable (such as something deriving from an input or random integer) it will compile down as much as possible, but not all the way. Source code like this

```code
import rand

print(rand.randint(1, 10) + 2 - 6)
```

Will compile down to

```python
import random

print(random.randint(1, 10) - 4)
```

>>>>>>> Stashed changes
This means that compiled code does not necessarily get evaluated at runtime, just if it depends on an external unknown value. 