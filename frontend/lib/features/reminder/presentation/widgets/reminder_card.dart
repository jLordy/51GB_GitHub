import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/reminder/controller/reminder_controller.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_frequency.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';
import 'package:frontend/theme/palette.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReminderCard extends ConsumerWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onEdit,
  });

  final MedicationReminder reminder;
  final VoidCallback onEdit;

  // ── Status presentation ────────────────────────────────────────────────────

  static const _statusColors = {
    ReminderStatus.upcoming: Color(0xFF359361),
    ReminderStatus.taken: Color(0xFF0EA5E9),
    ReminderStatus.missed: Color(0xFFD62828),
  };

  // ── Frequency badge colors ─────────────────────────────────────────────────

  static const _freqColors = {
    ReminderFrequency.daily: Color(0xFF359361),
    ReminderFrequency.twiceDaily: Color(0xFF0EA5E9),
    ReminderFrequency.weekly: Color(0xFF7C3AED),
    ReminderFrequency.asNeeded: Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Palette.darkSurfaceContainerColor : Colors.white;
    final textDark = isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E);
    final textMid = isDark ? Palette.darkOnSurfaceVariantColor : const Color(0xFF6B7280);

    final statusColor = _statusColors[reminder.status]!;
    final freqColor = _freqColors[reminder.frequency]!;
    final timeStr = DateFormat.jm().format(reminder.scheduledTime);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header strip ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Pill icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.medName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.dosage,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 20, color: textMid),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                // Time
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: textMid),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Frequency badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: freqColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: freqColor.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    reminder.frequency.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: freqColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Status chip
                _StatusChip(status: reminder.status, color: statusColor),
              ],
            ),
          ),

          // ── Footer: actions ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Alarm toggle
                Row(
                  children: [
                    Icon(
                      reminder.isAlarmEnabled
                          ? Icons.alarm_rounded
                          : Icons.alarm_off_rounded,
                      size: 16,
                      color: reminder.isAlarmEnabled
                          ? Palette.greenColor
                          : textMid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Alarm',
                      style: GoogleFonts.inter(fontSize: 12, color: textMid),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: reminder.isAlarmEnabled,
                        onChanged: (_) => ref
                            .read(reminderControllerProvider.notifier)
                            .toggleAlarm(reminder.id),
                        activeThumbColor: Palette.greenColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Mark taken / reset
                if (reminder.status != ReminderStatus.taken)
                  _ActionButton(
                    label: 'Mark taken',
                    icon: Icons.check_rounded,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => ref
                        .read(reminderControllerProvider.notifier)
                        .markStatus(reminder.id, ReminderStatus.taken),
                  ),
                if (reminder.status == ReminderStatus.taken) ...[
                  _ActionButton(
                    label: 'Reset',
                    icon: Icons.refresh_rounded,
                    color: textMid,
                    onTap: () => ref
                        .read(reminderControllerProvider.notifier)
                        .markStatus(reminder.id, ReminderStatus.upcoming),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final ReminderStatus status;
  final Color color;

  static const _icons = {
    ReminderStatus.upcoming: Icons.access_time_rounded,
    ReminderStatus.taken: Icons.check_circle_outline_rounded,
    ReminderStatus.missed: Icons.warning_amber_rounded,
  };

  static const _labels = {
    ReminderStatus.upcoming: 'Upcoming',
    ReminderStatus.taken: 'Taken',
    ReminderStatus.missed: 'Missed',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icons[status], size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            _labels[status]!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline action button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
