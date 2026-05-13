import 'dart:math' as math;
import 'package:flutter/material.dart';

enum RippleMode { outward, pulse }

class RipplePainter extends CustomPainter {
  final double animValue;
  final Color color;
  final int ringCount;
  final RippleMode mode;
  final double centerRadius;
  final double maxRadius;

  const RipplePainter({
    required this.animValue,
    required this.color,
    this.ringCount = 3,
    this.mode = RippleMode.outward,
    this.centerRadius = 50.0,
    this.maxRadius = 110.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < ringCount; i++) {
      double phase;
      if (mode == RippleMode.outward) {
        phase = (animValue + i / ringCount) % 1.0;
      } else {
        // pulse: rings breathe in sync with slight stagger
        phase = (animValue * 0.8 + i * 0.1).clamp(0.0, 1.0);
        phase = math.sin(phase * math.pi);
      }

      final radius = centerRadius + (maxRadius - centerRadius) * phase;
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.65;
      final strokeWidth = (1.0 - phase * 0.6).clamp(0.5, 2.0);

      paint
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.color != color ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.mode != mode;
  }
}
