import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Panduan oval untuk wajah di atas preview kamera, sama dengan halaman
/// /rekam: oval putus-putus putih, dan area di luarnya diredupkan.
class EnrollOvalGuide extends StatelessWidget {
  const EnrollOvalGuide({super.key, required this.widthFactor});

  /// Lebar oval sebagai bagian dari lebar area. Tinggi tetap 64%.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OvalPainter(widthFactor),
        size: Size.infinite,
      ),
    );
  }
}

class _OvalPainter extends CustomPainter {
  _OvalPainter(this.widthFactor);

  final double widthFactor;

  static const double _heightFactor = 0.64;
  static const double _centerYFactor = 0.5;
  static const double _dash = 10;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * _centerYFactor),
      width: size.width * widthFactor,
      height: size.height * _heightFactor,
    );

    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final edge = Path()..addOval(oval);
    for (final metric in edge.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + _dash, metric.length)),
          dashPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.widthFactor != widthFactor;
}
