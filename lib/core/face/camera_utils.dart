import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../config/app_config.dart';

/// Utilitas konversi frame kamera untuk ML Kit dan pemotongan wajah dengan rotasi yang benar.
class CameraUtils {
  CameraUtils._();

  /// Membangun [InputImage] dari [CameraImage] untuk diproses Google ML Kit.
  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required int rotationDegrees,
  }) {
    final rotation = _rotationFromDegrees(rotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final plane0 = image.planes.first;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane0.bytesPerRow,
      ),
    );
  }

  /// Derajat putaran searah jarum jam yang membuat buffer kamera tegak,
  /// dihitung dari orientasi sensor dan orientasi fisik perangkat.
  ///
  /// Hanya memakai `sensorOrientation` benar bila perangkat dipegang portrait
  /// (orientasi natural); pada landscape, wajah di buffer berputar 90°.
  static int rotationDegrees({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final device = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    if (camera.lensDirection == CameraLensDirection.front) {
      return (camera.sensorOrientation + device) % 360;
    }
    return (camera.sensorOrientation - device + 360) % 360;
  }

  static InputImageRotation _rotationFromDegrees(int orientation) {
    return switch (orientation) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }

  /// Daftar 5 landmark ML Kit dalam urutan template SFace (kiri-gambar dulu),
  /// atau `null` bila ada landmark yang tidak terdeteksi.
  static List<Point<double>>? sfaceLandmarks(Face face) {
    Point<double>? at(FaceLandmarkType type) {
      final p = face.landmarks[type]?.position;
      return p == null ? null : Point(p.x.toDouble(), p.y.toDouble());
    }

    final leftEye = at(FaceLandmarkType.leftEye);
    final rightEye = at(FaceLandmarkType.rightEye);
    final nose = at(FaceLandmarkType.noseBase);
    final leftMouth = at(FaceLandmarkType.leftMouth);
    final rightMouth = at(FaceLandmarkType.rightMouth);
    if (leftEye == null ||
        rightEye == null ||
        nose == null ||
        leftMouth == null ||
        rightMouth == null) {
      return null;
    }

    // "kiri/kanan" ML Kit mengacu ke subjek; template memakai posisi pada
    // gambar, jadi urutkan berdasarkan x.
    final eyes = [leftEye, rightEye]..sort((a, b) => a.x.compareTo(b.x));
    final mouth = [leftMouth, rightMouth]..sort((a, b) => a.x.compareTo(b.x));
    return [eyes[0], eyes[1], nose, mouth[0], mouth[1]];
  }

  /// Meluruskan wajah ke template SFace 112x112 (setara `alignCrop` OpenCV):
  /// transformasi similaritas dari template ke landmark, lalu pengambilan
  /// sampel bilinear langsung dari buffer kamera.
  static img.Image alignFaceRotated({
    required CameraImage image,
    required List<Point<double>> landmarks,
    required int rotation,
  }) {
    const size = AppConfig.faceSize;
    final tpl = AppConfig.sfaceTemplate;

    // Estimasi z (kompleks) yang meminimalkan sum |z*(a-ca) - (b-cb)|^2.
    var cax = 0.0, cay = 0.0, cbx = 0.0, cby = 0.0;
    for (var i = 0; i < 5; i++) {
      cax += tpl[i][0];
      cay += tpl[i][1];
      cbx += landmarks[i].x;
      cby += landmarks[i].y;
    }
    cax /= 5;
    cay /= 5;
    cbx /= 5;
    cby /= 5;

    var num = 0.0, numI = 0.0, den = 0.0;
    for (var i = 0; i < 5; i++) {
      final ax = tpl[i][0] - cax;
      final ay = tpl[i][1] - cay;
      final bx = landmarks[i].x - cbx;
      final by = landmarks[i].y - cby;
      num += ax * bx + ay * by;
      numI += ax * by - ay * bx;
      den += ax * ax + ay * ay;
    }
    final zr = num / den;
    final zi = numI / den;

    final aligned = img.Image(width: size, height: size);
    for (var v = 0; v < size; v++) {
      for (var u = 0; u < size; u++) {
        final px = u - cax;
        final py = v - cay;
        final ux = zr * px - zi * py + cbx;
        final uy = zr * py + zi * px + cby;
        final raw = _uprightToRaw(ux, uy, image, rotation);
        final rgb = _rgbBilinear(image, raw.dx, raw.dy);
        aligned.setPixelRgb(u, v, rgb[0], rgb[1], rgb[2]);
      }
    }
    return aligned;
  }

  /// Pemetaan balik dari koordinat gambar tegak (rotasi) ke koordinat buffer mentah.
  static Offset _uprightToRaw(
    double x,
    double y,
    CameraImage image,
    int rotation,
  ) {
    final origW = image.width;
    final origH = image.height;
    if (rotation == 90) {
      return Offset(y, origH - 1 - x);
    } else if (rotation == 270) {
      return Offset(origW - 1 - y, x);
    } else if (rotation == 180) {
      return Offset(origW - 1 - x, origH - 1 - y);
    }
    return Offset(x, y);
  }

  static List<int> _rgbBilinear(CameraImage image, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;

    final c00 = _rgbAt(image, x0, y0);
    final c10 = _rgbAt(image, x0 + 1, y0);
    final c01 = _rgbAt(image, x0, y0 + 1);
    final c11 = _rgbAt(image, x0 + 1, y0 + 1);

    return List<int>.generate(3, (k) {
      final top = c00[k] * (1 - fx) + c10[k] * fx;
      final bottom = c01[k] * (1 - fx) + c11[k] * fx;
      return (top * (1 - fy) + bottom * fy).round().clamp(0, 255);
    });
  }

  /// Konversi satu piksel buffer kamera ke RGB. Mendukung NV21 satu plane
  /// (Y diikuti VU interleaved) dan YUV420 tiga plane.
  static List<int> _rgbAt(CameraImage image, int x, int y) {
    final rawX = x.clamp(0, image.width - 1);
    final rawY = y.clamp(0, image.height - 1);

    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;

    final yIndex = rawY * yRowStride + rawX;
    final yVal = yIndex < yBytes.length ? yBytes[yIndex] : 0;

    var uVal = 0;
    var vVal = 0;

    if (image.planes.length == 1) {
      // NV21: bidang chroma ada setelah bidang Y pada buffer yang sama,
      // urutan byte V lalu U.
      final uvIndex =
          yRowStride * image.height + (rawY ~/ 2) * yRowStride + (rawX & ~1);
      if (uvIndex + 1 < yBytes.length) {
        vVal = yBytes[uvIndex] - 128;
        uVal = yBytes[uvIndex + 1] - 128;
      }
    } else if (image.planes.length >= 3) {
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final uvIndex = (rawY ~/ 2) * uvRowStride + (rawX ~/ 2) * uvPixelStride;
      if (uvIndex < uPlane.bytes.length && uvIndex < vPlane.bytes.length) {
        uVal = uPlane.bytes[uvIndex] - 128;
        vVal = vPlane.bytes[uvIndex] - 128;
      }
    }

    final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
    final g = (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
    final b = (yVal + 1.772 * uVal).round().clamp(0, 255);
    return [r, g, b];
  }
}
