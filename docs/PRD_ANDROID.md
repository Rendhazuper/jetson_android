# PRD — Aplikasi Android Presensi Wajah UNEJ

- **Status:** Draft untuk validasi kebutuhan dan keputusan arsitektur
- **Versi:** 1.0
- **Basis analisis:** Source project Python yang aktif setelah pull `main`; pemeriksaan statis pada kode dan konfigurasi yang ada
- **Bukan:** Spesifikasi backend yang telah diverifikasi atau jaminan akurasi biometrik

## 1. Ringkasan Produk

Aplikasi Android untuk melakukan verifikasi wajah saat presensi, menampilkan preview kamera dan status hasil, lalu meminta layanan perkuliahan memverifikasi/mencatat identitas. Tech stack aplikasi Android yang dipilih adalah **Flutter (Dart)**. Sistem saat ini berjalan sebagai aplikasi Python berbasis Tkinter atau Flask pada Jetson/Raspberry Pi. Aplikasi Flutter adalah klien baru; model, galeri embedding, camera lifecycle, dan UI perlu port serta validasi khusus Android.

Versi Android yang direncanakan memakai alur lokal **YuNet face detection → 5-point face alignment → CLAHE preprocessing → SFace embedding → cosine-distance matching**, kemudian mengirim `idpersonal` ke layanan API yang sudah dipakai aplikasi Python. Aplikasi tidak boleh menganggap embedding lokal sebagai bukti presensi yang telah diterima server.

## 2. Temuan dari Implementasi Saat Ini

### 2.1 Perilaku yang sudah ada

1. Kamera dibuka melalui OpenCV `VideoCapture` untuk USB atau GStreamer untuk kamera CSI Jetson (`core/camera.py`). Ini bukan implementasi Android dan harus diganti dengan CameraX/Camera2.
2. Deteksi dilakukan oleh OpenCV `FaceDetectorYN` dengan model YuNet ONNX. Hasilnya berisi bounding box, landmark dan confidence (`core/detector.py`).
3. Pipeline menjalankan deteksi/pengenalan pada worker thread dengan antrean frame berukuran terbatas dan membuang frame lama (`core/pipeline.py`).
4. Wajah di-align memakai `FaceRecognizerSF.alignCrop`, lalu SFace membuat feature vector. CLAHE diterapkan pada kanal L di ruang LAB (`core/pipeline.py`, `core/recognizer.py`).
5. Matching menghitung cosine similarity dan memakai `distance = 1 - similarity`. Nilai yang ditampilkan sebagai `confidence = 1 - distance` adalah skor kemiripan yang tidak terkalibrasi sebagai probabilitas (`core/recognizer.py`).
6. `core/enroll.py` membangun galeri fitur dari foto berfolder per identitas. Ini **ekstraksi embedding**, bukan pelatihan/fine-tuning model neural network. Tiap sumber gambar menghasilkan augmentasi untuk variasi brightness, flip, rotasi ringan, dan blur; lalu alignment dan CLAHE diterapkan sebelum ekstraksi.
7. Saat match lolos, proses mengirim POST JSON `{"idpersonal": "..."}` ke `PERSON_INFO_API_URL`, secara asynchronous (`services/person_api_service.py`, `core/pipeline.py`).
8. UI desktop menampilkan status, identitas dan log harian sementara di memori (`app_tkinter.py`, `core/pipeline.py`). Cooldown attendance juga bersifat lokal/in-memory (`services/attendance_service.py`).

### 2.2 Asumsi dan batas bukti

- Skema respons API seperti `streams.nama`, `streams.nomorpegawai`, `streams.nama_unit_kerja`, dan `streams.waktu` hanya merupakan asumsi yang dipakai klien; backend/API tidak tersedia untuk diverifikasi dalam repository ini.
- HTTP non-error saat ini dianggap berhasil meskipun bentuk body tidak sesuai harapan UI. PRD Android mensyaratkan penanganan respons berdasarkan kontrak backend yang disepakati.
- Model ONNX tidak dapat dianalisis oleh REA karena format ONNX ditolak sebagai target binary yang didukung. Kehadiran, versi, input/output tensor, lisensi, dan kompatibilitas Android harus diverifikasi dengan tool ONNX/runtime yang sesuai sebelum implementasi.
- Model/encoding bersifat privat dan tidak boleh memuat atau mengirim biometrik ke GitHub. `.env`, `database/raw`, dan `models/encodings.pkl` diabaikan oleh `.gitignore` saat ini.
- Dataset foto dan encoding berisi data biometrik. Penggunaan pada mahasiswa memerlukan dasar pemrosesan, pemberitahuan/consent bila berlaku, kontrol akses, retention dan prosedur penghapusan yang disetujui pemilik sistem.

