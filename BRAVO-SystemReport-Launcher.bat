@echo off
chcp 65001 >nul
setlocal

title BRAVO SYSTEM REPORT - Launcher

set "SCRIPT_DIR=%~dp0"

:MENU
cls
echo === BRAVO SYSTEM REPORT LAUNCHER ===
echo.
echo Оберіть режим запуску:
echo.
echo   1. Quick    - швидкий аудит
echo   2. Full     - повний базовий аудит
echo   3. Deep     - глибокий аудит
echo   4. Forensic - максимально детальний аудит
echo   0. Вихід
echo.

set /p MODE="Ваш вибір: "

if "%MODE%"=="1" (
    call "%SCRIPT_DIR%BRAVO-SystemReport-Quick.bat"
    goto MENU
)

if "%MODE%"=="2" (
    call "%SCRIPT_DIR%BRAVO-SystemReport-Full.bat"
    goto MENU
)

if "%MODE%"=="3" (
    call "%SCRIPT_DIR%BRAVO-SystemReport-Deep.bat"
    goto MENU
)

if "%MODE%"=="4" (
    call "%SCRIPT_DIR%BRAVO-SystemReport-Forensic.bat"
    goto MENU
)

if "%MODE%"=="0" (
    exit /b 0
)

echo.
echo [ERROR] Невірний вибір.
pause
goto MENU