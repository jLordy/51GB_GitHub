import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:flutter/material.dart';

// ── Private helpers ───────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
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
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _formatHistoryTime(DateTime dt) {
  final hour = dt.hour;
  final minute = dt.minute;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String _formatHistoryValue(dynamic v) {
  if (v == null) return '—';
  if (v is Map) {
    if (v.containsKey('value') && v.containsKey('unit')) {
      final raw = v['value'];
      final unit = v['unit'];
      final display = raw is double && raw == raw.roundToDouble()
          ? raw.toInt().toString()
          : raw?.toString() ?? '—';
      return '$display $unit';
    }
    if (v.containsKey('systolic') && v.containsKey('diastolic')) {
      return '${v['systolic']} / ${v['diastolic']}';
    }
    return v.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
  if (v is List) {
    return v.isEmpty ? '—' : v.map((x) => x.toString()).join(', ');
  }
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

String _buildHistoryPreview(Map<String, dynamic> answers) {
  if (answers.isEmpty) return 'No answers recorded.';
  final buffer = StringBuffer();
  int count = 0;
  for (final e in answers.entries) {
    if (count >= 8) {
      buffer.writeln('… and ${answers.length - count} more');
      break;
    }
    // Strip trailing unit suffixes before title-casing the key.
    final rawKey = e.key.replaceAll(
      RegExp(r'_(kg|lb|lbs|ml|l|g)$', caseSensitive: false),
      '',
    );
    final label = rawKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    buffer.writeln('$label: ${_formatHistoryValue(e.value)}');
    count++;
  }
  return buffer.toString().trim();
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Scrollable bottom-sheet body listing all [EditHistoryEntry] records.
///
/// Pass this widget directly to [showModalBottomSheet]'s [builder] (wrapped in
/// a [DraggableScrollableSheet]) so the caller controls when the sheet opens.
class EditHistorySheet extends StatelessWidget {
  const EditHistorySheet({
    super.key,
    required this.editHistory,
    required this.surfaceCard,
  });

  final List<EditHistoryEntry> editHistory;
  final Color surfaceCard;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return Column(
          children: [
            // ── Drag handle ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Title row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Edit History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${editHistory.length} '
                      '${editHistory.length == 1 ? 'edit' : 'edits'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            // ── History list ────────────────────────────────────────
            Expanded(
              child: editHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No edit history available.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: editHistory.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 24,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      itemBuilder: (_, i) {
                        final h = editHistory[i];
                        final formattedDate = _formatDate(h.editedAt.toLocal());
                        final formattedTime = _formatHistoryTime(
                          h.editedAt.toLocal(),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.secondaryContainer.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${h.editNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.secondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Edit #${h.editNumber}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '$formattedDate · $formattedTime',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (h.editedByName != null)
                                        Text(
                                          'Edited by ${h.editedByName}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Answers before this edit:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: surfaceCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                _buildHistoryPreview(h.previousAnswers),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