## 3. Masalah dan Tujuan

### Masalah
- Pengenalan perlu tersedia pada perangkat bergerak, dengan siklus hidup kamera dan UI Android.
- Sistem harus memberi feedback cepat tanpa memblokir preview ketika inference atau jaringan lambat.
- Variasi pencahayaan, pose, kamera, jarak, kacamata dan occlusion dapat menurunkan skor; augmentasi sintetis bukan pengganti data representatif dan tidak membuktikan robustness.
- Perangkat tidak boleh mencatat presensi berhasil hanya karena matcher lokal memilih identitas.

### Tujuan produk
- Menjalankan preview dan inference di perangkat Android yang disetujui, tanpa server Flask lokal.
- Memberi respons UI yang lancar dan status terpisah: wajah belum ada, memverifikasi, kandidat ditemukan, mengirim ke server, diterima/ditolak/gagal.
- Mengirim identitas hanya setelah kriteria lokal terpenuhi dan mencegah permintaan berulang menurut kebijakan cooldown/idempotensi yang disepakati.
- Menyediakan jalur enrollment/gallery yang kompatibel dan dapat diverifikasi terhadap model yang benar.
- Menyimpan minimum data pribadi yang diperlukan, secara aman, serta tidak menyimpan foto wajah secara default.

### Bukan tujuan MVP
- Melatih ulang/fine-tune YuNet atau SFace di telepon.
- Membuat layanan backend/API baru tanpa keputusan pemilik backend.
- Mengklaim liveness/anti-spoofing, anti-fraud, atau akurasi tertentu sebelum ada evaluasi.
- Menjalankan mode background tanpa UI/consent atau menganggap GPS sebagai bukti kehadiran, kecuali diputuskan terpisah.

## 4. Pengguna dan Skenario

### Pengguna utama
- Mahasiswa/peserta presensi yang menggunakan aplikasi pada perangkat Android yang diizinkan.
- Operator/pengelola yang mendistribusikan versi aplikasi dan memastikan konfigurasi backend/gallery.

### Skenario utama
1. Pengguna membuka aplikasi dan memberikan izin kamera.
2. Aplikasi memastikan sesi/konteks presensi tersedia (sumber sesi perlu dikonfirmasi; belum ada kontrak aplikasi Android di backend saat ini).
3. Preview kamera aktif; aplikasi mendeteksi satu atau lebih wajah dan menunjukkan batas wajah.
4. Aplikasi memilih wajah yang memenuhi kualitas minimum, melakukan alignment/preprocessing dan matching lokal.
5. Saat kandidat memenuhi kebijakan confidence, aplikasi mengirim `idpersonal` beserta metadata presensi yang disepakati ke API.
6. UI menunjukkan hasil hanya berdasarkan respons API yang valid. Jika jaringan gagal, UI menunjukkan status pending/gagal dan mengikuti kebijakan retry/idempotensi.
7. Pengguna dapat menutup sesi; kamera dan worker segera dilepas.

## 5. Kebutuhan Fungsional

### FR-1 — Akses kamera dan izin
- Gunakan Android CameraX sebagai pilihan awal; Camera2 hanya bila ada kebutuhan device-specific yang tidak tercakup CameraX.
- Minta izin kamera saat fitur digunakan, jelaskan alasan, tangani denial/permanent denial dan sediakan navigasi ke pengaturan.
- Mendukung orientasi sensor, rotasi layar, front/back camera sesuai keputusan produk, dan mirror preview dengan koordinat overlay yang konsisten.
- Hentikan dan lepaskan kamera ketika Activity/Screen berhenti atau aplikasi ditutup; tidak menjalankan capture tersembunyi di background.

