@echo off
setlocal EnableDelayedExpansion

rem Save starting directory
set startDir=%CD%
cd /d %~dp0

echo [*] Cleaning old test files

rem -------------------------
rem Define tests
rem -------------------------
set tests=types clear expressions_advanced expressions_basic expressions_edge_cases expressions sleep

rem -------------------------
rem Clean build outputs
rem -------------------------
for %%T in (%tests%) do (
    del ..\tests\build\%%T.exe  >nul 2>&1
    del ..\tests\build\%%T.py   >nul 2>&1
    del ..\tests\build\%%T.bat  >nul 2>&1
    del ..\tests\build\%%T.rs   >nul 2>&1
)

echo [*] Calling batch script, all errors after this point are compile time
echo [*] Compiling Tests

rem -------------------------
rem Compile native (exe)
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ..\tests\src\%%T.qil >nul 2>&1
    if errorlevel 1 (
        echo [^^!] Compilation FAILED for %%T on native
    )
)

rem -------------------------
rem Compile python target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ..\tests\src\%%T.qil -target=python >nul 2>&1
    if errorlevel 1 (
        echo [^^!] Compilation FAILED for %%T on python
    )
)

rem -------------------------
rem Compile batch target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ..\tests\src\%%T.qil -target=batch >nul 2>&1
    if errorlevel 1 (
        echo [^^!] Compilation FAILED for %%T on batch
    )
)

rem -------------------------
rem Compile rust target
rem -------------------------
for %%T in (%tests%) do (
    "../build/compiler/windows/quill-compiler-windows-x86_64.exe" ..\tests\src\%%T.qil -target=rust >nul 2>&1
    if errorlevel 1 (
        echo [^^!] Compilation FAILED for %%T on rust
    )
)

echo [*] Moving Tests

rem -------------------------
rem Move generated files
rem -------------------------
for %%T in (%tests%) do (
    REM Loop over each extension
    for %%E in (exe py bat rs) do (
        REM Check source folder first
        set "SRC_FILE=..\tests\src\%%T.%%E"
        if exist "!SRC_FILE!" (
            move /y "!SRC_FILE!" "..\tests\build\" >nul 2>&1
        )

        REM Check current folder
        set "CUR_FILE=%%T.%%E"
        if exist "!CUR_FILE!" (
            move /y "!CUR_FILE!" "..\tests\build\" >nul 2>&1
        )
    )
)

rem -------------------------
rem Run comparison
rem -------------------------
python ../tests/compare_windows.py

rem -------------------------
rem Clean build outputs
rem -------------------------
for %%T in (%tests%) do (
    for %%E in (exe py bat rs "") do (
        del ..\tests\build\%%T%%E>nul 2>&1
        if not "%%E"=="" del ..\tests\build\%%T.%%E >nul 2>&1
    )
)

rem Restore directory
cd /d %startDir%

echo [*] Tests Completed
endlocal