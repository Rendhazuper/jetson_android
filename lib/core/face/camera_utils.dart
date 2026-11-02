import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Utilitas konversi frame kamera untuk ML Kit dan pemotongan wajah dengan rotasi yang benar.
class CameraUtils {
  CameraUtils._();

  /// Membangun [InputImage] dari [CameraImage] untuk diproses Google ML Kit.
  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    final rotation = _rotationFromSensor(camera.sensorOrientation);
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

  static InputImageRotation _rotationFromSensor(int orientation) {
    return switch (orientation) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }

  /// Memotong area wajah dari frame kamera dengan memperhitungkan rotasi sensor.
  /// Bounding box dari ML Kit berada di sistem koordinat rotasi (sesuai tampilan mata pengguna).
  static img.Image cropFaceRotated({
    required CameraImage image,
    required Rect boundingBox,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    final targetW = boundingBox.width.toInt().clamp(10, 1000);
    final targetH = boundingBox.height.toInt().clamp(10, 1000);
    final cropped = img.Image(width: targetW, height: targetH);

    final yPlane = image.planes[0];
    final uPlane = image.planes.length > 1 ? image.planes[1] : null;
    final vPlane = image.planes.length > 2 ? image.planes[2] : null;

    final yBytes = yPlane.bytes;
    final uBytes = uPlane?.bytes;
    final vBytes = vPlane?.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane?.bytesPerRow ?? yRowStride;
    final uvPixelStride = uPlane?.bytesPerPixel ?? 1;

    final origW = image.width;
    final origH = image.height;

    for (var dy = 0; dy < targetH; dy++) {
      for (var dx = 0; dx < targetW; dx++) {
        final rotX = boundingBox.left.toInt() + dx;
        final rotY = boundingBox.top.toInt() + dy;

        int rawX;
        int rawY;

        // Pemetaan balik dari koordinat layar (rotasi) ke koordinat buffer mentah
        if (sensorOrientation == 90) {
          rawX = rotY;
          rawY = origH - 1 - rotX;
        } else if (sensorOrientation == 270) {
          rawX = origW - 1 - rotY;
          rawY = rotX;
        } else if (sensorOrientation == 180) {
          rawX = origW - 1 - rotX;
          rawY = origH - 1 - rotY;
        } else {
          rawX = rotX;
          rawY = rotY;
        }

        rawX = rawX.clamp(0, origW - 1);
        rawY = rawY.clamp(0, origH - 1);

        final yIndex = rawY * yRowStride + rawX;
        int yVal = 0;
        int uVal = 0;
        int vVal = 0;

        if (yIndex < yBytes.length) {
          yVal = yBytes[yIndex];
        }

        if (uBytes != null && vBytes != null) {
          final uvIndex = (rawY ~/ 2) * uvRowStride + (rawX ~/ 2) * uvPixelStride;
          if (uvIndex < uBytes.length && uvIndex < vBytes.length) {
            uVal = uBytes[uvIndex] - 128;
            vVal = vBytes[uvIndex] - 128;
          }
        }

        final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
        final g = (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
        final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

        cropped.setPixelRgb(dx, dy, r, g, b);
      }
    }

    return cropped;
  }
}
