@echo off
setlocal EnableExtensions
title Jalankan Cepat (tanpa test) - Presensi Wajah UNEJ
cd /d "%~dp0"

echo ============================================================
echo   JALANKAN CEPAT KE DEVICE ANDROID
echo ============================================================
echo   Mode ini melewati analyze dan test agar langsung build.
echo   Cocok untuk iterasi harian setelah build pertama sukses.
echo ============================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Perintah "flutter" tidak ditemukan di PATH.
    goto :selesai
)

set "ADB=C:\android-sdk\platform-tools\adb.exe"
set "TARGET="
if exist "%ADB%" (
    for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
        if "%%B"=="device" if not defined TARGET set "TARGET=%%A"
    )
)

if not defined TARGET (
    echo [ERROR] Tidak ada device Android berstatus "device".
    echo         Aktifkan USB Debugging dan terima dialog RSA.
    goto :selesai
)

echo Device: %TARGET%
echo.

rem --no-pub karena dependency sudah ada; hot reload dipertahankan.
call flutter run -d %TARGET% --no-pub
set "KODE=%ERRORLEVEL%"

echo.
if not "%KODE%"=="0" echo [PERINGATAN] flutter run selesai dengan kode %KODE%.

:selesai
echo.
echo ============================================================
echo   SELESAI. Tekan tombol apa saja untuk keluar.
echo ============================================================
pause >nul
endlocal
