import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_list_tile.dart';
import 'package:flutter/material.dart';

// ── Date-grouping helpers ──────────────────────────────────────────────────────

/// Groups [entries] by local-date string "YYYY-MM-DD".
/// Preserves descending order within each day. Returns an ordered map
/// (newest date first, matching the order of [entries]).
Map<String, List<JournalEntryModel>> _groupEntriesByDate(
  List<JournalEntryModel> entries,
) {
  final Map<String, List<JournalEntryModel>> map =
      <String, List<JournalEntryModel>>{};
  for (final entry in entries) {
    final d = entry.submittedAt.toLocal();
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => <JournalEntryModel>[]).add(entry);
  }
  return map;
}

/// Returns "Today", "Yesterday", or a formatted date for a "YYYY-MM-DD" key.
String _dateLabel(String isoDate) {
  final parts = isoDate.split('-');
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';
  return _formatFullDate(isoDate);
}

/// Returns "April 2, 2026" from a "YYYY-MM-DD" key.
String _formatFullDate(String isoDate) {
  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final parts = isoDate.split('-');
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  final year = parts[0];
  return '${months[month - 1]} $day, $year';
}

// ── Delete confirmation ────────────────────────────────────────────────────────

/// Shows the delete-confirmation dialog. Calls [onConfirmed] only if the user
/// taps "Delete". Guards against unmounted context after the async gap.
Future<void> _confirmDelete(
  BuildContext context,
  JournalEntryModel entry,
  void Function(JournalEntryModel) onConfirmed,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete entry?'),
      content: const Text(
        'This journal entry will be permanently deleted and cannot be recovered.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;
  onConfirmed(entry);
}

// ── Date group header ──────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                '$count ${count == 1 ? 'entry' : 'entries'}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}

// ── Main widget ────────────────────────────────────────────────────────────────

/// Scrollable grouped list of journal entries.
///
/// [onTapEntry] — called when the user taps a tile or selects "Edit".
/// [onDeleteEntry] — called after the user confirms deletion; the caller is
///   responsible for executing the actual delete and refreshing the list.
/// When [isReadOnly] is true the tile action bar is hidden and delete
/// confirmation is never triggered (doctor/caregiver read-only views).
class JournalEntriesList extends StatelessWidget {
  const JournalEntriesList({
    super.key,
    required this.entries,
    required this.onTapEntry,
    required this.onDeleteEntry,
    this.previewBuilder,
    this.isReadOnly = false,
  });

  final List<JournalEntryModel> entries;
  final void Function(JournalEntryModel) onTapEntry;
  final void Function(JournalEntryModel) onDeleteEntry;
  final String? Function(JournalEntryModel entry)? previewBuilder;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final bottomPad = 76 + MediaQuery.of(context).padding.bottom;
    final grouped = _groupEntriesByDate(entries);
    final dateKeys = grouped.keys.toList();

    return CustomScrollView(
      slivers: <Widget>[
        for (final dateKey in dateKeys) ...<Widget>[
          SliverToBoxAdapter(
            child: _DateGroupHeader(
              label: _dateLabel(dateKey),
              count: grouped[dateKey]!.length,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((BuildContext context, int i) {
              final entry = grouped[dateKey]![i];
              return JournalListTile(
                entry: entry,
                previewText: previewBuilder?.call(entry),
                onTap: () => onTapEntry(entry),
                onDelete: () => _confirmDelete(context, entry, onDeleteEntry),
                isReadOnly: isReadOnly,
              );
            }, childCount: grouped[dateKey]!.length),
          ),
        ],
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPad)),
      ],
    );
  }
}
