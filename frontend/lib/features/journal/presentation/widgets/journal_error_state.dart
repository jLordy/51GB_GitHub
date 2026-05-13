import 'package:flutter/material.dart';

/// Error state shown when the journal entries feed fails to load.
class JournalErrorState extends StatelessWidget {
  const JournalErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 52, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Could not load your journal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: cs.primary),
              label: Text('Retry', style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
