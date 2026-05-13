import 'package:frontend/features/file/model/file_folder_model.dart';
import 'package:flutter/material.dart';

/// Grid card representing a document folder.
///
/// [folder] — the folder data to display.
/// [onTap] — navigates into the folder.
/// [onRename] — triggered from the popup menu; null hides the option.
/// [onDelete] — triggered from the popup menu; null hides the option.
/// [isReadOnly] — when true the action menu is hidden entirely.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.isReadOnly = false,
  });

  final FileFolderModel folder;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF7FBF8);
    final iconBg = cs.primary.withValues(alpha: 0.12);
    final countColor = cs.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Top row: icon + menu ─────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      color: cs.primary,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (!isReadOnly)
                    _FolderMenuButton(
                      folder: folder,
                      onRename: onRename,
                      onDelete: onDelete,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Folder name ───────────────────────────────────────────────
              Text(
                folder.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // ── Item count ────────────────────────────────────────────────
              Text(
                '${folder.itemCount} ${folder.itemCount == 1 ? 'file' : 'files'}',
                style: TextStyle(fontSize: 11, color: countColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Three-dot popup menu for folder actions
// ─────────────────────────────────────────────────────────────────────────────

enum _FolderMenuAction { rename, delete }

class _FolderMenuButton extends StatelessWidget {
  const _FolderMenuButton({
    required this.folder,
    required this.onRename,
    required this.onDelete,
  });

  final FileFolderModel folder;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Nothing to show if all actions are disabled
    final canRename = onRename != null && !folder.isDefault;
    final canDelete = onDelete != null && !folder.isDefault;
    if (!canRename && !canDelete) return const SizedBox.shrink();

    return PopupMenuButton<_FolderMenuAction>(
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => <PopupMenuEntry<_FolderMenuAction>>[
        if (canRename)
          PopupMenuItem<_FolderMenuAction>(
            value: _FolderMenuAction.rename,
            child: Row(
              children: <Widget>[
                Icon(Icons.edit_rounded, size: 16, color: cs.onSurface),
                const SizedBox(width: 10),
                Text('Rename', style: TextStyle(color: cs.onSurface)),
              ],
            ),
          ),
        if (canDelete)
          PopupMenuItem<_FolderMenuAction>(
            value: _FolderMenuAction.delete,
            child: Row(
              children: <Widget>[
                Icon(Icons.delete_outline_rounded, size: 16, color: cs.error),
                const SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: cs.error)),
              ],
            ),
          ),
      ],
      onSelected: (action) {
        if (action == _FolderMenuAction.rename) onRename?.call();
        if (action == _FolderMenuAction.delete) onDelete?.call();
      },
    );
  }
}
