import 'package:flutter/material.dart';

/// Empty state shown when the user is browsing as a guest (not signed in).
class JournalGuestEmpty extends StatelessWidget {
  const JournalGuestEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer.withValues(alpha: 0.45),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Login to view your journal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an account or log in to track your daily health entries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
