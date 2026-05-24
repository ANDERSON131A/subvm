@echo off
setlocal enabledelayedexpansion
title Debian VM Setup

set /p VM_NAME="Container name [debian-vm]: "
if "%VM_NAME%"=="" set VM_NAME=debian-vm

set /p PORT="SSH port [2222]: "
if "%PORT%"=="" set PORT=2222

echo VM_NAME=%VM_NAME%> .env
echo SSH_PORT=%PORT%>> .env

echo [1/3] Cleaning old %VM_NAME% ...
wsl -d kali -- docker compose -f /mnt/e/debian-vm/docker-compose.yml --env-file /mnt/e/debian-vm/.env -p %VM_NAME% down -v 2>nul

echo [2/3] Building %VM_NAME% (port %PORT%) ...
wsl -d kali -- docker compose -f /mnt/e/debian-vm/docker-compose.yml --env-file /mnt/e/debian-vm/.env -p %VM_NAME% build
if errorlevel 1 goto end

echo [3/3] Starting %VM_NAME% ...
wsl -d kali -- docker compose -f /mnt/e/debian-vm/docker-compose.yml --env-file /mnt/e/debian-vm/.env -p %VM_NAME% up -d

echo.
echo ============================================
echo   %VM_NAME% ready!
echo   SSH : ssh root@localhost -p %PORT%
echo         (root / debian123)
echo         (vm   / vm123)
echo   Shell: shell.bat
echo ============================================

echo.
pause
