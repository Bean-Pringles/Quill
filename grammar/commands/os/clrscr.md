\# Syntax



The clrscr command does not accept any arguments but is part of the os library.



```python

os.clrscr()

```



It will erase all contents on the screen.



\# Examples


```python

import os



print("Before")

os.clrscr()

print("After")

```



You will only see "After" because the screen is cleared in the middle of the program.



```python

print("Before")

os.clrscr()

print("After")

```



This will error because os is not imported, so you can not access os commands.

