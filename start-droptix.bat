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
echo   [1] Google Chrome (Web) - Paling Cepat dan Mudah
echo   [2] Windows Desktop
echo   [3] Jalankan langsung di HP Android (Kabel USB)
echo   [4] Buat file APK untuk HP (Build APK Otomatis)
echo.
choice /c 1234 /m "Masukkan pilihan"
if errorlevel 4 goto TARGET_BUILD_APK
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

:TARGET_BUILD_APK
echo.
echo ===================================================
echo             MEMBUAT FILE APK ANDROID
echo ===================================================
echo Mengompilasi aplikasi dengan URL backend:
echo http://%LOCAL_IP%:3000/api/v1
echo.
cd /d "%~dp0app"
call flutter build apk --debug --dart-define=API_BASE_URL=http://%LOCAL_IP%:3000/api/v1
if errorlevel 1 (
    echo [ERROR] Gagal mengompilasi APK.
    goto FINISH
)
echo.
echo [SUKSES] File APK berhasil dibuat!
echo Lokasi: app\build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Membuka folder APK di File Explorer agar bisa langsung dikirim ke HP...
start explorer "%~dp0app\build\app\outputs\flutter-apk"
goto FINISH

:FINISH
pause