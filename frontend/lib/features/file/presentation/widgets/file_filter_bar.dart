import 'package:flutter/material.dart';

/// Sort options for the document grid.
enum FileSortOrder { dateDesc, dateAsc, nameAsc, nameDesc }

/// Filter bar shown at the top of the folder-documents screen.
///
/// Provides a sort-order dropdown and a search text field.
class FileFilterBar extends StatelessWidget {
  const FileFilterBar({
    super.key,
    required this.sortOrder,
    required this.onSortChanged,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final FileSortOrder sortOrder;
  final ValueChanged<FileSortOrder> onSortChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  static String _sortLabel(FileSortOrder order) {
    switch (order) {
      case FileSortOrder.dateDesc:
        return 'Date modified ↓';
      case FileSortOrder.dateAsc:
        return 'Date modified ↑';
      case FileSortOrder.nameAsc:
        return 'Name A–Z';
      case FileSortOrder.nameDesc:
        return 'Name Z–A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtle = cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: <Widget>[
          // ── Sort pill ────────────────────────────────────────────────────
          PopupMenuButton<FileSortOrder>(
            initialValue: sortOrder,
            onSelected: onSortChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => FileSortOrder.values
                .map(
                  (o) => PopupMenuItem<FileSortOrder>(
                    value: o,
                    child: Text(
                      _sortLabel(o),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                )
                .toList(),
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
                  Icon(Icons.sort_rounded, size: 14, color: subtle),
                  const SizedBox(width: 5),
                  Text(
                    _sortLabel(sortOrder),
                    style: TextStyle(color: subtle, fontSize: 13),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down, color: subtle, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Search field ──────────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: onSearchChanged,
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search files…',
                  hintStyle: TextStyle(fontSize: 13, color: subtle),
                  prefixIcon: Icon(Icons.search, size: 18, color: subtle),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
