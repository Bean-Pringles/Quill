@echo off
setlocal EnableDelayedExpansion

rem Save starting directory
set startDir=%CD%
cd /d %~dp0

echo [*] Cleaning old test files

rem -------------------------
rem Define tests
rem -------------------------
set tests=types clear expressions_advanced expressions_basic expressions_edge_cases expressions

rem -------------------------
rem Clean build outputs
rem -------------------------
for %%T in (%tests%) do (
    del ..\tests\build\%%T.exe >nul 2>&1
    del ..\tests\build\%%T.py  >nul 2>&1
    del ..\tests\build\%%T.bat >nul 2>&1
    del ..\tests\build\%%T.rs >nul 2>&1
)

echo [*] Compiling Tests

rem -------------------------
rem Compile native (exe)
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ../tests/src/%%T.qil >nul 2>&1
)

rem -------------------------
rem Compile python target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ../tests/src/%%T.qil -target=python >nul 2>&1
)

rem -------------------------
rem Compile batch target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ../tests/src/%%T.qil -target=batch >nul 2>&1
)

rem -------------------------
rem Compile rust target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ../tests/src/%%T.qil -target=rust >nul 2>&1
)

echo [*] Moving Tests

rem -------------------------
rem Move generated files
rem -------------------------
for %%T in (%tests%) do (
    if exist ..\tests\src\%%T.exe move ..\tests\src\%%T.exe ..\tests\build\ >nul 2>&1
    if exist %%T.exe move %%T.exe ..\tests\build\ >nul 2>&1
    if exist ..\tests\src\%%T.py  move ..\tests\src\%%T.py  ..\tests\build\ >nul 2>&1
    if exist %%T.py  move %%T.py  ..\tests\build\ >nul 2>&1
    if exist ..\tests\src\%%T.bat move ..\tests\src\%%T.bat ..\tests\build\ >nul 2>&1
    if exist %%T.bat move %%T.bat ..\tests\build\ >nul 2>&1
    if exist ..\tests\src\%%T.rs move ..\tests\src\%%T.rs ..\tests\build\ >nul 2>&1
    if exist %%T.rs move %%T.rs ..\tests\build\ >nul 2>&1
) 

rem Run comparison
python ../tests/compare_windows.py

rem -------------------------
rem Clean build outputs
rem -------------------------
for %%T in (%tests%) do (
    del ..\tests\build\%%T.exe >nul 2>&1
    del ..\tests\build\%%T.py  >nul 2>&1
    del ..\tests\build\%%T.bat >nul 2>&1
    del ..\tests\build\%%T.rs >nul 2>&1
    del ..\tests\build\%%T >nul 2>&1
)


rem Restore directory
cd /d %startDir%

echo [*] Tests Completed
endlocal