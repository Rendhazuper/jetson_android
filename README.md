# Presensi Wajah UNEJ — Aplikasi Android (Flutter)

Aplikasi Android untuk presensi berbasis wajah. Inference berjalan di
perangkat; server hanya menerima hasil presensi yang sudah tervalidasi.

Repository ini terpisah dari aplikasi Python (`jetson`). Kode Python dipakai
untuk membangun artefak model dan gallery, bukan dibagikan sebagai kode.

## Status

Fitur yang sudah berjalan:

- Kamera via CameraX (preview tanpa distorsi, object-fit cover)
- Deteksi wajah Google ML Kit dengan 5 landmark; rotasi frame dihitung dari
  orientasi sensor **dan** orientasi fisik perangkat (portrait/landscape)
- Preprocessing: alignment 5 landmark ke template SFace 112×112, CLAHE kanal L
  (LAB), tensor NCHW float32 (lihat "Resep preprocessing")
- Ekstraksi embedding SFace ONNX (onnxruntime) + cosine distance matching
- Cooldown presensi per identitas (gate 30 detik)
- Pengiriman `POST {"idpersonal": "..."}` ke layanan API, async. URL default
  `https://api-sister.unej.ac.id/perkuliahan/tendik/info-person`; timpa dengan
  `--dart-define=PERSON_INFO_API_URL=<url>`, nilai kosong = mode demo offline
- Pop-up "Presensi Vision Berhasil" otomatis setelah API mengonfirmasi
- Tampilan UPATIK tiga kolom: hasil presensi + status di kiri, kamera dengan
  bingkai di tengah, log presensi harian di kanan (badge ID biru, nama oranye)

## Prasyarat

- Flutter 3.38.x (Dart 3.10.x); build dan jalan juga di Flutter 3.47.3 (Dart 3.13.3)
- Android SDK, JDK 17
- Terima lisensi Android: `flutter doctor --android-licenses`
- Perangkat Android fisik atau emulator untuk menguji kamera
- Python + numpy (untuk menyiapkan aset encodings)
- macOS: Android Studio dengan plugin **Flutter** dan **Dart**; SDK default
  di `~/Library/Android/sdk`. JDK bawaan Android Studio (JBR) sudah cukup.

## Menyiapkan aset (wajib sebelum build)

Model dan encodings **tidak disimpan di repository**. Build gagal bila
`assets/models/` atau `assets/encodings.json` belum ada, karena keduanya
terdaftar di `pubspec.yaml`. Dua file yang dibutuhkan:

- `assets/models/face_recognition_sface.onnx`
- `assets/encodings.json`

### Windows

```bash
setup_assets.bat
```

Script ini menyalin model SFace dan mengonversi `encodings.pkl` dari project
Python menjadi `assets/encodings.json`. Bila lokasi project Python berbeda,
set dulu:

```bat
set JETSON_DIR=D:\Code Activity\jetson
setup_assets.bat
```

### macOS / Linux

File `.bat` tidak jalan di macOS. Lakukan langkahnya manual dari root project.

1. Model SFace. Salin dari project Python, atau unduh `face_recognition_sface_2021dec.onnx`
   dari [OpenCV Zoo](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)
   (sekitar 37 MB). Namanya harus `face_recognition_sface.onnx`:

   ```bash
   mkdir -p assets/models
   cp /PATH/KE/face_recognition_sface.onnx assets/models/face_recognition_sface.onnx
   ```

   Pakai model yang sama dengan yang membuat `encodings.pkl`. Varian lain
   (misalnya int8) memberi embedding sedikit berbeda, sehingga skor tidak cocok.

2. Konversi `encodings.pkl` menjadi `assets/encodings.json` (perlu `numpy`):

   ```bash
   python3 -c "import pickle,json;d=pickle.load(open('/PATH/KE/encodings.pkl','rb'));json.dump({'encodings':[a.reshape(-1).tolist() for a in d['encodings']],'names':d['names']},open('assets/encodings.json','w'))"
   ```

   Format `.pkl`: dict dengan kunci `encodings` (daftar array 128 dimensi) dan
   `names` (daftar label, panjang sama).

