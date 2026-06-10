@echo off
chcp 65001 >nul
setlocal

title BRAVO SYSTEM REPORT - Forensic

set "SCRIPT_DIR=%~dp0"
set "SCRIPT=%SCRIPT_DIR%Get-BravoSystemReport.ps1"
set "REPORTS=%SCRIPT_DIR%reports"

echo === BRAVO SYSTEM REPORT ===
echo [INFO] Режим запуску: Forensic
echo [INFO] Директорія: %SCRIPT_DIR%
echo [INFO] Звіти: %REPORTS%
echo.

if not exist "%SCRIPT%" (
    echo [ERROR] Не знайдено файл: %SCRIPT%
    echo.
    pause
    exit /b 1
)

if not exist "%REPORTS%" (
    mkdir "%REPORTS%" >nul 2>&1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Profile Forensic -NoPause -NoOpenFolder -OutputPath "%REPORTS%"

set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo [SUCCESS] BRAVO SYSTEM REPORT завершено успішно.
    echo [INFO] Звіти збережено: %REPORTS%
) else (
    echo [ERROR] BRAVO SYSTEM REPORT завершився з кодом: %EXIT_CODE%
)

echo.
pause
exit /b %EXIT_CODE%