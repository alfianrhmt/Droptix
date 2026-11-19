@echo off
setlocal enabledelayedexpansion
title Droptix — Menjalankan Aplikasi

echo ===================================================
echo             DROPTIX ONE-CLICK LAUNCHER
echo ===================================================
echo.

:: Tambahkan path Docker Desktop ke session saat ini jika belum ada
set "PATH=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin;C:\Program Files\Docker\Docker\resources\bin;%PATH%"

:: Cek apakah Docker terpasang
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker tidak ditemukan! Pastikan Docker Desktop sudah terpasang.
    pause
    exit /b 1
)

:: Pastikan Docker Desktop sedang berjalan
echo [1/3] Memeriksa status Docker Desktop...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Docker Desktop belum aktif. Mencoba membuka Docker Desktop...
    if exist "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe" (
        start "" "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe"
    ) else if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
        start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    )
    echo Menunggu Docker engine siap (biasanya butuh 15-30 detik)...
    :WAIT_DOCKER
    timeout /t 5 /nobreak >nul
    docker info >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Sedang menunggu Docker engine...
        goto WAIT_DOCKER
    )
)
echo [OK] Docker engine aktif!
echo.

:: Menyalakan container database dan API backend
echo [2/3] Menyalakan Backend (Express API) dan Database (PostgreSQL)...
docker compose up -d
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Gagal menyalakan docker compose.
    pause
    exit /b 1
)

echo [OK] Backend aktif di http://localhost:3000/api/v1
echo.

:: Menjalankan Flutter
echo [3/3] Memilih target Flutter:
echo   1. Google Chrome (Web) - Rekomendasi
echo   2. Windows Desktop
echo   3. Perangkat Default / HP Android Terhubung
echo.
set /p TARGET="Pilih nomor target [1/2/3] (default: 1): "
if "%TARGET%"=="" set TARGET=1

cd app

if "%TARGET%"=="1" (
    echo Menjalankan Droptix di Google Chrome...
    flutter run -d chrome
) else if "%TARGET%"=="2" (
    echo Menjalankan Droptix di Desktop Windows...
    flutter run -d windows
) else (
    echo Menjalankan Droptix di perangkat terhubung...
    flutter run
)

pause
