import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Horizontal segmented toggle for selecting a summary period.
///
/// [periods] is an ordered list of period labels, e.g. ['Week', 'Month', 'Year'].
/// [selected] is the currently selected value.
/// [onChanged] is called with the new value when the user taps a segment.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  final List<String> periods;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? Palette.darkSurfaceContainerColor
            : const Color(0xFFEEF4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: periods.map((period) {
          final isSelected = period == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Palette.greenColor : Palette.greenColor)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  period,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
