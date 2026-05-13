import 'package:frontend/features/file/controller/file_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet displayed while a file is being uploaded.
///
/// Reads [uploadProgressProvider] to show a progress indicator.
/// Automatically dismisses when progress becomes null (upload complete).
/// [fileName] is shown below the indicator.
/// [onCancel] is wired to the Cancel button — the caller is responsible
/// for actually aborting the upload.
class UploadProgressSheet extends ConsumerWidget {
  const UploadProgressSheet({
    super.key,
    required this.fileName,
    required this.onCancel,
  });

  final String fileName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(uploadProgressProvider);

    // Auto-dismiss when upload finishes (progress set back to null)
    if (progress == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Drag handle ──────────────────────────────────────────────
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Uploading label ───────────────────────────────────────────
            Text(
              'Uploading…',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // ── Progress indicator ────────────────────────────────────────
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                color: cs.primary,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
              ),
            ),

            if (progress != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '${(progress * 100).toStringAsFixed(0)} %',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 16),

            // ── File name ─────────────────────────────────────────────────
            Text(
              fileName,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 24),

            // ── Cancel button ─────────────────────────────────────────────
            OutlinedButton(
              onPressed: () {
                onCancel();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
