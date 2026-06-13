@echo off
chcp 65001 >nul
title KINGDOM ^& CO

>nul 2>&1 net session || (
    echo.
    echo  ============================================
    echo    KINGDOM ^& CO
    echo  ============================================
    echo.
    echo  Requesting admin privileges...
    mshta "javascript:new ActiveXObject('Shell.Application').ShellExecute('%~s0','','','runas',1);window.close()"
    exit /b
)

cls
echo.
echo   K K III N N GGG DDD OOO M M
echo   K K I NN N G G D D O O MM MM
echo   KKK I N N G G D D O O M M
echo   K K I N NN G GG D D O O M M
echo   K K III N N GGG DDD OOO M M
echo.
echo     CCC OOO
echo     C O O
echo     C O O
echo     C O O
echo     CCC OOO
echo.
echo     KINGDOM ^& CO
echo     MEmu Auto Installer v2.10.2
echo     Multi-Emulator Batch Support
echo.
echo --------------------------------------------------
echo.
echo   Checking for updates...
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0AutoUpdater.ps1"

echo.
echo --------------------------------------------------
echo.
echo   Checking MEmu...
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0UpdateFiles.ps1"

echo.
echo --------------------------------------------------
echo.
echo   Launching...
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0KingROK.ps1"
pause