### FR-2 — Face detection dan kualitas masukan
- Gunakan YuNet hanya setelah model ONNX, lisensi, tensor contract, runtime dan performa pada Android telah diverifikasi.
- Tampilkan bounding box yang mengikuti rotasi/cropping preview.
- Abaikan frame terlalu blur, terlalu gelap/terang, terlalu kecil, miring ekstrem atau berisi lebih dari jumlah wajah yang diizinkan; tampilkan petunjuk perbaikan.
- Definisikan kebijakan multi-face: MVP memproses tepat satu wajah pada area presensi; jika lebih dari satu, minta pengguna lain keluar dari frame.

### FR-3 — Alignment, embedding dan matching
- Terapkan preprocessing yang sama pada enrollment dan inference: versi model, YuNet landmarks, `alignCrop`, warna/format kanal, CLAHE dan normalisasi input harus identik.
- Bandingkan embedding SFace dengan galeri lokal yang berisi label identitas dan metadata versi.
- Threshold dan kebijakan vote harus dapat dikonfigurasi per versi dan ditentukan melalui evaluasi FAR/FRR; jangan menggunakan confidence sebagai probabilitas.
- Kandidat lokal adalah hasil sementara. Catat hasil presensi sebagai berhasil hanya bila API membalas sukses sesuai schema/aturan backend.

### FR-4 — Attendance API
- API contract wajib disepakati: URL, method, request schema, response schema, autentikasi, TLS trust, timeout, error codes, idempotency, retry policy dan environment.
- Minimal request mempertahankan kompatibilitas yang ada (`POST` JSON `idpersonal`) kecuali backend mensyaratkan perubahan.
- TLS certificate verification aktif secara default; jangan mengirim credential/token di log.
- Retry hanya untuk error transien yang aman; gunakan idempotency key atau backend duplicate protection agar retry tidak membuat presensi ganda.
- Jangan mengirim foto, video atau embedding ke API kecuali ada kebutuhan, legal approval dan protokol yang eksplisit.

### FR-5 — UI dan feedback
- Menampilkan preview kamera, panduan posisi wajah, status sistem/jaringan, identitas yang dikembalikan API, timestamp dan hasil presensi.
- Status pengenalan, pengiriman, accepted/rejected dan offline harus berbeda jelas.
- UI tidak boleh freeze saat inference atau request API berlangsung.
- Log tampil hanya untuk sesi berjalan atau sesuai retention yang disetujui; sediakan penghapusan/clear bila disyaratkan.

### FR-6 — Enrollment dan distribusi gallery
- Tentukan authoritative source untuk foto dan enrollment. Saat ini folder `database/raw/<id>/` hanya ada pada device/repository lokal dan diabaikan oleh Git.
- Buat proses ekspor gallery versioned dari tool enrollment, bukan memasukkan dataset foto/embedding pribadi ke repository publik.
- Gallery manifest mencatat model ID/version/hash, preprocessing version, feature dimensions, jumlah identitas/fitur, waktu pembuatan dan digest.
- Android harus menolak gallery yang tidak kompatibel atau korup; update gallery harus atomik dan dapat rollback.
- Tentukan apakah gallery diunduh dari backend terautentikasi atau didistribusikan melalui kanal privat/MDM; jangan bundel seluruh gallery ke APK publik tanpa threat/privacy review.

## 6. Kebutuhan Non-Fungsional dan Kriteria Penerimaan

Target berikut adalah target uji, bukan klaim hasil yang sudah terbukti. Tetapkan perangkat baseline (model, RAM, Android, camera) sebelum acceptance.

