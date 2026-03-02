@echo off
setlocal

REM Save starting directory
set "startDir=%CD%"
cd /d "%~dp0"
echo [*] Running EXE update script...

set "scriptPath=%~1"
set "args=%~2"

REM Run it
call "%scriptPath%" %args%

REM Return to original directory
cd /d "%startDir%"

EXIT /B