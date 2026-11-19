@echo off
setlocal
title Droptix Launcher

echo ===================================================
echo             DROPTIX ONE-CLICK LAUNCHER
echo ===================================================
echo.

set "PATH=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin;C:\Program Files\Docker\Docker\resources\bin;%PATH%"

cd /d "%~dp0"

docker info >nul 2>&1
if not errorlevel 1 goto DOCKER_RUNNING

echo [1/3] Docker Desktop belum aktif. Membuka Docker Desktop...
if exist "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe" (
    start "" "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe"
)
echo Menunggu Docker engine aktif sekitar 20 detik...
timeout /t 20 /nobreak

:DOCKER_RUNNING
echo [1/3] Menyalakan Backend Express dan Database PostgreSQL...
docker compose up -d

:: Mendeteksi alamat IP lokal laptop di jaringan Wi-Fi
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object IPv4DefaultGateway).IPv4Address.IPAddress"') do set "LOCAL_IP=%%a"
if "%LOCAL_IP%"=="" set "LOCAL_IP=192.168.1.158"

echo.
echo [2/3] Backend aktif di:
echo       - Komputer lokal : http://localhost:3000/api/v1
echo       - Jaringan HP    : http://%LOCAL_IP%:3000/api/v1
echo.

echo [3/3] Pilih target aplikasi Flutter:
echo   [1] Google Chrome (Web) - Rekomendasi
echo   [2] Windows Desktop
echo   [3] Jalankan langsung di HP Android (Kabel USB)
echo.
choice /c 123 /m "Masukkan pilihan"
if errorlevel 3 goto TARGET_PHONE_USB
if errorlevel 2 goto TARGET_WINDOWS
if errorlevel 1 goto TARGET_CHROME

:TARGET_CHROME
echo.
echo Menjalankan Droptix di Google Chrome...
cd /d "%~dp0app"
call flutter run -d chrome
goto FINISH

:TARGET_WINDOWS
echo.
echo Menjalankan Droptix di Windows Desktop...
cd /d "%~dp0app"
call flutter run -d windows
goto FINISH

:TARGET_PHONE_USB
echo.
echo Menjalankan Droptix langsung di HP Android via USB...
echo Menggunakan URL API: http://%LOCAL_IP%:3000/api/v1
cd /d "%~dp0app"
call flutter run -d android --dart-define=API_BASE_URL=http://%LOCAL_IP%:3000/api/v1
goto FINISH

:FINISH
pause