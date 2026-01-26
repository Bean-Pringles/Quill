@echo off

rem Move to scripts dir
SET startDir=%CD%
cd /d %~dp0

rem Checks if setup exists
if not exist ..\build\setup\windows\setup.exe echo [!] setup.exe doesn't exist
if not exist ..\build\setup\windows\setup.exe exit /B

rem Rename setup
ren ..\build\setup\windows\setup.exe quill-setup-windows-x86_64.exe

rem Deletes old files
echo [*] Deleting Old Signatures
if exist ..\build\setup\windows\quill-setup-windows-x86_64.exe.sig del ..\build\setup\windows\quill-setup-windows-x86_64.exe.sig

strip ..\build\setup\windows\quill-setup-windows-x86_64.exe
upx --best --lzma ..\build\setup\windows\quill-setup-windows-x86_64.exe

rem Sign and verify the program
gpg --detach-sign ..\build\setup\windows\quill-setup-windows-x86_64.exe
gpg --verify ..\build\setup\windows\quill-setup-windows-x86_64.exe.sig ..\build\setup\windows\quill-setup-windows-x86_64.exe

rem Return to starting dir
cd /d %startDir%

echo [*] Completed Signing