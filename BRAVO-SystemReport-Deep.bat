@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "SCRIPT=%SCRIPT_DIR%Get-BravoSystemReport.ps1"
set "REPORTS=%SCRIPT_DIR%reports"
set "NO_PAUSE=0"

:parse_args
if "%~1"=="" goto after_parse_args

if /I "%~1"=="--nopause" (
    set "NO_PAUSE=1"
    shift
    goto parse_args
)

if /I "%~1"=="-nopause" (
    set "NO_PAUSE=1"
    shift
    goto parse_args
)

if /I "%~1"=="/nopause" (
    set "NO_PAUSE=1"
    shift
    goto parse_args
)

shift
goto parse_args

:after_parse_args

echo === BRAVO SYSTEM REPORT ===
echo [INFO] Profile: Deep
echo [INFO] Script: %SCRIPT%
echo [INFO] Reports: %REPORTS%

if not exist "%SCRIPT%" (
    echo [ERROR] Script not found: %SCRIPT%
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

if not exist "%REPORTS%" (
    mkdir "%REPORTS%"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Profile Deep -NoPause -NoOpenFolder -OutputPath "%REPORTS%"

set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo [ERROR] BRAVO SYSTEM REPORT failed. ExitCode=%EXIT_CODE%
) else (
    echo [SUCCESS] BRAVO SYSTEM REPORT completed successfully.
)

echo [INFO] Reports saved: %REPORTS%

if "%NO_PAUSE%"=="0" pause

exit /b %EXIT_CODE%