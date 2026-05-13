import 'package:frontend/features/file/model/file_document_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Grid card representing a single document inside a folder.
///
/// [document] — document data.
/// [onTap] — opens the file viewer.
/// [onRename] — popup menu option; null hides it.
/// [onDelete] — popup menu option; null hides it.
/// [isReadOnly] — when true the action menu is hidden entirely.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.isReadOnly = false,
  });

  final FileDocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  String get _formattedDate => _dateFmt.format(document.createdAt.toLocal());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF7FBF8);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Thumbnail area ────────────────────────────────────────────
            Expanded(
              child: _DocumentThumbnail(document: document, cs: cs),
            ),

            // ── Info footer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          document.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isReadOnly)
                    _DocumentMenuButton(onRename: onRename, onDelete: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Thumbnail — image preview, PDF icon, or Word icon
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.document, required this.cs});

  final FileDocumentModel document;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (document.isImage) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: Image.network(
          document.fileUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _IconThumb(
            icon: Icons.broken_image_rounded,
            color: cs.onSurfaceVariant,
            bg: cs.surfaceContainerHighest,
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: cs.primary,
              ),
            );
          },
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (document.isPdf) {
      return _IconThumb(
        icon: Icons.picture_as_pdf_rounded,
        color: isDark
            ? Colors.white.withValues(alpha: 0.90)
            : const Color(0xFFE53E3E),
        bg: isDark
            ? const Color(0xFFE53E3E).withValues(alpha: 0.18)
            : const Color(0xFFFFF5F5),
        label: 'PDF',
      );
    }

    // Word / DOC / DOCX
    return _IconThumb(
      icon: Icons.description_rounded,
      color: isDark
          ? Colors.white.withValues(alpha: 0.90)
          : const Color(0xFF2B6CB0),
      bg: isDark
          ? const Color(0xFF2B6CB0).withValues(alpha: 0.18)
          : const Color(0xFFEBF8FF),
      label: 'DOC',
    );
  }
}

class _IconThumb extends StatelessWidget {
  const _IconThumb({
    required this.icon,
    required this.color,
    required this.bg,
    this.label,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 36, color: color),
          if (label != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Three-dot popup menu for document actions
// ─────────────────────────────────────────────────────────────────────────────

enum _DocMenuAction { rename, delete }

class _DocumentMenuButton extends StatelessWidget {
  const _DocumentMenuButton({required this.onRename, required this.onDelete});

  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (onRename == null && onDelete == null) return const SizedBox.shrink();

    return PopupMenuButton<_DocMenuAction>(
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: Icon(Icons.more_vert_rounded, size: 16, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => <PopupMenuEntry<_DocMenuAction>>[
        if (onRename != null)
          PopupMenuItem<_DocMenuAction>(
            value: _DocMenuAction.rename,
            child: Row(
              children: <Widget>[
                Icon(Icons.edit_rounded, size: 16, color: cs.onSurface),
                const SizedBox(width: 10),
                Text('Rename', style: TextStyle(color: cs.onSurface)),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<_DocMenuAction>(
            value: _DocMenuAction.delete,
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
        if (action == _DocMenuAction.rename) onRename?.call();
        if (action == _DocMenuAction.delete) onDelete?.call();
      },
    );
  }
}
