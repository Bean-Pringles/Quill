@echo off
rem Full Build Script

SET startingDir=%CD%
cd /d %~dp0

call remove.bat
call build.bat
call sign.bat
call test.bat

cd /d %startingDir%
echo [*] Full build, test, and sign process completed successfully!