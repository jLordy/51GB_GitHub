import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/theme/palette.dart';

class HealthSummaryPreview extends ConsumerWidget {
  const HealthSummaryPreview({super.key});

  // ── Score derivation ─────────────────────────────────────────────────────────

  /// Normalises a single entry to 0.0–1.0 from universal daily questions.
  /// overall_condition is the primary signal; energy_level is a ±0.1 nudge.
  static double _entryScore(JournalEntryModel e) {
    const condScore = {'better': 0.88, 'same': 0.55, 'worse': 0.18};
    const energyDelta = {'high': 0.10, 'moderate': 0.0, 'low': -0.10};
    final base = condScore[e.answers['overall_condition']] ?? 0.55;
    final delta = energyDelta[e.answers['energy_level']] ?? 0.0;
    return (base + delta).clamp(0.0, 1.0);
  }

  static String _moodValue(List<JournalEntryModel> entries) {
    if (entries.isEmpty) return '--';
    final avg =
        entries.map(_entryScore).reduce((a, b) => a + b) / entries.length;
    return '${(avg * 10).toStringAsFixed(1)}/10';
  }

  /// Returns average "sys/dia" from all entries that have a blood_pressure answer.
  /// Returns '--/--' when none exist.
  static String _bpValue(List<JournalEntryModel> entries) {
    final readings = entries
        .map((e) => e.answers['blood_pressure'])
        .whereType<Map<String, dynamic>>()
        .where((m) => m['systolic'] != null && m['diastolic'] != null)
        .toList();
    if (readings.isEmpty) return '--/--';
    final sys = readings
            .map((m) => (m['systolic'] as num).toDouble())
            .reduce((a, b) => a + b) /
        readings.length;
    final dia = readings
            .map((m) => (m['diastolic'] as num).toDouble())
            .reduce((a, b) => a + b) /
        readings.length;
    return '${sys.toInt()}/${dia.toInt()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final entriesAsync = ref.watch(journalEntriesProvider);

    // Use null while loading; empty list on error so the UI stays functional.
    final entries = entriesAsync.asData?.value;
    final isLoading = entriesAsync is AsyncLoading;

    // Sparkline: last 10 entries newest-first → reverse to chronological.
    final last10 =
        entries == null ? <JournalEntryModel>[] : entries.take(10).toList().reversed.toList();
    final sparkData = last10.map(_entryScore).toList();

    final moodStr = isLoading ? '…' : _moodValue(entries ?? []);
    final bpStr = isLoading ? '…' : _bpValue(entries ?? []);
    final logStr = isLoading ? '…' : (entries?.length.toString() ?? '--');
    final rangeLabel = last10.isEmpty ? 'No entries yet' : 'Last ${last10.length} entries';

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
                rangeLabel,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Sparkline or empty state ──────────────────────────────────
          SizedBox(
            height: 62,
            width: double.infinity,
            child: _SparklineBody(
              isLoading: isLoading,
              data: sparkData,
              cs: cs,
              tt: tt,
            ),
          ),
          const SizedBox(height: 14),

          // ── Summary stat badges ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _StatBadge(label: 'Mood', value: moodStr, cs: cs, tt: tt),
              _Divider(),
              _StatBadge(label: 'BP Avg', value: bpStr, cs: cs, tt: tt),
              _Divider(),
              _StatBadge(label: 'Log Entries', value: logStr, cs: cs, tt: tt),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sparkline body ────────────────────────────────────────────────────────────

class _SparklineBody extends StatelessWidget {
  const _SparklineBody({
    required this.isLoading,
    required this.data,
    required this.cs,
    required this.tt,
  });

  final bool isLoading;
  final List<double> data;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Palette.greenColor,
          ),
        ),
      );
    }
    if (data.length < 2) {
      return Center(
        child: Text(
          'Log your first journal entry to see your trend',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    return CustomPaint(
      painter: _SparklinePainter(data: data, lineColor: Palette.greenColor),
    );
  }
}

// ── Stat badge ────────────────────────────────────────────────────────────────

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

// ── Sparkline painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.data, required this.lineColor});
  final List<double> data;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final step = size.width / (data.length - 1);

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

    // End-point dot
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
