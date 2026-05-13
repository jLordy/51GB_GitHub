import 'package:flutter/material.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';

/// Sparkline chart of the patient's recent health log trend.
///
/// [_data] is normalised 0.0–1.0 (higher = better self-reported health).
/// In production, derive from journal entry mood/vitals scores via a
/// JournalProvider and normalise server-side before passing here.
class HealthSummaryPreview extends StatelessWidget {
  const HealthSummaryPreview({super.key});

  static const List<double> _data = [
    0.40, 0.58, 0.50, 0.72, 0.65, 0.80, 0.70, 0.83, 0.74, 0.90,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header row ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Health Trend',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Last 10 days',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Sparkline ────────────────────────────────────────────────────
          SizedBox(
            height: 62,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: _data,
                lineColor: Palette.greenColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Summary stat badges ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _StatBadge(label: 'Mood', value: '7.2/10', cs: cs, tt: tt),
              _Divider(),
              _StatBadge(label: 'BP Avg', value: '118/76', cs: cs, tt: tt),
              _Divider(),
              _StatBadge(label: 'Log Days', value: '12', cs: cs, tt: tt),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat badge ───────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Palette.greenColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

// ── Sparkline painter ────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.data, required this.lineColor});
  final List<double> data;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final step = size.width / (data.length - 1);

    // Gradient fill under the line
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - data[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        // Bezier smoothing between points
        final prevX = (i - 1) * step;
        final prevY = size.height - data[i - 1] * size.height;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    fillPath
      ..lineTo((data.length - 1) * step, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // End-point dot only (avoids visual clutter on dense data)
    final lastX = (data.length - 1) * step;
    final lastY = size.height - data.last * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.lineColor != lineColor;
}