- **Respons UI:** preview tetap responsif saat inference dan jaringan lambat; tidak ada pemrosesan CV di main/UI thread.
- **Latensi lokal:** ukur p50/p95 dari frame masuk sampai kandidat/unknown pada perangkat baseline. Target awal: p95 ≤ 250 ms; revisi setelah benchmark nyata.
- **Stabilitas kamera:** minimal 30 menit operasi berkelanjutan tanpa crash, kebocoran kamera, atau antrean frame yang terus menua.
- **Jaringan:** timeout dan kegagalan API tidak membekukan preview; hasil server tetap otoritatif; retry tidak menduplikasi presensi.
- **Akurasi:** acceptance memakai dataset validasi terpisah per identitas dan kondisi, mengukur False Accept Rate (FAR), False Reject Rate (FRR), precision/recall per kondisi, serta confidence interval. Ambang numerik harus disetujui pemilik sistem/security sebelum rollout.
- **Variasi kondisi:** uji dengan/tanpa kacamata, pencahayaan terang/redup, pose frontal/terbatas, jarak dan device kamera berbeda. Augmentasi tidak boleh dianggap sebagai data uji independen.
- **Privasi:** tidak ada foto/video/embedding pada log crash atau analytics; data biometrik terenkripsi saat transit dan tersimpan; data uji dianonimkan dan akses dibatasi.
- **Kompatibilitas:** tetapkan minimum Android API level dan daftar device; verifikasi dukungan kamera, runtime ONNX dan model pada setiap baseline.

## 7. Arsitektur Flutter Android yang Diusulkan

### Tech stack yang dipilih
- **Flutter + Dart** untuk aplikasi, UI, navigasi, permission flow, state presentation dan integrasi API.
- **CameraX melalui plugin Flutter yang terpelihara** untuk preview/camera lifecycle Android. Camera plugin yang dipilih harus mendukung `ImageAnalysis` atau alur frame yang efisien, orientasi dan backpressure; validasi plugin sebelum dikunci.
- **Native Android inference bridge** (Kotlin via Flutter platform channel/FFI bila diperlukan) untuk menghindari copy/convert frame berulang dan menjalankan model ONNX/OpenCV secara efisien. Flutter tetap pemilik UI/state; native layer menjadi adapter inference/camera bila plugin Dart tidak menyediakan kontrol yang diperlukan.
- **ONNX Runtime Mobile atau OpenCV Android DNN** sebagai pilihan runtime model. Keputusan final ditentukan oleh spike kompatibilitas dan benchmark pada Raspberry Pi bukan target Android; benchmark wajib pada Android baseline nyata.
- **Dart HTTP client/API repository** untuk request presensi, TLS, parsing respons, timeout, retry dan idempotency.
- **Secure storage**: Android Keystore-backed encryption untuk gallery/config sensitif; jangan menyimpan secret hardcoded dalam app bundle.

```text
Flutter UI (Dart) + app state
          │
          ├── Flutter camera plugin / CameraX preview
          │       └── ImageAnalysis frames + rotation metadata
          │
          └── Native inference bridge (Kotlin; only if needed)
                    │ YUV frame; single-flight, drop stale frames
                    ├── YuNet ONNX detection + landmarks
                    ├── quality gate + single-face policy
                    ├── SFace alignCrop + parity-verified CLAHE/preprocessing
                    └── embedding ↔ versioned local gallery (cosine distance)
                              │ candidate only
                              ▼
                    Dart Attendance Repository / API client
                    HTTPS + auth + timeout + idempotency + bounded retry
                              │ validated server result
                              ▼
                    Flutter UI state (preview never blocked by API)
```

**Catatan implementasi:** Jangan menjalankan inferensi sinkron pada isolate/UI thread Flutter. Jika frame diteruskan ke Dart, ukur biaya konversi YUV→RGB/BGR dan salinan memori; preferensi awal adalah preview melalui Flutter camera plugin dan inferensi melalui analyzer/native bridge dengan frame drop/backpressure. Pastikan `alignCrop`, urutan landmark, format warna, CLAHE, dan normalisasi benar-benar parity dengan Python.

**Pilihan runtime**: lakukan spike pembuktian pada Android dengan ONNX Runtime Mobile atau runtime lain yang mendukung operator dan model terpilih. Alternatif yang harus dibandingkan adalah OpenCV Android DNN bila versi, operasi, lisensi dan performanya sesuai. Jangan menyimpulkan model dapat berjalan di Android hanya karena OpenCV Python pada host bisa memuatnya.

## 8. Keamanan, Privasi, dan Tata Kelola Biometrik

