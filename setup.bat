@echo off
setlocal enabledelayedexpansion
title VM Setup

echo ==============================
echo   VM Setup
echo ==============================
echo.
echo Distros:
echo   [1] Debian latest
echo   [2] openEuler latest
echo.
set /p DISTRO="Distro [1]: "

if "%DISTRO%"=="2" goto euler
if /i "%DISTRO%"=="euler" goto euler

set COMPOSE_FILE=docker-compose.yml
set DISTRO_NAME=Debian
set BASE_IMAGE=debian:latest
set DEF_NAME=debian-vm
set DEF_ROOT=debian123
goto distro_ok

:euler
set COMPOSE_FILE=docker-compose.euler.yml
set DISTRO_NAME=openEuler
set BASE_IMAGE=openeuler/openeuler:latest
set DEF_NAME=euler-vm
set DEF_ROOT=euler123

:distro_ok
echo.
set /p VM_NAME="Container name [%DEF_NAME%]: "
if "%VM_NAME%"=="" set VM_NAME=%DEF_NAME%

set /p PORT="SSH port [2222]: "
if "%PORT%"=="" set PORT=2222

echo VM_NAME=%VM_NAME%> .env
echo SSH_PORT=%PORT%>> .env
echo BASE_IMAGE=%BASE_IMAGE%>> .env

rem === Check WSL ===
wsl -d kali -- echo ok >nul 2>&1
if errorlevel 1 (
    echo [ERROR] WSL distro "kali" not available.
    echo   Run: wsl --install -d kali
    goto end
)

rem === Check / Start Docker ===
wsl -d kali -- docker info >nul 2>&1
if not errorlevel 1 goto docker_ok
echo Docker is not running, starting it ...
wsl -d kali -u root -- service docker start >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to start Docker daemon.
    goto end
)
echo Waiting for Docker daemon ...
set /a TRIES=0
:waitdocker
set /a TRIES+=1
if !TRIES! gtr 10 (
    echo [ERROR] Docker did not start properly.
    goto end
)
timeout /t 2 /nobreak >nul
wsl -d kali -- docker info >nul 2>&1
if errorlevel 1 goto waitdocker
echo Docker started successfully.
:docker_ok

echo [1/3] Cleaning old %VM_NAME% ...
wsl -d kali --cd "%~dp0" -- docker compose -f %COMPOSE_FILE% --env-file .env -p %VM_NAME% down -v 2>nul

echo [2/3] Building %DISTRO_NAME% (%VM_NAME%, port %PORT%) ...
wsl -d kali --cd "%~dp0" -- docker compose -f %COMPOSE_FILE% --env-file .env -p %VM_NAME% build --pull
if errorlevel 1 goto end

echo [3/3] Starting %VM_NAME% ...
wsl -d kali --cd "%~dp0" -- docker compose -f %COMPOSE_FILE% --env-file .env -p %VM_NAME% up -d

echo.
echo ============================================
echo   %DISTRO_NAME% - %VM_NAME% ready!
echo   Image: %BASE_IMAGE%
echo   SSH : ssh root@localhost -p %PORT%
echo         (root / %DEF_ROOT%)
echo         (vm   / vm123)
echo   Shell: shell.bat
echo ============================================

echo.
:end
pause