> Jangan letakkan `encodings.pkl` di dalam `assets/`. Seluruh isi
> `assets/models/` ikut dibundel ke APK, sehingga data wajah ikut terdistribusi.
> Simpan `.pkl` di luar `assets/` (pola `*.pkl` sudah di-gitignore).

## Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### macOS: ke tablet atau ponsel Android

1. Aktifkan **Developer Options** dan **USB Debugging** di tablet, colok kabel
   USB, lalu pilih **Allow** pada dialog RSA.
2. Pastikan perangkat terdeteksi:

   ```bash
   flutter devices
   ~/Library/Android/sdk/platform-tools/adb devices
   ```

   Catat ID perangkat (kolom kedua `flutter devices`).
3. Jalankan dari terminal:

   ```bash
   flutter pub get
   flutter run -d <ID_PERANGKAT>
   ```

   Atau dari Android Studio: buka folder project, pilih perangkat di dropdown
   device pada toolbar, lalu klik **Run**. Build pertama lama karena Gradle
   mengunduh dependency.
4. Izinkan akses kamera saat aplikasi pertama kali dibuka.

Bila perangkat tidak muncul: cabut dan colok ulang kabel, ganti kabel yang
mendukung data (bukan hanya charging), lalu ulangi langkah 1.

Bila instalasi menggantung lama: lihat layar tablet. Perangkat Huawei menampilkan
dialog pemeriksaan risiko instalasi (AppGallery) yang harus disetujui di tablet;
selama dialog itu belum disetujui, `flutter run` dan `adb install` menunggu terus.
Jangan jalankan dua instalasi bersamaan ke satu perangkat.

Bila `flutter run` gagal dengan `package_config.json does not exist`, jalankan
`flutter pub get` (file itu terhapus oleh `flutter clean`).

Memasang APK debug tanpa menjalankan debugger:

```bash
flutter build apk --debug
flutter install --debug -d <ID_PERANGKAT>
```

### Script Windows (.bat)

Hanya untuk Windows. Klik dua kali pada file berikut (tidak menutup jendela saat selesai):

| File | Fungsi |
|---|---|
| `setup_assets.bat` | Salin model SFace + konversi encodings dari project Python |
| `accept_licenses.bat` | Terima lisensi Android SDK, lalu verifikasi `flutter doctor` |
| `doctor.bat` | Cek Flutter, Android toolchain, device adb, dan device Flutter |
| `run_android.bat` | `pub get` → `analyze` → `test` → `flutter run` ke device |
| `run_fast.bat` | Langsung `flutter run` tanpa analyze/test (iterasi harian) |

Urutan pertama kali pakai:
`accept_licenses.bat` → `setup_assets.bat` → `doctor.bat` → `run_android.bat`.

> **Perhatian:** dengan URL default, setiap pengenalan yang lolos mengirim ID
> ke API produksi dan dapat mencatat presensi sungguhan (ulang tiap cooldown
> 30 detik selama wajah tetap di depan kamera). Untuk uji coba gunakan gallery
> kecil atau `--dart-define=PERSON_INFO_API_URL=` (kosong).

Jika device Android tidak terdeteksi:
1. Aktifkan Developer Options dan USB Debugging di ponsel.
2. Colok kabel USB, pilih **Allow** pada dialog RSA.
3. Jalankan ulang `doctor.bat` untuk memastikan device muncul.

## Resep preprocessing (harus sama dengan gallery)

Embedding SFace sangat sensitif terhadap cara wajah disiapkan. Gallery
`encodings` dibuat dengan resep OpenCV berikut, dan aplikasi mengikutinya:

1. Deteksi wajah, ambil 5 landmark (mata, hidung, sudut mulut).
2. `alignCrop` ke 112×112 memakai template 5 titik SFace
   (`AppConfig.sfaceTemplate`).
3. CLAHE pada kanal L di ruang LAB (`clipLimit=2.0`, `tileGridSize=8×8`),
   lalu kembali ke RGB.
4. Tensor NCHW float32, nilai 0–255 (tanpa normalisasi), urutan RGB.

