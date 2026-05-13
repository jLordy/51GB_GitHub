import 'package:flutter/material.dart';

/// Badge chip showing how many times an entry has been edited, with an
/// optional "View history" link that fires [onViewHistory].
class EditHistoryChip extends StatelessWidget {
  const EditHistoryChip({
    super.key,
    required this.editCount,
    required this.historyLoading,
    required this.onViewHistory,
  });

  final int editCount;
  final bool historyLoading;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // ── Badge chip ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: editCount > 0
                  ? scheme.secondaryContainer.withValues(alpha: 0.55)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: editCount > 0
                    ? scheme.secondary.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  editCount > 0
                      ? Icons.edit_rounded
                      : Icons.check_circle_outline,
                  size: 13,
                  color: editCount > 0
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  editCount > 0
                      ? 'Edited $editCount ${editCount == 1 ? 'time' : 'times'}'
                      : 'Original entry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: editCount > 0
                        ? scheme.secondary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // ── View history link (only when there are edits) ───────
          if (editCount > 0) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: historyLoading ? null : onViewHistory,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (historyLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: scheme.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'View history',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
