@echo off
REM Remove Old Compiled Files
cls

SET startDir=%CD%
cd /d %~dp0

echo [*] Removing Past Compiled Artifacts...
IF EXIST ..\src\test.exe DEL ..\src\test.exe
IF EXIST ..\src\test.ll DEL ..\src\test.ll
IF EXIST ..\src\test.zip DEL ..\src\test.zip
IF EXIST ..\src\test.bat DEL ..\src\test.bat
IF EXIST ..\src\test.rs DEL ..\src\test.rs

cd /d %startDir%
echo [*] Completed