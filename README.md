# Presensi Wajah UNEJ — Aplikasi Android (Flutter)

Aplikasi Android untuk presensi berbasis wajah. Inference berjalan di
perangkat; server hanya menerima hasil presensi yang sudah tervalidasi.

Repository ini terpisah dari aplikasi Python (`jetson`). Kode Python dipakai
untuk membangun artefak model dan gallery, bukan dibagikan sebagai kode.

## Status

Fitur yang sudah berjalan:

- Kamera via CameraX (preview tanpa distorsi, object-fit cover)
- Deteksi wajah Google ML Kit, crop area wajah presisi dengan koreksi rotasi sensor
- Preprocessing: resize 112×112, CLAHE, tensor NCHW float32
- Ekstraksi embedding SFace ONNX (onnxruntime) + cosine distance matching
- Cooldown presensi per identitas (gate 30 detik)
- Pengiriman `POST idpersonal` ke layanan API, async
- Pop-up "PRESENSI BERHASIL" otomatis setelah API mengonfirmasi
- Panel informasi + log presensi harian (badge ID biru, nama oranye)

## Prasyarat

- Flutter 3.38.x (Dart 3.10.x)
- Android SDK, JDK 17
- Terima lisensi Android: `flutter doctor --android-licenses`
- Perangkat Android fisik atau emulator untuk menguji kamera
- Python + numpy (untuk menyiapkan aset encodings)

## Menyiapkan aset (wajib sebelum build)

Model dan encodings **tidak disimpan di repository**. Jalankan sekali:

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

## Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Script Windows (.bat)

Klik dua kali pada file berikut (tidak menutup jendela saat selesai):

| File | Fungsi |
|---|---|
| `setup_assets.bat` | Salin model SFace + konversi encodings dari project Python |
| `accept_licenses.bat` | Terima lisensi Android SDK, lalu verifikasi `flutter doctor` |
| `doctor.bat` | Cek Flutter, Android toolchain, device adb, dan device Flutter |
| `run_android.bat` | `pub get` → `analyze` → `test` → `flutter run` ke device |
| `run_fast.bat` | Langsung `flutter run` tanpa analyze/test (iterasi harian) |

Urutan pertama kali pakai:
`accept_licenses.bat` → `setup_assets.bat` → `doctor.bat` → `run_android.bat`.

Jika device Android tidak terdeteksi:
1. Aktifkan Developer Options dan USB Debugging di ponsel.
2. Colok kabel USB, pilih **Allow** pada dialog RSA.
3. Jalankan ulang `doctor.bat` untuk memastikan device muncul.

## Artefak yang tidak di-commit

Model dan gallery adalah data sensitif dan besar:

- `assets/models/*.onnx`
- `assets/encodings.json`
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

- Skor `1 - distance` **bukan** probabilitas; threshold belum dikalibrasi formal (FAR/FRR).
- Belum ada liveness/anti-spoofing.
- Kontrak API backend belum final; tanpa URL, aplikasi memakai data demo lokal.
- Enrollment tetap di sisi Python; aplikasi hanya konsumen gallery.
