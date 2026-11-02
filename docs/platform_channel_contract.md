# Kontrak Platform Channel — Kamera & Inference

Status: **draft**, menunggu spike. Nama channel dan payload belum final; dokumen ini mengunci bentuk minimum agar Dart dan Kotlin tidak menyimpang.

## Channel

| Channel | Arah | Tujuan |
|---|---|---|
| `id.ac.unej.face_presensi/analyzer` | Kotlin → Dart | Hasil analisis frame (kandidat/unknown/error) |
| `id.ac.unej.face_presensi/control` | Dart → Kotlin | Mulai/hentikan analyzer, muat gallery, set threshold |

## Payload `control`

```json
{ "action": "start", "cameraLens": "front|back", "minFaceRatio": 0.2 }
{ "action": "stop" }
{ "action": "loadGallery", "galleryPath": "...", "expectedSha256": "..." }
{ "action": "setThresholds", "strongDistance": 0.25, "maxDistance": 0.40 }
```

## Payload `analyzer` (event)

```json
{
  "type": "candidate",
  "identity": "00174BE5-...",
  "distance": 0.312,
  "confidenceScore": 0.688,
  "trackId": 7,
  "frameTimestampMs": 123456,
  "latencyMs": 48
}
```

```json
{ "type": "unknown", "bestDistance": 0.61, "reason": "above_threshold" }
{ "type": "no_face" }
{ "type": "quality_reject", "reason": "too_dark|too_blurred|too_small|multi_face" }
{ "type": "error", "code": "MODEL_LOAD_FAILED", "message": "..." }
```

## Aturan

1. **Single-flight:** Kotlin wajib membuang frame bila analisis sebelumnya belum selesai.
2. **Tidak ada blocking:** channel hanya mengirim hasil; keputusan presensi ada di Dart.
3. **Confidence bukan probabilitas:** `confidenceScore` = `1 - distance`, hanya untuk tampilan.
4. **Koordinat:** kotak wajah dikirim ternormalisasi `0..1` terhadap frame asli, agar Flutter dapat menyesuaikan orientasi/crop preview.
5. **Privasi:** channel tidak mengirim gambar, hanya metadata. Bukti foto tidak disimpan default.
6. **Versi:** setiap event menyertakan `analyzerVersion` dan `preprocessingVersion`.

## Error code minimum

`MODEL_LOAD_FAILED`, `GALLERY_INCOMPATIBLE`, `CAMERA_UNAVAILABLE`, `PERMISSION_DENIED`, `INFERENCE_FAILED`, `OUT_OF_MEMORY`.
