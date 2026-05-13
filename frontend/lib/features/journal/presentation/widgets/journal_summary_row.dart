import 'package:flutter/material.dart';

/// A single answered-question row in the journal summary.
///
/// Shows the question [label], the pre-formatted [displayValue], and an
/// edit icon that fires [onEdit] when tapped.
class JournalSummaryRow extends StatelessWidget {
  const JournalSummaryRow({
    super.key,
    required this.label,
    required this.displayValue,
    this.onEdit,
  });

  final String label;
  final String displayValue;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: scheme.primary,
                  size: 20,
                ),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        Text(
          displayValue,
          style: TextStyle(fontSize: 14, color: scheme.onSurface, height: 1.4),
        ),
        Divider(
          height: 28,
          thickness: 0.5,
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}