Pembuktian: foto enrollment yang diproses dengan resep ini memberi jarak
**0.000** ke vektor di `encodings.pkl`; crop bounding box biasa memberi
0.48–0.74. Port CLAHE-LAB di Dart (`face_preprocessor.dart`) berbeda dari
OpenCV hanya 0.002–0.033 pada jarak embedding, karena CLAHE dengan
`clipLimit=1` per tile sensitif terhadap pembulatan konversi LAB.

Bila menyiapkan gallery baru dari foto mentah, pakai resep yang sama
(OpenCV `FaceDetectorYN` YuNet + `FaceRecognizerSF.alignCrop` + CLAHE LAB),
bukan crop bounding box.

### Rotasi kamera

Buffer kamera depan diputar `(sensorOrientation + orientasiPerangkat) % 360`
(`CameraUtils.rotationDegrees`). Memakai `sensorOrientation` saja hanya benar
saat perangkat portrait; pada tablet landscape wajah masuk ML Kit dan SFace
tergeletak 90° dan jarak ke gallery tinggi (0.6–0.9) walau wajah terdaftar.

### Bila wajah terdaftar tetap `UNKNOWN`

- Hadap lurus ke kamera depan, setinggi mata, jarak 40–50 cm, cahaya cukup.
  Menengadah atau menoleh menaikkan jarak sampai 0.5–0.7.
- Lihat log `[RECOG]` (`adb logcat -s flutter`): `closest=` memberi ID terdekat
  dan `bestDistance` jaraknya. Kecocokan sungguhan umumnya di bawah 0.45.
- Pastikan ID ada di `assets/encodings.json`.

## Artefak yang tidak di-commit

Model dan gallery adalah data sensitif dan besar:

- `assets/models/*.onnx`
- `assets/encodings.json`
- `assets/raw-faces-data/` (foto wajah mentah; sebaiknya simpan di luar project)
- `assets/gallery/*`
- file `*.pkl`, `*.bin`, `*.npy`

**Alasan:** `encodings.json` berisi vektor wajah orang sungguhan. Jangan pernah
commit ke repository publik. Sediakan melalui kanal privat saat build
(lihat `setup_assets.bat`). Lihat `docs/architecture_decisions.md` ADR-2 dan ADR-6.

## Dokumentasi

| Dokumen | Isi |
|---|---|
| `docs/PRD_ANDROID.md` | Kebutuhan produk, risiko, kriteria penerimaan |
| `docs/architecture_decisions.md` | ADR: repo, kontrak gallery, batas Dart/native, state, API, privasi |
| `docs/platform_channel_contract.md` | Kontrak channel kamera/inference |

## Batasan yang perlu diketahui

- ID personal bersifat rahasia: tidak ditampilkan di UI (banner, log, cadangan
  nama saat API gagal, mode demo). Identitas yang tampil hanya dari balasan API,
  dan log `[RECOG]` yang memuat ID hanya dicetak pada build debug.
- Skor `1 - distance` **bukan** probabilitas; threshold belum dikalibrasi formal (FAR/FRR).
- Batas terima efektif **0.45** dengan **voting 3 frame berurutan**
  (`AppConfig.dynamicThreshold*`, `recognitionVotes`). Angka ini perkiraan awal,
  bukan hasil kalibrasi FAR/FRR. Ukuran dari foto enrollment pada gallery 1.904
  identitas (wajah tak terdaftar yang diterima): 0.60 → ~99%, 0.50 → 44%,
  0.45 → 12%, 0.40 → 1%, 0.35 → 0,1%. Di tablet uji, ambang 0.60 tanpa voting
  menerima 3 ID orang lain dalam 9 detik sementara pemilik ID sah di 0.37–0.43.
  Kalibrasi ulang dengan data kamera target sebelum dipakai sungguhan.
- Kamera depan tablet uji (720×480) lebih redup dan lebih berisik daripada foto
  enrollment, sehingga jarak wajah sah cenderung lebih tinggi dari di Python.
- Belum ada liveness/anti-spoofing.
- Kontrak API backend belum final; tanpa URL, aplikasi memakai data demo lokal.
- Enrollment tetap di sisi Python; aplikasi hanya konsumen gallery.
