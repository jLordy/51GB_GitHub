import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/features/reminder/controller/reminder_controller.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';
import 'package:frontend/features/reminder/presentation/widgets/add_reminder_sheet.dart';
import 'package:frontend/features/reminder/presentation/widgets/reminder_card.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);
    final textDark =
        isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    final state = ref.watch(reminderControllerProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Reminders',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddReminderSheet(context),
        backgroundColor: Palette.greenColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add reminder',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: BottomNavbar(
        selectedIndex: 2,
        onHomeTap: () => context.go('/home'),
        onJournalTap: () => context.go('/journal'),
        onNotificationsTap: () => context.go('/reminder'),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Palette.greenColor))
          : state.reminders.isEmpty
              ? _EmptyState(textDark: textDark, textMid: textMid)
              : _ReminderList(
                  reminders: state.reminders,
                  textDark: textDark,
                  textMid: textMid,
                ),
    );
  }
}

// ── Grouped list ──────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.reminders,
    required this.textDark,
    required this.textMid,
  });

  final List<MedicationReminder> reminders;
  final Color textDark;
  final Color textMid;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final missed =
        reminders.where((r) => r.status == ReminderStatus.missed).toList();

    final todayList = reminders.where((r) {
      if (r.status == ReminderStatus.missed) return false;
      final d = DateTime(
          r.scheduledTime.year, r.scheduledTime.month, r.scheduledTime.day);
      return d == today;
    }).toList();

    final upcoming = reminders.where((r) {
      if (r.status == ReminderStatus.missed) return false;
      final d = DateTime(
          r.scheduledTime.year, r.scheduledTime.month, r.scheduledTime.day);
      return d.isAfter(today);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      children: [
        if (missed.isNotEmpty) ...[
          _SectionHeader(
              label: 'Missed',
              accent: const Color(0xFFD62828),
              textMid: textMid),
          ...missed.map((r) => _DismissibleCard(reminder: r)),
        ],
        if (todayList.isNotEmpty) ...[
          _SectionHeader(
              label: 'Today',
              accent: Palette.greenColor,
              textMid: textMid),
          ...todayList.map((r) => _DismissibleCard(reminder: r)),
        ],
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(
              label: 'Upcoming',
              accent: const Color(0xFF0EA5E9),
              textMid: textMid),
          ...upcoming.map((r) => _DismissibleCard(reminder: r)),
        ],
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.accent,
    required this.textMid,
  });

  final String label;
  final Color accent;
  final Color textMid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textMid,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Swipe-to-delete card ──────────────────────────────────────────────────────

class _DismissibleCard extends ConsumerWidget {
  const _DismissibleCard({required this.reminder});
  final MedicationReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFD62828),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) =>
          ref.read(reminderControllerProvider.notifier).delete(reminder.id),
      child: ReminderCard(
        reminder: reminder,
        onEdit: () => showAddReminderSheet(context, existing: reminder),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.textDark, required this.textMid});
  final Color textDark;
  final Color textMid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Palette.greenColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 44,
                color: Palette.greenColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reminders yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add reminder" to schedule your first medication.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: textMid),
            ),
          ],
        ),
      ),
    );
  }
}
