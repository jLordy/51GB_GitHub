import 'package:flutter/material.dart';

/// Empty state shown when there are no journal entries yet.
///
/// Set [isReadOnly] to `true` when the viewer is a doctor so the copy
/// reflects that they cannot add entries themselves.
class JournalEmptyState extends StatelessWidget {
  const JournalEmptyState({super.key, this.isReadOnly = false});

  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.book_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isReadOnly
                  ? 'This patient has not recorded any journal entries yet.'
                  : 'Tap the "Add Entry" button below to record your first health journal entry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
