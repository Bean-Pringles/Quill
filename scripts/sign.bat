@echo off

rem Move to scripts dir
SET startDir=%CD%
cd /d %~dp0

rem Checks if compiler exists
if not exist ..\src\compiler.exe echo [!] compiler.exe doesn't exist
if not exist ..\src\compiler.exe exit /B

rem Deletes old files
echo [*] Deleting Old Files
if exist ..\build\compiler\windows\quill-compiler-windows-x86_64.exe del ..\build\compiler\windows\quill-compiler-windows-x86_64.exe
if exist ..\build\compiler\windows\quill-compiler-windows-x86_64.exe.sig del ..\build\compiler\windows\quill-compiler-windows-x86_64.exe.sig

rem Moves the compiler.exe
echo [*] Moving File
move ..\src\compiler.exe ..\build\compiler\windows\

rem Rename compiler
ren ..\build\compiler\windows\compiler.exe quill-compiler-windows-x86_64.exe

rem Optimize it
echo [*] Optimizing File
upx --best --lzma ..\build\compiler\windows\quill-compiler-windows-x86_64.exe

rem Sign and verify the program
gpg --detach-sign ..\build\compiler\windows\quill-compiler-windows-x86_64.exe
gpg --verify ..\build\compiler\windows\quill-compiler-windows-x86_64.exe.sig ..\build\compiler\windows\quill-compiler-windows-x86_64.exe

rem Return to starting dir
cd /d %startDir%

echo [*] Completed Signing