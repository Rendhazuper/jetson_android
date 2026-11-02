@echo off
setlocal EnableExtensions
title Jalankan Aplikasi di Device Android - Presensi Wajah UNEJ
cd /d "%~dp0"

echo ============================================================
echo   JALANKAN APLIKASI DI DEVICE ANDROID
echo ============================================================
echo   Folder : %CD%
echo ============================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Perintah "flutter" tidak ditemukan di PATH.
    goto :selesai
)

set "ADB=C:\android-sdk\platform-tools\adb.exe"

echo === Cek device ===
if exist "%ADB%" (
    "%ADB%" devices -l
) else (
    echo [INFO] adb tidak ditemukan di %ADB%
)
echo.

echo === Ambil dependency ===
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get gagal.
    goto :selesai
)
echo.

echo === Analisis kode ===
call flutter analyze
echo.

echo === Unit test ===
call flutter test
echo.

echo === Menjalankan di Android ===
echo Tips: tekan  r  untuk hot reload,  R  untuk hot restart,  q  untuk keluar.
echo.

set "TARGET="
if exist "%ADB%" (
    for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
        if "%%B"=="device" if not defined TARGET set "TARGET=%%A"
    )
)

if not defined TARGET (
    echo [INFO] Tidak ada device Android berstatus "device".
    echo        Pastikan USB Debugging aktif dan dialog RSA sudah di-Allow.
    goto :selesai
)

echo Device Android terdeteksi: %TARGET%
echo.
call flutter run -d %TARGET%
set "KODE=%ERRORLEVEL%"

echo.
if not "%KODE%"=="0" (
    echo [PERINGATAN] flutter run selesai dengan kode %KODE%.
    echo Periksa pesan di atas. Sering disebabkan:
    echo   - Belum ada device Android terdeteksi
    echo   - Lisensi SDK belum diterima ^(jalankan accept_licenses.bat^)
    echo   - USB Debugging belum aktif / dialog RSA belum di-Allow
)

:selesai
echo.
echo ============================================================
echo   SELESAI. Jendela ini tidak akan tertutup otomatis.
echo   Tekan tombol apa saja untuk keluar.
echo ============================================================
pause >nul
endlocal
