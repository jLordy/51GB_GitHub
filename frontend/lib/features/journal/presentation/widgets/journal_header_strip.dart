import 'package:flutter/material.dart';

/// App-bar-adjacent header showing the journal icon, title, subtitle,
/// and a live entry-count badge.
class JournalHeaderStrip extends StatelessWidget {
  const JournalHeaderStrip({super.key, required this.entryCount});

  final int? entryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(Icons.menu_book_rounded, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Health Journal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Record how you feel anytime',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '${entryCount ?? '-'} entries',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
