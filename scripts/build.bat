@echo off
REM Nim Build & Compile Script

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

echo [*] Removing old compiled test files...
REM Remove old test.exe, test.zip, and test.ll if they exist
IF EXIST ..\src\test.exe DEL ..\src\test.exe
IF EXIST ..\src\test.ll DEL ..\src\test.ll
IF EXIST ..\src\test.zip DEL ..\src\test.zip
IF EXIST ..\src\test.bat DEL ..\src\test.bat
IF EXIST ..\src\test.rs DEL ..\src\test.rs
IF EXIST ..\src\test.py DEL ..\src\test.py

REM Return to original directory
cd /d %startDir%
echo [*] Build and compilation completed successfully!