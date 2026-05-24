@echo off
setlocal enabledelayedexpansion
title Debian VM Shell

echo ==============================
echo   Docker Container Shell
echo ==============================
echo.

set COUNT=0
for /f "delims=" %%a in ('wsl -d kali -- docker ps --format "{{.Names}}" --filter "status=running" 2^>nul') do (
    set /a COUNT+=1
    set "NAME_!COUNT!=%%a"
    echo   [!COUNT!] %%a
)

if %COUNT%==0 (
    echo No running containers. Run setup.bat first.
    pause
    goto end
)

echo.
choice /c 123456789 /m "Select container" /n
set IDX=%errorlevel%
set CONTAINER=!NAME_%IDX%!

wsl -d kali -- docker exec -it !CONTAINER! bash

:end
