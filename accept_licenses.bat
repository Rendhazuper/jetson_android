@echo off
setlocal EnableExtensions
title Terima Lisensi Android SDK - Presensi Wajah UNEJ
cd /d "%~dp0"

echo ============================================================
echo   TERIMA LISENSI ANDROID SDK
echo ============================================================
echo   Perintah ini akan menampilkan beberapa lisensi SDK.
echo   Ketik  y  lalu Enter pada setiap pertanyaan untuk menerima.
echo.
echo   Tanpa ini, build Android akan gagal.
echo ============================================================
echo.
echo Tekan tombol apa saja untuk mulai...
pause >nul
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Perintah "flutter" tidak ditemukan di PATH.
    goto :selesai
)

call flutter doctor --android-licenses
set "KODE=%ERRORLEVEL%"

echo.
if "%KODE%"=="0" (
    echo [OK] Lisensi selesai diproses.
) else (
    echo [PERINGATAN] Exit code: %KODE%
    echo Periksa keluaran di atas bila masih ada lisensi yang ditolak.
)

echo.
echo === Verifikasi ===
call flutter doctor

:selesai
echo.
echo ============================================================
echo   SELESAI. Jendela ini tidak akan tertutup otomatis.
echo   Tekan tombol apa saja untuk keluar.
echo ============================================================
pause >nul
endlocal
