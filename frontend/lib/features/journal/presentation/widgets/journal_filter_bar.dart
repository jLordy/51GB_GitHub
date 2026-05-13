import 'package:flutter/material.dart';

/// Sort order applied to journal entries.
enum JournalSortOrder { newestFirst, oldestFirst }

/// Interactive filter bar with sort-order toggle and date filter.
///
/// [sortOrder] / [onSortChanged] — current sort and change callback.
/// [dateFilter] / [onDateFilterChanged] — selected date (null = all) and
///   change callback; pass `null` to clear.
class JournalFilterBar extends StatelessWidget {
  const JournalFilterBar({
    super.key,
    required this.sortOrder,
    required this.dateFilter,
    required this.onSortChanged,
    required this.onDateFilterChanged,
  });

  final JournalSortOrder sortOrder;
  final DateTime? dateFilter;
  final ValueChanged<JournalSortOrder> onSortChanged;
  final ValueChanged<DateTime?> onDateFilterChanged;

  static String _fmtDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtle = cs.onSurfaceVariant;
    final isFiltered = dateFilter != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: <Widget>[
          // ── Sort pill ────────────────────────────────────────────────────
          PopupMenuButton<JournalSortOrder>(
            initialValue: sortOrder,
            onSelected: onSortChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => <PopupMenuEntry<JournalSortOrder>>[
              PopupMenuItem<JournalSortOrder>(
                value: JournalSortOrder.newestFirst,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: cs.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text('Newest first', style: TextStyle(color: cs.onSurface)),
                  ],
                ),
              ),
              PopupMenuItem<JournalSortOrder>(
                value: JournalSortOrder.oldestFirst,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: cs.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text('Oldest first', style: TextStyle(color: cs.onSurface)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    sortOrder == JournalSortOrder.newestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 14,
                    color: subtle,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    sortOrder == JournalSortOrder.newestFirst
                        ? 'Newest first'
                        : 'Oldest first',
                    style: TextStyle(color: subtle, fontSize: 13),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down, color: subtle, size: 16),
                ],
              ),
            ),
          ),
          const Spacer(),
          // ── Date filter pill ─────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: dateFilter ?? now,
                firstDate: DateTime(2020),
                lastDate: now,
              );
              if (!context.mounted) return;
              if (picked != null) onDateFilterChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isFiltered
                    ? cs.primaryContainer.withValues(alpha: 0.4)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFiltered
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: isFiltered ? cs.primary : subtle,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isFiltered ? _fmtDate(dateFilter!) : 'All dates',
                    style: TextStyle(
                      color: isFiltered ? cs.primary : subtle,
                      fontSize: 13,
                      fontWeight: isFiltered
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (isFiltered) ...<Widget>[
                    const SizedBox(width: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDateFilterChanged(null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down, color: subtle, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
