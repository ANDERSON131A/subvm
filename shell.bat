@echo off
setlocal enabledelayedexpansion
title Debian VM Shell

echo ==============================
echo   Docker Container Shell
echo ==============================
echo.

rem === Check WSL ===
wsl -d kali -- echo ok >nul 2>&1
if errorlevel 1 (
    echo [ERROR] WSL distro "kali" not available.
    echo   Run: wsl --install -d kali
    pause
    exit /b 1
)

rem === Check / Start Docker ===
wsl -d kali -- docker info >nul 2>&1
if errorlevel 1 (
    echo Docker is not running.
    choice /c YN /m "Start it now" /n
    if errorlevel 2 goto end
    echo Starting Docker ...
    wsl -d kali -u root -- service docker start >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Failed to start Docker daemon.
        pause
        exit /b 1
    )
    timeout /t 2 /nobreak >nul
    wsl -d kali -- docker info >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Docker did not start properly.
        pause
        exit /b 1
    )
    echo Docker started successfully.
    echo.
)

rem === Enumerate containers ===
set RUN_COUNT=0
for /f "delims=" %%a in ('wsl -d kali -- docker ps --format "{{.Names}}" --filter "status=running" 2^>nul') do (
    set /a RUN_COUNT+=1
    set "NAME_!RUN_COUNT!=%%a"
    set "RUN_FLAG_!RUN_COUNT!=1"
)

set STOP_COUNT=0
for /f "delims=" %%a in ('wsl -d kali -- docker ps -a --format "{{.Names}}" --filter "status=exited" 2^>nul') do (
    set /a STOP_COUNT+=1
    set /a IDX=RUN_COUNT+STOP_COUNT
    set "NAME_!IDX!=%%a"
    set "RUN_FLAG_!IDX!=0"
)

set /a TOTAL=RUN_COUNT+STOP_COUNT

rem === No containers ===
if !TOTAL!==0 (
    echo No containers found.
    echo.
    choice /c YN /m "Run setup.bat to create one" /n
    if errorlevel 2 goto end
    call "%~dp0setup.bat"
    goto end
)

rem === Display containers ===
echo.

if !RUN_COUNT! gtr 0 (
    echo Running:
    for /l %%i in (1,1,!RUN_COUNT!) do (
        echo   [%%i] !NAME_%%i!
    )
    echo.
)

if !STOP_COUNT! gtr 0 (
    echo Stopped:
    for /l %%i in (1,1,!STOP_COUNT!) do (
        set /a IDX=RUN_COUNT+%%i
        echo   [!IDX!] !NAME_!IDX!!  (stopped)
    )
    echo.
)

rem === Select container ===
set _num=0
:select
set /p SEL="Select container [1-!TOTAL!]: "
if "!SEL!"=="" goto end
set /a _num=!SEL! 2>nul
if !_num! lss 1 (
    echo Invalid input.
    goto select
)
if !_num! gtr !TOTAL! (
    echo Invalid input.
    goto select
)

set CONTAINER=!NAME_%_num%!

rem === Start if stopped ===
if !RUN_FLAG_%_num%!==0 (
    echo.
    echo Starting "!CONTAINER!" ...
    wsl -d kali -- docker start !CONTAINER!
    if errorlevel 1 (
        echo Failed to start !CONTAINER!.
        pause
        goto end
    )
)

echo.
wsl -d kali -- docker exec -it !CONTAINER! bash

:end
pause
