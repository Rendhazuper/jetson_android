# Keputusan Arsitektur — Aplikasi Presensi Wajah UNEJ (Flutter)

Dokumen ini mencatat keputusan arsitektur sebelum implementasi kode.
PRD acuan berada di repository Python: `jetson/PRD_ANDROID.md`.

- **Repository:** terpisah dari `jetson` (Python), di `jetson_android`.
- **Stack UI:** Flutter / Dart.
- **Package id:** `id.ac.unej.face_presensi`
- **minSdk:** 24

## ADR-1 — Repository terpisah

**Keputusan:** Aplikasi Android berada di repository sendiri (`jetson_android`), bukan subfolder `jetson`.

**Alasan:**
- `jetson` adalah proyek Python (OpenCV/Tkinter/Flask) dengan toolchain berbeda.
- Repo `jetson` sudah memuat artefak besar dan biometrik (`models/sface/*.onnx` 38 MB, `models/encodings.pkl`, `database/test_input/*.jpg`); menambah Flutter memperbesar risiko penyebaran data.
- Branch `feat/implement_yolo` masih aktif; riwayat Android harus tetap bersih.

**Konsekuensi:** Perlu kontrak artefak eksplisit (lihat ADR-2). PRD tetap di `jetson` sebagai sumber spesifikasi.

## ADR-2 — Kontrak gallery, bukan transfer kode

**Keputusan:** Python tidak mengirim kode ke Flutter. Yang dipertukarkan adalah **artefak gallery versioned**.

**Format minimum (`gallery.json` + `embeddings.bin`):**

| Field | Keterangan |
|---|---|
| `formatVersion` | versi format gallery; Flutter menolak versi tak dikenal |
| `model.id`, `model.sha256` | identitas model SFace yang diekstrak |
| `preprocessing.version` | versi urutan alignCrop + CLAHE + resize |
| `feature.dimensions` | dimensi embedding (SFace: 128) |
| `feature.dtype` | `float32` |
| `entries[].identity` | label identitas (ID personal) |
| `entries[].offset` / `count` | posisi di `embeddings.bin` |
| `createdAt`, `digest` | audit dan integritas |

**Alasan:** embedding hanya valid bila model + preprocessing identik. Tanpa manifest, mismatch menghasilkan false reject massal yang sulit dilacak.

**Konsekuensi:** Enrollment tetap di Python. Flutter hanya konsumen gallery.

## ADR-3 — Batas Dart dan native (Kotlin)

**Keputusan:** UI, state, navigasi, dan API client di Dart. Inference berat berada di native Kotlin melalui platform channel.

**Alasan:**
- Konversi `YUV_420_888` → RGB di Dart melalui MethodChannel mahal dan rawan frame drop.
- CameraX `ImageAnalysis` + runtime inference native memungkinkan zero-copy ke native buffer.
- CLAHE dan `alignCrop` pada Python berbasis OpenCV; native Kotlin memakai OpenCV Android agar semantik operasi sama.

**Konsekuensi:**
- Definisi kontrak channel harus stabil dan minimal (lihat `docs/platform_channel_contract.md`).
- Jika plugin kamera Flutter mampu menyediakan frame analyzer native tanpa channel tambahan, channel hanya untuk hasil inference.

## ADR-4 — State machine UI

**Keputusan:** Satu state machine eksplisit untuk seluruh alur kamera → presensi.

```
idle → initializing → scanning → verifying → sending → accepted | rejected
                                     ↑                        |
                                     └────── reset ───────────┘
offline / error adalah state terpisah, bukan bagian sukses.
```

**Aturan:**
- `accepted` hanya boleh terjadi dari respons API tervalidasi.
- Frame drop wajib: satu analisis berjalan pada satu waktu (*single-flight*).
- Transisi state tidak boleh memblokir preview kamera.

## ADR-5 — API dan idempotensi

**Keputusan:** Pertahankan `POST` JSON `{"idpersonal": "..."}` kecuali backend menetapkan kontrak baru.

**Wajib sebelum implementasi:**
- Auth, TLS trust, timeout, schema respons, kode error.
- Idempotency key atau proteksi duplikat di backend.
- Retry hanya untuk kegagalan transien.

**Larangan:** menonaktifkan verifikasi TLS sebagai default; menyimpan token di kode.

## ADR-6 — Privasi dan artefak sensitif

**Keputusan:**
- Model ONNX dan gallery **tidak** di-commit ke repository Android.
- `.gitignore` mencegah `assets/models/*.onnx`, `*.pkl`, `*.bin`, gallery.
- Artefak disediakan melalui kanal privat saat build/distribusi.

**Catatan risiko terbuka:** repo `jetson` saat ini masih melacak `models/encodings.pkl` dan foto di `database/test_input`/`database/test_output`. Perlu keputusan pemilik sistem untuk purge history.

## Status keputusan

| ADR | Status |
|---|---|
| ADR-1 Repository terpisah | Diputuskan |
| ADR-2 Kontrak gallery | Diputuskan format minimum |
| ADR-3 Batas Dart/native | Diputuskan arah, detail menyusul spike |
| ADR-4 State machine | Diputuskan |
| ADR-5 API | Menunggu kontrak backend |
| ADR-6 Privasi | Diputuskan arah, purge history belum |
| Runtime inference (ORT vs OpenCV DNN) | Belum diputuskan — butuh benchmark |
