@echo off
setlocal
title Droptix Launcher

set "PATH=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin;C:\Program Files\Docker\Docker\resources\bin;%PATH%"
cd /d "%~dp0"

cls
echo ===================================================
echo               DROPTIX APP LAUNCHER
echo ===================================================
echo.
echo Pilih target aplikasi untuk dijalankan:
echo.
echo   [1] Google Chrome (Laptop) - Rekomendasi
echo   [2] Windows Desktop
echo   [3] Layar HP (via Wi-Fi / Hotspot)
echo.
choice /c 123 /m "Masukkan pilihan"
if errorlevel 3 goto ACTION_PHONE
if errorlevel 2 goto ACTION_WINDOWS
if errorlevel 1 goto ACTION_CHROME

:START_DOCKER
docker info >nul 2>&1
if not errorlevel 1 goto DOCKER_IS_UP

echo.
echo Docker Desktop belum aktif. Membuka Docker Desktop...
if exist "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe" (
    start "" "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe"
)
echo Menunggu Docker engine aktif sekitar 20 detik...
timeout /t 20 /nobreak

:DOCKER_IS_UP
echo.
echo Menyalakan Backend Express dan Database PostgreSQL...
docker compose up -d
goto :eof

:ACTION_CHROME
call :START_DOCKER
echo.
echo Menjalankan Droptix di Google Chrome Laptop...
echo (Tekan 'q' di terminal ini untuk berhenti dan mematikan backend)
echo.
cd /d "%~dp0app"
call flutter run -d chrome
cd /d "%~dp0"
echo.
echo Menghentikan backend Docker...
docker compose down
echo Selesai. Sampai jumpa!
exit /b 0

:ACTION_WINDOWS
call :START_DOCKER
echo.
echo Menjalankan Droptix di Windows Desktop...
echo (Tutup aplikasi atau tekan 'q' di terminal untuk mematikan backend)
echo.
cd /d "%~dp0app"
call flutter run -d windows
cd /d "%~dp0"
echo.
echo Menghentikan backend Docker...
docker compose down
echo Selesai. Sampai jumpa!
exit /b 0

:ACTION_PHONE
call :START_DOCKER

for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object IPv4DefaultGateway).IPv4Address.IPAddress"') do set "LOCAL_IP=%%a"
if "%LOCAL_IP%"=="" set "LOCAL_IP=192.168.1.158"

echo.
echo ===================================================================
echo                  SERVER APLIKASI DROPTIX AKTIF
echo ===================================================================
echo.
echo Buka browser di HP Anda (Chrome / Safari), lalu ketik alamat ini:
echo.
echo         http://%LOCAL_IP%:8080
echo.
echo [STATUS] Backend dan server HP sedang BERJALAN.
echo Selama jendela terminal ini TERBUKA, backend TETAP HIDUP.
echo.
echo ===================================================================
node "%~dp0backend\scripts\serve-mobile-web.js"
exit /b 0