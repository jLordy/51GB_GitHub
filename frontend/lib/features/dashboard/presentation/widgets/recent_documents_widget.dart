import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/file/controller/file_controller.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

/// Horizontal scroll of the patient's document folders.
///
/// Uses [fileFoldersProvider] — same source as DocumentsScreen.
/// Renders only for patient roles; non-patient callers should not mount this.
class RecentDocumentsWidget extends ConsumerWidget {
  const RecentDocumentsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final foldersAsync = ref.watch(fileFoldersProvider);

    // Right padding is zero so horizontal list bleeds to the screen edge
    return GlassmorphicContainer(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Documents',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => context.go('/documents'),
                  child: Text(
                    'See all',
                    style: tt.labelSmall?.copyWith(
                      color: Palette.greenColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Folder list ──────────────────────────────────────────────────
          foldersAsync.when(
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Text(
                'Could not load folders',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            data: (folders) {
              if (folders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 4),
                  child: Text(
                    'No folders yet — tap Documents to create one',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              return SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: folders.length,
                  itemBuilder: (_, i) {
                    final folder = folders[i];
                    return GestureDetector(
                      onTap: () => context.push(
                        '/documents/${folder.id}',
                        extra: <String, String>{'name': folder.name},
                      ),
                      child: Container(
                        width: 84,
                        decoration: BoxDecoration(
                          color: Palette.greenColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Palette.greenColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.folder_outlined,
                              color: Palette.greenColor,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                folder.name,
                                style: tt.labelSmall?.copyWith(fontSize: 10),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
