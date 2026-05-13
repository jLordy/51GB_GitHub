import 'package:flutter/material.dart';

/// Generic radio-style selection card used across multiple onboarding steps.
/// [compact] removes bottom padding — used when cards sit side-by-side
/// inside a [Row] (e.g. the family history condition rows).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  // Controls vertical density for inline row layouts.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTextColor = isDark ? Colors.white : scheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 10 : 13,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.6 : 1.0,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? selectedTextColor : scheme.onSurface,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selected ? 1.0 : 0.0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: selectedTextColor,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
