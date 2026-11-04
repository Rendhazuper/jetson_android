import 'dart:math';
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
    _applyClaheInPlace(bytes, AppConfig.faceSize, AppConfig.faceSize);

    return _toNchw(bytes, AppConfig.faceSize, AppConfig.faceSize);
  }

  /// Memproses gambar wajah yang sudah terpotong: resize ke 112x112, CLAHE, lalu NCHW.
  static Float32List processCroppedFace(img.Image cropped) {
    final resized =
        cropped.width == AppConfig.faceSize &&
            cropped.height == AppConfig.faceSize
        ? cropped
        : img.copyResize(
            cropped,
            width: AppConfig.faceSize,
            height: AppConfig.faceSize,
            interpolation: img.Interpolation.linear,
          );

    // Salin agar CLAHE in-place tidak mengubah gambar milik pemanggil.
    final bytes = Uint8List.fromList(
      resized.getBytes(order: img.ChannelOrder.rgb),
    );
    _applyClaheInPlace(bytes, AppConfig.faceSize, AppConfig.faceSize);
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

  /// CLAHE pada kanal L (LAB) — port dari `cv2.createCLAHE(clipLimit, tileGrid)`
  /// yang dipakai saat enrollment gallery. Konversi LAB memakai rumus 8-bit
  /// OpenCV (D65, sRGB); histogram per tile di-clip, lalu LUT diinterpolasi
  /// bilinear antar tile.
  static void _applyClaheInPlace(Uint8List rgb, int w, int h) {
    final n = w * h;

    // RGB -> LAB (8-bit)
    final lCh = Uint8List(n);
    final aCh = Uint8List(n);
    final bCh = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final r = _srgbToLinear[rgb[i * 3]];
      final g = _srgbToLinear[rgb[i * 3 + 1]];
      final b = _srgbToLinear[rgb[i * 3 + 2]];

      final x = (0.412453 * r + 0.357580 * g + 0.180423 * b) / 0.950456;
      final y = 0.212671 * r + 0.715160 * g + 0.072169 * b;
      final z = (0.019334 * r + 0.119193 * g + 0.950227 * b) / 1.088754;

      final fx = _labF(x);
      final fy = _labF(y);
      final fz = _labF(z);

      final l = y > 0.008856 ? 116.0 * fy - 16.0 : 903.3 * y;
      lCh[i] = (l * 255.0 / 100.0).round().clamp(0, 255);
      aCh[i] = (500.0 * (fx - fy) + 128.0).round().clamp(0, 255);
      bCh[i] = (200.0 * (fy - fz) + 128.0).round().clamp(0, 255);
    }

    _claheOnL(lCh, w, h);

    // LAB -> RGB (8-bit)
    for (var i = 0; i < n; i++) {
      final l = lCh[i] * 100.0 / 255.0;
      final a = aCh[i] - 128.0;
      final b = bCh[i] - 128.0;

      final fy = (l + 16.0) / 116.0;
      final fx = fy + a / 500.0;
      final fz = fy - b / 200.0;

      final x = _labFInv(fx) * 0.950456;
      final y = _labFInv(fy);
      final z = _labFInv(fz) * 1.088754;

      final rl = 3.240479 * x - 1.537150 * y - 0.498535 * z;
      final gl = -0.969256 * x + 1.875991 * y + 0.041556 * z;
      final bl = 0.055648 * x - 0.204043 * y + 1.057311 * z;

      rgb[i * 3] = _linearToSrgb(rl);
      rgb[i * 3 + 1] = _linearToSrgb(gl);
      rgb[i * 3 + 2] = _linearToSrgb(bl);
    }
  }

  static const int _claheTilesX = AppConfig.claheTileGridX;
  static const int _claheTilesY = AppConfig.claheTileGridY;

  static final Float64List _srgbToLinear = Float64List.fromList(
    List<double>.generate(256, (i) {
      final v = i / 255.0;
      return v <= 0.04045
          ? v / 12.92
          : pow((v + 0.055) / 1.055, 2.4).toDouble();
    }),
  );

  static double _labF(double t) =>
      t > 0.008856 ? pow(t, 1.0 / 3.0).toDouble() : 7.787 * t + 16.0 / 116.0;

  static double _labFInv(double f) =>
      f > 0.206893 ? f * f * f : (f - 16.0 / 116.0) / 7.787;

  static int _linearToSrgb(double v) {
    final c = v.clamp(0.0, 1.0);
    final s = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    return (s * 255.0).round().clamp(0, 255);
  }

  /// CLAHE OpenCV pada satu kanal 8-bit; [w] dan [h] harus habis dibagi
  /// jumlah tile (112 dibagi 8 tile = 14 piksel).
  static void _claheOnL(Uint8List l, int w, int h) {
    const histSize = 256;
    final tileW = w ~/ _claheTilesX;
    final tileH = h ~/ _claheTilesY;
    final tileTotal = tileW * tileH;

    var clipLimit = (AppConfig.claheClipLimit * tileTotal / histSize).floor();
    if (clipLimit < 1) clipLimit = 1;

    // LUT per tile
    final luts = List<Uint8List>.generate(
      _claheTilesX * _claheTilesY,
      (_) => Uint8List(histSize),
    );
    final lutScale = (histSize - 1) / tileTotal;

    for (var ty = 0; ty < _claheTilesY; ty++) {
      for (var tx = 0; tx < _claheTilesX; tx++) {
        final hist = List<int>.filled(histSize, 0);
        for (var y = ty * tileH; y < (ty + 1) * tileH; y++) {
          for (var x = tx * tileW; x < (tx + 1) * tileW; x++) {
            hist[l[y * w + x]]++;
          }
        }

        var clipped = 0;
        for (var i = 0; i < histSize; i++) {
          if (hist[i] > clipLimit) {
            clipped += hist[i] - clipLimit;
            hist[i] = clipLimit;
          }
        }

        final redistBatch = clipped ~/ histSize;
        var residual = clipped - redistBatch * histSize;
        for (var i = 0; i < histSize; i++) {
          hist[i] += redistBatch;
        }
        if (residual != 0) {
          final residualStep = max(histSize ~/ residual, 1);
          for (var i = 0; i < histSize && residual > 0; i += residualStep) {
            hist[i]++;
            residual--;
          }
        }

        final lut = luts[ty * _claheTilesX + tx];
        var sum = 0;
        for (var i = 0; i < histSize; i++) {
          sum += hist[i];
          lut[i] = (sum * lutScale).round().clamp(0, 255);
        }
      }
    }

    // Interpolasi bilinear antar tile
    final out = Uint8List(w * h);
    final invTw = 1.0 / tileW;
    final invTh = 1.0 / tileH;
    for (var y = 0; y < h; y++) {
      final tyf = y * invTh - 0.5;
      var ty1 = tyf.floor();
      var ty2 = ty1 + 1;
      final ya = tyf - ty1;
      final ya1 = 1.0 - ya;
      ty1 = max(ty1, 0);
      ty2 = min(ty2, _claheTilesY - 1);

      for (var x = 0; x < w; x++) {
        final txf = x * invTw - 0.5;
        var tx1 = txf.floor();
        var tx2 = tx1 + 1;
        final xa = txf - tx1;
        final xa1 = 1.0 - xa;
        tx1 = max(tx1, 0);
        tx2 = min(tx2, _claheTilesX - 1);

        final v = l[y * w + x];
        final res =
            (luts[ty1 * _claheTilesX + tx1][v] * xa1 +
                    luts[ty1 * _claheTilesX + tx2][v] * xa) *
                ya1 +
            (luts[ty2 * _claheTilesX + tx1][v] * xa1 +
                    luts[ty2 * _claheTilesX + tx2][v] * xa) *
                ya;
        out[y * w + x] = res.round().clamp(0, 255);
      }
    }
    l.setAll(0, out);
  }
}
