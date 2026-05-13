import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:flutter/material.dart';

// ── Skeleton shimmer ───────────────────────────────────────────────────────────

class _PreviewSkeleton extends StatefulWidget {
  const _PreviewSkeleton();

  @override
  State<_PreviewSkeleton> createState() => _PreviewSkeletonState();
}

class _PreviewSkeletonState extends State<_PreviewSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final color = base.withValues(alpha: 0.08 + _anim.value * 0.08);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonLine(color: color, widthFactor: 0.85),
            const SizedBox(height: 6),
            _SkeletonLine(color: color, widthFactor: 0.70),
            const SizedBox(height: 6),
            _SkeletonLine(color: color, widthFactor: 0.55),
          ],
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.color, required this.widthFactor});
  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ── Menu actions ───────────────────────────────────────────────────────────────

enum _TileMenuAction { edit, delete }

// ── Formatting helper ──────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour;
  final minute = local.minute;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

// ── Widget ─────────────────────────────────────────────────────────────────────

/// A card-style tile that displays a journal entry preview, an optional
/// "Edited" badge, and a popup context menu (Edit / Print / Delete).
///
/// All colors are derived from [Theme.of(context)] — no color parameters needed.
/// [onTap] is invoked both by tapping the card and by selecting "Edit".
/// [onDelete] is invoked when the user selects "Delete"; the caller is
/// responsible for showing any confirmation dialog.
/// When [isReadOnly] is true the action bar (divider + popup menu) is hidden,
/// making the tile suitable for doctor/caregiver read-only views.
class JournalListTile extends StatelessWidget {
  const JournalListTile({
    super.key,
    required this.entry,
    this.previewText,
    required this.onTap,
    required this.onDelete,
    this.isReadOnly = false,
  });

  final JournalEntryModel entry;
  final String? previewText;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Tappable content area ──────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // ── Time + edited badge column ─────────────────────────
                  SizedBox(
                    width: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _formatTime(entry.submittedAt),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                            height: 1.2,
                          ),
                        ),
                        if (entry.editCount > 0) ...<Widget>[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: cs.secondary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.edit_rounded,
                                  size: 9,
                                  color: cs.secondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: cs.secondary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Preview ───────────────────────────────────────────
                  Expanded(
                    child: previewText == null
                        ? const _PreviewSkeleton()
                        : Text(
                            previewText!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: cs.onSurface.withValues(alpha: 0.85),
                              height: 1.55,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // ── Divider ───────────────────────────────────────────────────
          if (!isReadOnly) Divider(height: 1, thickness: 1, color: borderColor),
          // ── Action bar ────────────────────────────────────────────────
          if (!isReadOnly)
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<_TileMenuAction>(
                icon: Icon(
                  Icons.more_horiz,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: '',
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onSelected: (action) {
                  switch (action) {
                    case _TileMenuAction.edit:
                      onTap();
                    case _TileMenuAction.delete:
                      onDelete();
                      throw UnimplementedError();
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<_TileMenuAction>>[
                  PopupMenuItem<_TileMenuAction>(
                    value: _TileMenuAction.edit,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: cs.onSurface,
                        ),
                        const SizedBox(width: 10),
                        Text('Edit', style: TextStyle(color: cs.onSurface)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_TileMenuAction>(
                    value: _TileMenuAction.delete,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline, size: 18, color: cs.error),
                        const SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
