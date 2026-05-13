import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Two-field row for picking a start and end date.
///
/// Uses [showDatePicker] from Material. Both dates are nullable until the user
/// picks them.  The parent screen decides how to format them for the API call
/// (use [DateRangeRow.formatDate] helper, which produces `"yyyy-MM-dd"`).
class DateRangeRow extends StatelessWidget {
  const DateRangeRow({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;

  static String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  static String displayDate(DateTime? dt) =>
      dt == null ? 'Pick date' : DateFormat('MMM d, yyyy').format(dt);

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? current,
    required DateTime? firstDate,
    required DateTime? lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? now,
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _DateChip(
            label: 'From',
            value: displayDate(startDate),
            isDark: isDark,
            cs: cs,
            onTap: () => _pickDate(
              context: context,
              current: startDate,
              firstDate: null,
              lastDate: endDate ?? DateTime.now(),
              onPicked: onStartChanged,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.arrow_forward_rounded, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: _DateChip(
            label: 'To',
            value: displayDate(endDate),
            isDark: isDark,
            cs: cs,
            onTap: () => _pickDate(
              context: context,
              current: endDate,
              firstDate: startDate,
              lastDate: DateTime.now(),
              onPicked: onEndChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Palette.darkSurfaceContainerColor
              : const Color(0xFFF0F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: Palette.greenColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
