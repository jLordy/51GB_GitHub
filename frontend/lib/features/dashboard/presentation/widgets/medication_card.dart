import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/features/reminder/controller/reminder_controller.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MedicationCard extends ConsumerWidget {
  const MedicationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final reminders = ref.watch(
      reminderControllerProvider.select((s) => s.reminders),
    );

    // Adherence = taken / (taken + missed); upcoming doses don't count yet.
    final taken = reminders.where((r) => r.status == ReminderStatus.taken).length;
    final missed = reminders.where((r) => r.status == ReminderStatus.missed).length;
    final evaluated = taken + missed;
    final adherence = evaluated > 0 ? taken / evaluated : 0.0;

    // Next upcoming dose sorted by scheduledTime.
    final upcoming = reminders
        .where((r) => r.status == ReminderStatus.upcoming)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final MedicationReminder? next = upcoming.isEmpty ? null : upcoming.first;

    return GestureDetector(
      onTap: () => context.go('/reminder'),
      child: GlassmorphicContainer(
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
                    color: evaluated == 0
                        ? cs.outlineVariant
                        : Palette.greenColor,
                  ),
                  Text(
                    evaluated == 0
                        ? '--'
                        : '${(adherence * 100).toInt()}%',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: evaluated == 0
                          ? cs.onSurfaceVariant
                          : Palette.greenColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // ── Medication details ─────────────────────────────────────────────
            Expanded(
              child: next == null
                  ? _EmptyState(tt: tt, cs: cs, hasReminders: reminders.isNotEmpty)
                  : _NextDose(next: next, tt: tt, cs: cs),
            ),

            // ── Arrow icon ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Palette.greenColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Palette.greenColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextDose extends StatelessWidget {
  const _NextDose({required this.next, required this.tt, required this.cs});

  final MedicationReminder next;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.jm().format(next.scheduledTime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Next Medication',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          '${next.medName} · ${next.dosage}',
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          timeStr,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tt, required this.cs, required this.hasReminders});

  final TextTheme tt;
  final ColorScheme cs;
  final bool hasReminders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Medications',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          hasReminders ? 'All done for today!' : 'No reminders set',
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 1),
        Text(
          hasReminders ? 'Great job keeping up' : 'Tap to add a reminder',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
