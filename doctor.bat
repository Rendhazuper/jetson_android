@echo off
setlocal EnableExtensions
title Flutter Doctor - Presensi Wajah UNEJ
cd /d "%~dp0"

echo ============================================================
echo   FLUTTER DOCTOR - jetson_android
echo ============================================================
echo   Folder : %CD%
echo   Waktu  : %DATE% %TIME%
echo ============================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Perintah "flutter" tidak ditemukan di PATH.
    echo         Tambahkan folder bin Flutter ke PATH lalu ulangi.
    echo.
    goto :selesai
)

echo === Versi Flutter ===
call flutter --version
echo.

echo === Flutter Doctor ===
call flutter doctor -v
echo.
echo === Ringkasan Doctor ===
call flutter doctor
echo.

echo === Perangkat Android (adb) ===
set "ADB=C:\android-sdk\platform-tools\adb.exe"
if exist "%ADB%" (
    "%ADB%" devices -l
    echo.
    echo Jika daftar di atas kosong, lakukan di ponsel:
    echo   1. Aktifkan Opsi Pengembang / Developer Options
    echo   2. Aktifkan USB Debugging
    echo   3. Colok kabel USB, lalu pilih "Allow" pada dialog RSA
    echo   4. Jalankan ulang file .bat ini
) else (
    echo [INFO] adb tidak ditemukan di %ADB%
    echo        Jalankan: adb devices
)

echo.
echo === Perangkat yang terdeteksi Flutter ===
call flutter devices
echo.

:selesai
echo ============================================================
echo   SELESAI. Jendela ini tidak akan tertutup otomatis.
echo   Tekan tombol apa saja untuk keluar.
echo ============================================================
pause >nul
endlocal
