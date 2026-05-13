import 'package:flutter/material.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';

/// Displays the next scheduled medication and a circular adherence ring.
///
/// In production, wire [adherence], [medicationName], and [schedule] to a
/// MedicationProvider that reads from the patient's medication sub-collection.
class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Placeholder — replace with provider value (0.0 – 1.0)
    const double adherence = 0.78;

    return GlassmorphicContainer(
      child: Row(
        children: <Widget>[
          // ── Circular adherence progress ring ──────────────────────────────
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                  value: adherence,
                  strokeWidth: 5,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.35),
                  color: Palette.greenColor,
                ),
                Text(
                  '${(adherence * 100).toInt()}%',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Palette.greenColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // ── Medication details ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Next Medication',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  'Metformin 500mg',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  '8:00 AM · After Breakfast',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // ── Alarm icon ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Palette.greenColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.alarm_outlined,
              color: Palette.greenColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
