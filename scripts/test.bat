@echo off

rem Move to scripts dir
SET startDir=%CD%
cd /d %~dp0

rem Generate exes
echo [*] Compiling Tests
rem Miscellaneous
start "" /WAIT cmd /c "quill ../tests/src/types.qil >nul 2>&1"
start "" /WAIT cmd /c "quill ../tests/src/clear.qil >nul 2>&1"
rem Expressions
start "" /WAIT cmd /c "quill ../tests/src/expressions_advanced.qil >nul 2>&1"
start "" /WAIT cmd /c "quill ../tests/src/expressions_basic.qil >nul 2>&1"
start "" /WAIT cmd /c "quill ../tests/src/expressions_edge_cases.qil >nul 2>&1"
start "" /WAIT cmd /c "quill ../tests/src/expressions.qil >nul 2>&1"

rem Move the exes
echo [*] Moving Tests
rem Miscellaneous
move ..\tests\src\types.exe ..\tests\build\ >nul 2>&1
move ..\tests\src\clear.exe ..\tests\build\ >nul 2>&1
rem Expressions
move ..\tests\src\expressions_advanced.exe ..\tests\build\ >nul 2>&1
move ..\tests\src\expressions_basic.exe ..\tests\build\ >nul 2>&1
move ..\tests\src\expressions_edge_cases.exe ..\tests\build\ >nul 2>&1
move ..\tests\src\expressions.exe ..\tests\build\ >nul 2>&1

rem Run Python
python ../tests/compare.py

REM Return to original directory
cd /d %startDir%

echo [*] Tests Completed