- Dapatkan persetujuan pemilik sistem dan penilaian hukum/privasi sebelum produksi, termasuk dasar pemrosesan biometrik, pemberitahuan, hak opt-out bila berlaku, retention, penghapusan, dan pengelolaan insiden.
- Minimalkan data: inference dan pencocokan lokal; API menerima ID dan metadata minimum; foto mentah tidak disimpan pada perangkat kecuali diperlukan eksplisit.
- Lindungi gallery/embedding dengan Android Keystore-backed encryption, akses aplikasi terbatas, integrity/version checks dan secure update.
- Gunakan TLS dengan validasi sertifikat; kredensial API disimpan aman, tidak hardcoded dalam APK atau log.
- Tentukan threat model untuk perangkat hilang/rooted, APK tampering, replay/foto spoofing dan penyalahgunaan gallery. Liveness/anti-spoofing tetap **belum ada** dan harus menjadi keputusan/fitur tersendiri.
- Retensi log lokal default minimum; jangan log raw face ID jika tidak dibutuhkan untuk troubleshooting.

## 9. Migrasi dan Tahapan Kerja

### Tahap 0 — Konfirmasi dan audit kontrak
- Konfirmasi Raspberry Pi/Jetson tetap backend inference atau aplikasi Android melakukan semua inference.
- Dapatkan API spec/backend owner, model/license provenance, target Android devices, alur enrollment, auth, attendance policy dan privacy approvals.
- Audit source of truth untuk identitas dan sinkronisasi data.

### Tahap 1 — Spike teknis Flutter (tanpa produksi)
- Buat app Flutter minimal dengan preview kamera Android dan bridge inference YuNet/SFace pada satu perangkat baseline.
- Evaluasi Flutter camera plugin/CameraX analyzer dan tentukan apakah frame analysis dapat dilakukan dengan baik melalui plugin atau perlu Kotlin platform channel/native bridge.
- Verifikasi input/output ONNX, warna YUV/RGB/BGR, landmark ordering, alignCrop equivalence, CLAHE parity dan hasil embedding terhadap Python fixture.
- Benchmark cold start, p50/p95 latency, memory, battery/thermal, biaya frame conversion dan frame drop.
- Putuskan ONNX Runtime Mobile vs OpenCV Android, serta Dart vs native inference boundary, berdasarkan hasil bukan asumsi.

### Tahap 2 — API client dan state machine
- Implementasi network contract, auth/TLS, response validation, idempotency, timeout/retry dan UI states.
- Uji server success, rejection, malformed response, offline, timeout, retry dan duplicate requests.

### Tahap 3 — Gallery/enrollment
- Definisikan format gallery portable dan versioning.
- Buat export/import terotentikasi dan atomik. Validasi kompatibilitas feature/preprocessing.
- Jalankan akurasi per kondisi pada dataset terpisah dari enrollment; calibrate threshold berdasarkan FAR/FRR.

### Tahap 4 — Pilot dan rilis
- Pilot terbatas dengan persetujuan, monitoring yang minim data biometrik, support process dan rollback.
- Rilis melalui kanal privat/managed distribution hingga keamanan dan legal review selesai.

## 10. Rencana Pengujian

1. **Unit:** parsing config/gallery, cosine distance, threshold decision, quality gate, state transitions, idempotency generation, response parsing.
2. **Golden-image integration:** input gambar yang telah disetujui → detection box/landmarks → aligned crop → embedding; bandingkan parity terhadap Python dengan toleransi numerik yang ditetapkan.
3. **Recognition validation:** genuine/impostor pair set yang dipisahkan per individu/sesi; hindari kebocoran foto augmentasi yang sama ke train dan test.
4. **Camera/device:** orientasi, front/back camera, permission denied/revoked, lifecycle/background, thermal throttling, low light, blur, multiple faces.
5. **Network:** success, HTTP rejection, empty/malformed JSON, timeout, offline, TLS failure, retry, duplicate/idempotency behavior.
6. **Privacy/security:** pemeriksaan log, APK strings/secrets, local storage encryption, gallery replacement/tampering, data deletion.
7. **Regression:** seluruh hasil unknown/rejected tidak boleh membuat request attendance; hanya status server terverifikasi boleh tampil sebagai presensi berhasil.

