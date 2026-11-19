@echo off
title Droptix — Menghentikan Backend

echo ===================================================
echo             DROPTIX STOP BACKEND
echo ===================================================
echo.

set "PATH=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin;C:\Program Files\Docker\Docker\resources\bin;%PATH%"

echo Menghentikan container database dan API backend...
docker compose down

echo.
echo [OK] Backend dan database telah dihentikan.
echo Data database tetap tersimpan dengan aman di Docker volume.
echo.
pause
