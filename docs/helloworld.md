# Creating a Hello World Program in Quill

To create a variable, hello, with a value of "Hello" you would do

```code
let hello: string = "Hello"
```

This creates and assigns the value to the variable hello. To print it afterwords, you would run

```code
# Prints Hello, World to the console
let hello: string = "Hello"
print(hello + ", World!")
```

This creates the variable hello with value of "Hello" and then prints it to the the screen along with aditional charecters so the full string printed to the console is "Hello, World!"

# Compiling a Hello World Program

To compile the program, make sure you have LLVM, UPX, Strip, and the compiler installed and setup using the setup wizard in ./build/setup/wizard/<os name>/quill-setup-<os name>-x86_64.exe. Then run the following command

```shell
quill helloworld.qil
```

This should compile your program (If it is named helloworld.qil, change it to this name if it is not) and create helloworld.exe. Upoun running the exe, you should see the charecters "Hello, World!" printed to the screen.