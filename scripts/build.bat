@echo off
REM Nim Build & Compile Script
REM Clear the screen for readability
cls

echo [*] Running build script...

REM Run build.nim and exit if it fails
nim r %~dp0/build.nim
IF ERRORLEVEL 1 (
    echo [ERROR] build.nim failed. Aborting.
    exit /b 1
)

echo [*] Compiling compiler.nim in release mode...

IF EXIST ../src/compiler.exe DEL compiler.exe

REM Compile in release mode and exit if it fails
nim c -d:release ../src/compiler.nim
IF ERRORLEVEL 1 (
    echo [ERROR] compiler.nim compilation failed. Aborting.
    exit /b 1
)

echo [*] Build and compilation completed successfully!