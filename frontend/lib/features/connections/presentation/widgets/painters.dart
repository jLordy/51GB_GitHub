import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Role / avatar style enum
// ─────────────────────────────────────────────────────────────────────────────

enum JerseyType { center, warriors, magic, peer }

// ─────────────────────────────────────────────────────────────────────────────
//  Gradient lines connecting "Me" to each care-team node
// ─────────────────────────────────────────────────────────────────────────────

class ConnectionLinesPainter extends CustomPainter {
  final Offset from;
  final Offset? leftTo;
  final Offset? rightTo;

  const ConnectionLinesPainter({
    required this.from,
    required this.leftTo,
    required this.rightTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final targets = [
      (leftTo, const Color(0xFF7C3AED)),
      (rightTo, const Color(0xFF3B82F6)),
    ];

    for (final (to, roleColor) in targets) {
      if (to == null) continue;

      // Soft glow layer
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = roleColor.withValues(alpha: 0.12)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Gradient main line
      final shader = LinearGradient(
        colors: [
          Palette.greenColor.withValues(alpha: 0.65),
          roleColor.withValues(alpha: 0.65),
        ],
      ).createShader(Rect.fromPoints(from, to));
      canvas.drawLine(
        from,
        to,
        Paint()
          ..shader = shader
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(ConnectionLinesPainter old) =>
      old.from != from || old.leftTo != leftTo || old.rightTo != rightTo;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Gradient silhouette painter — clean role-coloured gradient + person shape
// ─────────────────────────────────────────────────────────────────────────────

class SilhouettePainter extends CustomPainter {
  final JerseyType jerseyType;

  const SilhouettePainter({required this.jerseyType});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _gradientColors,
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = shader);

    final silPaint = Paint()..color = Colors.white.withValues(alpha: 0.88);
    final cx = size.width / 2;

    // Head
    canvas.drawCircle(
      Offset(cx, size.height * 0.30),
      size.width * 0.14,
      silPaint,
    );

    // Body trapezoid
    final body = Path()
      ..moveTo(cx - size.width * 0.28, size.height * 1.05)
      ..lineTo(cx - size.width * 0.22, size.height * 0.57)
      ..quadraticBezierTo(
        cx,
        size.height * 0.46,
        cx + size.width * 0.22,
        size.height * 0.57,
      )
      ..lineTo(cx + size.width * 0.28, size.height * 1.05)
      ..close();
    canvas.drawPath(body, silPaint);
  }

  List<Color> get _gradientColors {
    switch (jerseyType) {
      case JerseyType.center:
        return [const Color(0xFF43A97A), Palette.greenColor];
      case JerseyType.warriors:
        return [const Color(0xFFA78BFA), const Color(0xFF7C3AED)];
      case JerseyType.magic:
        return [const Color(0xFF60A5FA), const Color(0xFF3B82F6)];
      case JerseyType.peer:
        return [const Color(0xFF2DD4BF), const Color(0xFF0D9488)];
    }
  }

  @override
  bool shouldRepaint(SilhouettePainter old) => old.jerseyType != jerseyType;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Multi-target gradient lines — center doctor to N patient nodes
// ─────────────────────────────────────────────────────────────────────────────

class MultiConnectionLinesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> targets;

  const MultiConnectionLinesPainter({
    required this.center,
    required this.targets,
  });

  // Cycle through distinct accent colors per patient node
  static const _palette = [
    Color(0xFF43A97A),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF6366F1),
    Color(0xFFEF4444),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < targets.length; i++) {
      final to = targets[i];
      final roleColor = _palette[i % _palette.length];

      // Soft glow layer
      canvas.drawLine(
        center,
        to,
        Paint()
          ..color = roleColor.withValues(alpha: 0.11)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Gradient main line
      final shader = LinearGradient(
        colors: [
          Palette.greenColor.withValues(alpha: 0.65),
          roleColor.withValues(alpha: 0.65),
        ],
      ).createShader(Rect.fromPoints(center, to));
      canvas.drawLine(
        center,
        to,
        Paint()
          ..shader = shader
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(MultiConnectionLinesPainter old) =>
      old.center != center || old.targets.length != targets.length;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Subtle dot-grid background pattern
// ─────────────────────────────────────────────────────────────────────────────

class GridBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 38.0;

    final dotPaint = Paint()
      ..color = const Color(0xFF359361).withValues(alpha: 0.065)
      ..style = PaintingStyle.fill;

    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(GridBgPainter old) => false;
}
