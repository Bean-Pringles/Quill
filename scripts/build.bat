@echo off
REM Nim Build & Compile Script
REM Clear the screen for readability
cls

REM Save the starting directory
SET startDir=%CD%
cd /d %~dp0

echo [*] Running build script...

REM Run build.nim and exit if it fails
nim r build.nim
IF ERRORLEVEL 1 (
    echo [ERROR] build.nim failed. Aborting.
    exit /b 1
)

echo [*] Compiling compiler.nim in release mode...

REM Delete old compiler.exe if it exists
IF EXIST ..\src\compiler.exe DEL ..\src\compiler.exe

REM Compile in release mode and exit if it fails
nim c -d:release ..\src\compiler.nim
IF ERRORLEVEL 1 (
    echo [ERROR] compiler.nim compilation failed. Aborting.
    exit /b 1
)

REM Return to original directory
cd /d %startDir%
echo [*] Build and compilation completed successfully!