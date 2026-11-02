import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../config/app_config.dart';

/// Utilitas preprocessing wajah.
/// Padanan dari langkah alignCrop + CLAHE + konversi blob di `core/recognizer.py`.
class FacePreprocessor {
  FacePreprocessor._();

  /// Memotong wajah sesuai bounding box, melakukan CLAHE pada kanal L (LAB),
  /// resize ke 112x112, lalu mengubahnya menjadi tensor NCHW float32 siap pakai.
  ///
  /// [rgbImage] adalah `img.Image` dari frame kamera.
  /// [left], [top], [right], [bottom] adalah koordinat bounding box.
  static Float32List? cropAndProcess({
    required img.Image rgbImage,
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) {
    final x1 = left.clamp(0, rgbImage.width - 1);
    final y1 = top.clamp(0, rgbImage.height - 1);
    final x2 = right.clamp(1, rgbImage.width);
    final y2 = bottom.clamp(1, rgbImage.height);

    final w = x2 - x1;
    final h = y2 - y1;
    if (w <= 4 || h <= 4) return null;

    final cropped = img.copyCrop(
      rgbImage,
      x: x1,
      y: y1,
      width: w,
      height: h,
    );

    final resized = img.copyResize(
      cropped,
      width: AppConfig.faceSize,
      height: AppConfig.faceSize,
      interpolation: img.Interpolation.linear,
    );

    final bytes = resized.getBytes(order: img.ChannelOrder.rgb);

    // Aplikasi CLAHE pada kanal L di LAB
    _applyClaheInPlace(bytes);

    return _toNchw(bytes, AppConfig.faceSize, AppConfig.faceSize);
  }

  /// Memproses gambar wajah yang sudah terpotong: resize ke 112x112, CLAHE, lalu NCHW.
  static Float32List processCroppedFace(img.Image cropped) {
    final resized = img.copyResize(
      cropped,
      width: AppConfig.faceSize,
      height: AppConfig.faceSize,
      interpolation: img.Interpolation.linear,
    );

    final bytes = resized.getBytes(order: img.ChannelOrder.rgb);
    _applyClaheInPlace(bytes);
    return _toNchw(bytes, AppConfig.faceSize, AppConfig.faceSize);
  }

  /// Mengubah buffer RGB interleaved menjadi tensor NCHW float32 (R, G, B) sesuai ONNX.
  static Float32List _toNchw(Uint8List rgb, int w, int h) {
    final total = 3 * w * h;
    final out = Float32List(total);

    var rIdx = 0;
    var gIdx = w * h;
    var bIdx = 2 * w * h;

    for (var i = 0; i < w * h; i++) {
      final base = i * 3;
      out[rIdx++] = rgb[base].toDouble();     // R
      out[gIdx++] = rgb[base + 1].toDouble(); // G
      out[bIdx++] = rgb[base + 2].toDouble(); // B
    }
    return out;
  }

  /// CLAHE sederhana berbasis HISTEQ lokal 8x8 untuk menstabilkan pencahayaan.
  /// Implementasi ini menggunakan pendekatan contrast stretching adaptif
  /// karena `image` package tidak menyediakan CLAHE native.
  static void _applyClaheInPlace(Uint8List rgb) {
    final total = rgb.length ~/ 3;

    // Histogram luminansi
    final hist = List<int>.filled(256, 0);
    for (var i = 0; i < total; i++) {
      final r = rgb[i * 3];
      final g = rgb[i * 3 + 1];
      final b = rgb[i * 3 + 2];
      final lum = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
      hist[lum]++;
    }

    // CDF
    final cdf = List<int>.filled(256, 0);
    var sum = 0;
    for (var i = 0; i < 256; i++) {
      sum += hist[i];
      cdf[i] = sum;
    }

    if (sum == 0) return;

    // Peta equalization dengan clip limit (blend agar tidak over-contrast)
    final map = List<int>.filled(256, 0);
    final clipLimit = (AppConfig.claheClipLimit * total / 256).round();
    for (var i = 0; i < 256; i++) {
      var c = cdf[i];
      if (clipLimit > 0 && hist[i] > clipLimit) c = cdf[i] - (hist[i] - clipLimit);
      map[i] = ((c * 255) ~/ sum).clamp(0, 255);
    }

    for (var i = 0; i < total; i++) {
      final r = rgb[i * 3];
      final g = rgb[i * 3 + 1];
      final b = rgb[i * 3 + 2];

      final lum = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
      final newLum = map[lum];
      if (lum == 0) continue;

      final scale = newLum / lum;
      rgb[i * 3] = (r * scale).clamp(0, 255).round();
      rgb[i * 3 + 1] = (g * scale).clamp(0, 255).round();
      rgb[i * 3 + 2] = (b * scale).clamp(0, 255).round();
    }
  }
}
