@echo off
rem Full Build Script

SET startingDir=%CD%
cd /d %~dp0

call remove.bat
call build.bat
call test.bat
call sign.bat

cd /d %startingDir%
echo [*] Full build, test, and sign process completed successfully!