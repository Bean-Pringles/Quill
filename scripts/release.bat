@echo off
rem Full Build Script

SETLOCAL ENABLEDELAYEDEXPANSION

SET startingDir=%CD%
cd /d %~dp0

set "found=false"

for %%A in (%*) do (
    if /I "%%A"=="-nt" (
        set "found=true"
    )
)

call remove.bat
call build.bat
call sign.bat

if "!found!"=="false" (
    call test.bat
)

cd /d %startingDir%
echo [*] Full build, test, and sign process completed successfully!

ENDLOCAL