## 11. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Model/ONNX tidak kompatibel atau lambat pada Android | Fitur utama gagal atau preview tersendat | Spike runtime dan benchmark di device nyata sebelum port penuh |
| Augmentasi sintetis memberi rasa aman palsu | False reject/accept tetap terjadi pada kondisi nyata | Kumpulkan validation set realistis; uji FAR/FRR; jangan menyebut augmentasi sebagai training model |
| Gallery usang/tidak cocok dengan model | Semua/ sebagian pengguna gagal dikenali | Version/hash manifest, compatibility check, atomik update dan rollback |
| API contract tidak terdokumentasi | Status attendance salah/duplikat | Backend contract dan sandbox sebelum implementasi |
| Salah match biometrik | Presensi atas nama orang lain | Threshold berbasis evaluasi, server-side validation, multi-frame evidence yang terbatas, audit dan fallback manual |
| Kebocoran data biometrik | Dampak privasi berat | Minimisasi, enkripsi, akses terbatas, retention/penghapusan dan review hukum |
| Spoof dengan foto/video | Presensi palsu | Nyatakan belum didukung; threat assessment dan liveness sebagai pekerjaan tersendiri |

## 12. Keputusan yang Harus Dikonfirmasi

**Sudah diputuskan:** aplikasi Android menggunakan Flutter/Dart untuk UI, navigasi dan API client. Integrasi kamera dan inference dapat memakai plugin Flutter atau native Kotlin bridge berdasarkan hasil spike.

1. Apakah Android melakukan inference lokal penuh atau mengirim frame ke server? Rekomendasi: inference lokal; jangan upload frame secara default.
2. Siapa pemilik dan penyedia gallery, serta bagaimana gallery diotorisasi dan diperbarui?
3. Apakah perangkat dimiliki mahasiswa atau disediakan kampus? Apakah aplikasi dikelola MDM?
4. Apa minimum Android API dan daftar model perangkat yang wajib didukung?
5. Endpoint/auth/schema respons resmi, kebijakan TLS, duplicate prevention dan attendance session/context apa yang dibutuhkan?
6. Berapa FAR/FRR yang dapat diterima, dan siapa yang menyetujui evaluasi biometrik?
7. Bagaimana consent, alternatif presensi manual, retention dan deletion ditangani?
8. Apakah perlu liveness/anti-spoofing pada MVP?
9. Runtime inference final (ONNX Runtime Mobile atau OpenCV Android DNN), plugin kamera dan batas Dart/native apa yang dipilih setelah benchmark?

## Lampiran A — Referensi Source yang Dianalisis

- `core/camera.py`: capture USB/CSI, mirror dan frame lifecycle.
- `core/detector.py`: YuNet ONNX dan landmark output.
- `core/recognizer.py`: SFace, CLAHE, cosine distance, thresholds dan embedding gallery.
- `core/pipeline.py`: worker threads, frame queue, recognition throttle, API dispatch, state, events dan cooldown.
- `core/enroll.py`, `enroll_runner.py`: ekstraksi embeddings/enrollment dan augmentasi; bukan neural-network training.
- `services/person_api_service.py`: POST `idpersonal`, TLS/proxy config dan response/error handling.
- `services/attendance_service.py`: cooldown per ID dalam memori.
- `app_tkinter.py`, `app.py`: UI desktop dan web.
- `utils/config.py`: model/gallery path, thresholds, camera dan API config.
- `tests/`: suite yang ada perlu diperbaiki/ditambah; beberapa tes tampak memerlukan kamera/live services.
- `PRD.md` serta laporan teknis lama: kontennya tidak sinkron dengan kode aktif (masih menyebut HaarCascade/dlib/SQLite); jangan jadikan spesifikasi arsitektur aktif tanpa pembaruan.

**Catatan REA:** Percobaan membuka `models/sface/face_recognition_sface.onnx` melalui REA gagal dengan `unsupported binary format`. Dengan demikian, model graph, tensor contract dan lisensinya belum dianalisis oleh REA dan wajib diverifikasi dengan tool yang mendukung ONNX.
