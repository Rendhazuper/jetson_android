import 'package:flutter/material.dart';

/// Bingkai penanda area wajah di atas preview kamera: sudut tebal berwarna
/// dan garis putus-putus tipis di sepanjang tepi.
class CameraFrameOverlay extends StatelessWidget {
  const CameraFrameOverlay({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _FramePainter(color), size: Size.infinite),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color);

  final Color color;

  static const double _inset = 10;
  static const double _corner = 44;
  static const double _dash = 9;
  static const double _gap = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _inset,
      _inset,
      size.width - 2 * _inset,
      size.height - 2 * _inset,
    );

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dashed = Path()..addRect(rect);
    for (final metric in dashed.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), dashPaint);
      }
    }

    final bracket = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + _corner)
        ..lineTo(l, t)
        ..lineTo(l + _corner, t)
        ..moveTo(r - _corner, t)
        ..lineTo(r, t)
        ..lineTo(r, t + _corner)
        ..moveTo(r, b - _corner)
        ..lineTo(r, b)
        ..lineTo(r - _corner, b)
        ..moveTo(l + _corner, b)
        ..lineTo(l, b)
        ..lineTo(l, b - _corner),
      bracket,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
