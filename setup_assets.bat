@echo off
setlocal EnableExtensions
title Siapkan Aset Model & Encodings - Presensi Wajah UNEJ
cd /d "%~dp0"

echo ============================================================
echo   SIAPKAN ASET MODEL ^& ENCODINGS
echo ============================================================
echo.
echo File berikut TIDAK disimpan di repository karena berisi
echo model besar dan data biometrik:
echo   - assets\models\face_recognition_sface.onnx
echo   - assets\encodings.json
echo.
echo Script ini mengambilnya dari project Python (jetson).
echo ============================================================
echo.

rem Sesuaikan bila lokasi project Python berbeda.
set "JETSON_DIR=%JETSON_DIR%"
if "%JETSON_DIR%"=="" set "JETSON_DIR=..\jetson"

set "SFACE_SRC=%JETSON_DIR%\models\sface\face_recognition_sface.onnx"
set "ENC_SRC=%JETSON_DIR%\models\encodings.pkl"

echo Lokasi project Python: %JETSON_DIR%
echo.

if not exist "%SFACE_SRC%" (
    echo [ERROR] Model SFace tidak ditemukan:
    echo         %SFACE_SRC%
    echo         Set variabel JETSON_DIR bila lokasinya berbeda.
    goto :selesai
)

if not exist "%ENC_SRC%" (
    echo [ERROR] encodings.pkl tidak ditemukan:
    echo         %ENC_SRC%
    echo         Jalankan dulu: python core\enroll.py
    goto :selesai
)

if not exist "assets\models" mkdir "assets\models"

echo [1/2] Menyalin model SFace...
copy /Y "%SFACE_SRC%" "assets\models\face_recognition_sface.onnx" >nul
if errorlevel 1 (
    echo [ERROR] Gagal menyalin model.
    goto :selesai
)
echo       OK

echo [2/2] Mengonversi encodings.pkl ke encodings.json...
python -c "import pickle,json;d=pickle.load(open(r'%ENC_SRC%','rb'));json.dump({'encodings':[a.reshape(-1).tolist() for a in d['encodings']],'names':d['names']},open(r'assets\encodings.json','w'))"
if errorlevel 1 (
    echo [ERROR] Konversi gagal. Pastikan Python + numpy terpasang.
    goto :selesai
)
echo       OK

echo.
echo ============================================================
echo   SELESAI. Aset siap untuk build.
echo   Selanjutnya: flutter build apk
echo ============================================================

:selesai
echo.
echo Tekan tombol apa saja untuk keluar.
pause >nul
endlocal
