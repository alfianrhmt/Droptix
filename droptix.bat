@echo off
setlocal
title Droptix Control Center

set "PATH=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin;C:\Program Files\Docker\Docker\resources\bin;%PATH%"
cd /d "%~dp0"

:MAIN_MENU
cls
echo ===================================================
echo             DROPTIX CONTROL CENTER
echo ===================================================
echo.
echo Pilih aksi:
echo   [1] Jalankan di Google Chrome (Laptop) - Rekomendasi
echo   [2] Jalankan di Desktop Windows
echo   [3] Jalankan untuk Layar HP (Browser di HP)
echo   [4] Hentikan Backend (Stop Docker)
echo   [0] Keluar
echo.
choice /c 12340 /m "Masukkan pilihan"
if errorlevel 5 goto EXIT_SCRIPT
if errorlevel 4 goto ACTION_STOP
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
cd /d "%~dp0app"
call flutter run -d chrome
pause
goto MAIN_MENU

:ACTION_WINDOWS
call :START_DOCKER
echo.
echo Menjalankan Droptix di Windows Desktop...
cd /d "%~dp0app"
call flutter run -d windows
pause
goto MAIN_MENU

:ACTION_PHONE
call :START_DOCKER

for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object IPv4DefaultGateway).IPv4Address.IPAddress"') do set "LOCAL_IP=%%a"
if "%LOCAL_IP%"=="" set "LOCAL_IP=192.168.1.158"

echo.
echo ===================================================================
echo                   SERVER APLIKASI UNTUK HP AKTIF
echo ===================================================================
echo.
echo Buka browser di HP Anda (Chrome / Safari), lalu ketik alamat ini:
echo.
echo               >>> http://%LOCAL_IP%:8080 <<<
echo.
echo Catatan:
echo - Pastikan HP dan laptop di jaringan yang sama (misal Hotspot HP).
echo - Biarkan jendela ini TETAP TERBUKA selama Anda membuka di HP.
echo - Tekan Ctrl + C jika ingin berhenti dan kembali ke menu.
echo ===================================================================
echo.
node "%~dp0backend\scripts\serve-mobile-web.js"
pause
goto MAIN_MENU

:ACTION_STOP
echo.
echo Menghentikan Backend dan Database Docker...
docker compose down
echo [OK] Backend dan database telah dihentikan.
echo Data tetap tersimpan aman di Docker volume.
echo.
pause
goto MAIN_MENU

:EXIT_SCRIPT
echo Sampai jumpa!
exit /b 0